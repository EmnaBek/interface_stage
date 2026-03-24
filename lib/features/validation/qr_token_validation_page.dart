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
  String? _decodedPayload;
  String? _serverResponse;
  String? _error;

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
        _error = "Token introuvable dans le QR code.";
        _rawQrValue = rawValue;
        _token = null;
        _decodedPayload = null;
        _serverResponse = null;
      });
      return;
    }

    setState(() {
      _scanLocked = true;
      _rawQrValue = rawValue;
      _token = extractedToken;
      _decodedPayload = _decodeTokenPayload(extractedToken);
      _error = null;
      _serverResponse = null;
    });

    await _callProtectedApi(extractedToken);
  }

  String _extractToken(String value) {
    final Uri? uri = Uri.tryParse(value);
    final String? tokenFromQuery = uri?.queryParameters['token'];
    if (tokenFromQuery != null && tokenFromQuery.isNotEmpty) {
      return tokenFromQuery;
    }

    final dynamic decoded = _tryDecodeJson(value);
    if (decoded is Map<String, dynamic>) {
      final dynamic tokenField = decoded['token'];
      if (tokenField is String && tokenField.isNotEmpty) {
        return tokenField;
      }
    }

    if (value.toLowerCase().startsWith('bearer ')) {
      return value.substring(7).trim();
    }

    return value;
  }

  dynamic _tryDecodeJson(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  String _decodeTokenPayload(String token) {
    final List<String> parts = token.split('.');
    if (parts.length < 2) {
      return 'Ce token ne ressemble pas à un JWT (payload Base64 non détecté).';
    }

    try {
      final String normalized = base64Url.normalize(parts[1]);
      final List<int> payloadBytes = base64Url.decode(normalized);
      final String payloadText = utf8.decode(payloadBytes);
      final dynamic payloadJson = _tryDecodeJson(payloadText);

      if (payloadJson != null) {
        return const JsonEncoder.withIndent('  ').convert(payloadJson);
      }

      return payloadText;
    } catch (_) {
      return 'Impossible de décoder le payload Base64 du token.';
    }
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
    if (uri == null || !uri.hasScheme) {
      setState(() {
        _isLoading = false;
        _error = 'URL API invalide.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      setState(() {
        _serverResponse =
            "Status ${response.statusCode}\n\n${response.body.isEmpty ? '(Aucune donnée)' : response.body}";
      });
    } catch (exception) {
      setState(() {
        _error = 'Erreur réseau: $exception';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetScan() {
    setState(() {
      _scanLocked = false;
      _rawQrValue = null;
      _token = null;
      _decodedPayload = null;
      _serverResponse = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR + Token'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                child: MobileScanner(
                  onDetect: _handleDetection,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
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
            if (_rawQrValue != null)
              Text(
                'QR brut: $_rawQrValue',
                style: const TextStyle(fontSize: 12),
              ),
            if (_token != null)
              Text(
                'Token: $_token',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            if (_decodedPayload != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Payload décodé (Base64):',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(_decodedPayload!),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
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
