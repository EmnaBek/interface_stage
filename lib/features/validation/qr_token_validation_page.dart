import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/session/user_session.dart';

class QrTokenValidationPage extends StatefulWidget {
  const QrTokenValidationPage({super.key});

  @override
  State<QrTokenValidationPage> createState() => _QrTokenValidationPageState();
}

class _QrTokenValidationPageState extends State<QrTokenValidationPage> {
  final TextEditingController _endpointController = TextEditingController();

  bool _scanLocked = false;
  bool _isLoading = false;
  String? _rawQrValue;
  String? _token;
  String? _serverResponse;
  String? _error;
  String? _jwtDecodeNote;
  Map<String, dynamic>? _decodedTokenClaims;

  @override
  void dispose() {
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_scanLocked || _isLoading) return;

    final String? rawValue =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    final String extractedToken = _extractToken(rawValue.trim());
    if (extractedToken.isEmpty) {
      setState(() {
        _rawQrValue = rawValue;
        _error = 'Aucun token exploitable trouvé dans le QR.';
      });
      return;
    }

    final Map<String, dynamic>? decodedClaims =
        _tryDecodeJwtPayload(extractedToken);

    setState(() {
      _scanLocked = true;
      _rawQrValue = rawValue;
      _token = extractedToken;
      _decodedTokenClaims = decodedClaims;
      _jwtDecodeNote = decodedClaims == null
          ? 'Token détecté, mais payload JWT illisible (ou token non-JWT).'
          : null;
      _error = null;
      _serverResponse = null;
    });

    final String? displayName = _extractDisplayName(decodedClaims);
    if (displayName != null && displayName.isNotEmpty) {
      UserSession.displayName.value = displayName;
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        return;
      }
    }

    if (_endpointController.text.trim().isNotEmpty) {
      await _callProtectedApi(extractedToken);
    }
  }

  String _extractToken(String value) {
    final Uri? uri = Uri.tryParse(value);
    final String? tokenFromQuery = uri?.queryParameters['token'];
    if (tokenFromQuery != null && tokenFromQuery.isNotEmpty) {
      return _normalizeTokenCandidate(tokenFromQuery);
    }

    final dynamic decoded = _tryDecodeJson(value);
    if (decoded is Map<String, dynamic>) {
      final dynamic tokenField = decoded['token'];
      if (tokenField is String && tokenField.isNotEmpty) {
        return _normalizeTokenCandidate(tokenField);
      }
    }

    return _normalizeTokenCandidate(value);
  }

  String _normalizeTokenCandidate(String value) {
    final String compact =
        value.trim().replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');

    final RegExp jwtPattern =
        RegExp(r'([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)');
    final RegExpMatch? match = jwtPattern.firstMatch(compact);
    if (match != null) {
      return match.group(1) ?? compact;
    }

    return compact;
  }

  dynamic _tryDecodeJson(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _tryDecodeJwtPayload(String token) {
    final List<String> parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }

    try {
      final String normalizedPayload = base64Url.normalize(parts[1]);
      final String payloadJson = utf8.decode(base64Url.decode(normalizedPayload));
      final dynamic decoded = jsonDecode(payloadJson);

      if (decoded is Map<String, dynamic>) {
        final dynamic exp = decoded['exp'];
        if (exp is int) {
          decoded['exp_readable_utc'] =
              DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
                  .toIso8601String();
        }
        return decoded;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String? _extractDisplayName(Map<String, dynamic>? claims) {
    if (claims == null) return null;

    final String? fromGivenAndFamily = _joinNameParts(claims);
    if (fromGivenAndFamily != null) return fromGivenAndFamily;

    const Set<String> candidateKeys = <String>{
      'display_name',
      'displayname',
      'display-name',
      'name',
      'fullname',
      'full_name',
      'full-name',
      'preferred_username',
      'preferredusername',
      'username',
      'user_name',
      'nom',
      'prenom',
      'agent_name',
      'agentname',
      'sub',
    };

    return _findDisplayNameRecursively(claims, candidateKeys: candidateKeys);
  }

  String? _joinNameParts(Map<String, dynamic> claims) {
    const List<String> givenNameKeys = <String>['given_name', 'givenname', 'prenom'];
    const List<String> familyNameKeys = <String>['family_name', 'familyname', 'nom'];

    String? findFirst(List<String> keys) {
      for (final String key in keys) {
        final dynamic value = claims[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    final String? givenName = findFirst(givenNameKeys);
    final String? familyName = findFirst(familyNameKeys);
    if (givenName != null && familyName != null) {
      return '$givenName $familyName';
    }
    return givenName ?? familyName;
  }

  String? _findDisplayNameRecursively(
    dynamic node, {
    required Set<String> candidateKeys,
  }) {
    if (node is! Map) return null;

    for (final MapEntry<dynamic, dynamic> entry in node.entries) {
      final String normalizedKey = entry.key.toString().toLowerCase();
      final dynamic value = entry.value;

      if (candidateKeys.contains(normalizedKey) &&
          value is String &&
          value.trim().isNotEmpty) {
        return value.trim();
      }

      final String? nested =
          _findDisplayNameRecursively(value, candidateKeys: candidateKeys);
      if (nested != null) return nested;
    }

    return null;
  }

  Future<void> _callProtectedApi(String token) async {
    final String endpoint = _endpointController.text.trim();
    if (endpoint.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = "Ajoute l'URL API avant de scanner.";
      });
      return;
    }

    final Uri? uri = Uri.tryParse(endpoint);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      setState(() {
        _isLoading = false;
        _error = 'URL invalide. Exemple: https://api.exemple.com/path';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final http.Response response = await http.get(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final String prettyBody = _formatBody(response.body);
      setState(() {
        _serverResponse =
            'HTTP ${response.statusCode}\n\nHeaders: ${response.headers}\n\n$prettyBody';
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur réseau: $e';
        _serverResponse = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatBody(String body) {
    final dynamic decoded = _tryDecodeJson(body);
    if (decoded != null) {
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    }
    return body;
  }

  void _resetScan() {
    setState(() {
      _scanLocked = false;
      _isLoading = false;
      _rawQrValue = null;
      _token = null;
      _decodedTokenClaims = null;
      _jwtDecodeNote = null;
      _serverResponse = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> infoWidgets = <Widget>[];

    if (_rawQrValue != null) {
      infoWidgets.add(SelectableText('QR brut: $_rawQrValue'));
      infoWidgets.add(const SizedBox(height: 6));
    }

    if (_token != null) {
      infoWidgets.add(SelectableText('Token: $_token'));
      infoWidgets.add(const SizedBox(height: 6));
    }

    if (_decodedTokenClaims != null) {
      infoWidgets.add(const Text('Token décodé (payload JWT):'));
      infoWidgets.add(const SizedBox(height: 4));
      infoWidgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(_decodedTokenClaims),
          ),
        ),
      );
      infoWidgets.add(const SizedBox(height: 8));
    }

    if (_jwtDecodeNote != null) {
      infoWidgets.add(
        Text(
          _jwtDecodeNote!,
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
      );
      infoWidgets.add(const SizedBox(height: 8));
    }

    if (_error != null) {
      infoWidgets.add(
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
      infoWidgets.add(const SizedBox(height: 6));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR + Token')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _endpointController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Endpoint API protégé',
                hintText: 'https://api.exemple.com/patient/profile',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 240,
                width: double.infinity,
                child: MobileScanner(onDetect: _handleDetection),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _scanLocked ? _resetScan : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rescanner'),
                ),
                const SizedBox(width: 10),
                if (_isLoading) const CircularProgressIndicator(),
              ],
            ),
            const SizedBox(height: 12),
            if (infoWidgets.isNotEmpty) ...<Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: infoWidgets,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_serverResponse != null)
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(_serverResponse!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
