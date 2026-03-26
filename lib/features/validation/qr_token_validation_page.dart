import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

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
    if (_scanLocked || _isLoading) {
      return;
    }

    final String? rawValue =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    final String extractedToken = _extractToken(rawValue.trim());
    if (extractedToken.isEmpty) {
      setState(() {
        _rawQrValue = rawValue;
        _token = null;
        _decodedTokenClaims = null;
        _jwtDecodeNote = null;
        _serverResponse = null;
        _error = 'Token introuvable dans le QR code.';
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
          ? "Le token n'est pas un JWT valide (format: header.payload.signature)."
          : null;
      _error = null;
      _serverResponse = null;
    });

    await _callProtectedApi(extractedToken);
  }

  String _extractToken(String value) {
    final String source = value.trim();

    final Uri? uri = Uri.tryParse(source);
    final String? tokenFromQuery = uri?.queryParameters['token'];
    if (tokenFromQuery != null && tokenFromQuery.isNotEmpty) {
      return _normalizeTokenCandidate(tokenFromQuery);
    }

    final dynamic decoded = _tryDecodeJson(source);
    if (decoded is Map<String, dynamic>) {
      final dynamic tokenField = decoded['token'];
      if (tokenField is String && tokenField.isNotEmpty) {
        return _normalizeTokenCandidate(tokenField);
      }
    }

    return _normalizeTokenCandidate(source);
  }

  String _normalizeTokenCandidate(String value) {
    final String compact =
        value.trim().replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');

    final RegExp jwtPattern = RegExp(
      r'([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)',
    );
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
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
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
            if (_rawQrValue != null) ...<Widget>[
              SelectableText('QR brut: $_rawQrValue'),
              const SizedBox(height: 6),
            ],
            if (_token != null) ...<Widget>[
              SelectableText('Token: $_token'),
              const SizedBox(height: 6),
            ],
            if (_decodedTokenClaims != null) ...<Widget>[
              const Text('Token décodé (payload JWT):'),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ')
                      .convert(_decodedTokenClaims),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_jwtDecodeNote != null) ...<Widget>[
              Text(
                _jwtDecodeNote!,
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
              const SizedBox(height: 8),
            ],
            if (_error != null) ...<Widget>[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 6),
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
