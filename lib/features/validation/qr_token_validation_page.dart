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

        _serverResponse = null;
      });
      return;
    }

    setState(() {
      _scanLocked = true;
      _rawQrValue = rawValue;
      _token = extractedToken;

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


    return value;
  }

  dynamic _tryDecodeJson(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
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
