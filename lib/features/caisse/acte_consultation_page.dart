import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../../core/services/taka_usb_service.dart';

class ActeConsultationPage extends StatefulWidget {
  const ActeConsultationPage({super.key});

  @override
  State<ActeConsultationPage> createState() => _ActeConsultationPageState();
}

class _ActeConsultationPageState extends State<ActeConsultationPage> {
  final takaUsb = TakaUsbService();
  String status = "Press READ";
  bool isLoading = false;
  Map<String, dynamic>? cardData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Acte et consultation")),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              if (cardData != null)
                _buildCardDataDisplay()
              else
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Card Reading Status",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _readCard,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text("READ CARD"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _disconnect,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  backgroundColor: Colors.red,
                ),
                child: const Text("DISCONNECT"),
              ),
              if (cardData != null) ...[
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    setState(() => cardData = null);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text("CLEAR DATA"),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardDataDisplay() {
    final firstName = cardData?['firstName'] ?? 'N/A';
    final lastName = cardData?['lastName'] ?? 'N/A';
    final cardId = cardData?['cardId'] ?? 'N/A';
    final birthDate = cardData?['date_naissance'] ?? 'N/A';
    final gender = cardData?['gender'] ?? 'N/A';
    final country = cardData?['countryCode'] ?? 'N/A';
    final faceImageUri = cardData?['faceImagePath'] as String?;
    final faceImageBase64 = cardData?['faceImageBase64'] as String?;

    debugPrint('\n=== _buildCardDataDisplay ===');
    debugPrint('cardData keys: ${cardData?.keys.toList()}');
    debugPrint('faceImageUri: "$faceImageUri"');
    debugPrint(
        'faceImageBase64 present: ${faceImageBase64 != null}, length: ${faceImageBase64?.length}');
    if (faceImageBase64 != null && faceImageBase64.length < 100) {
      debugPrint('faceImageBase64 content: "$faceImageBase64"');
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        border: Border.all(color: Colors.teal, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Affiliation",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Icon(Icons.person, color: Colors.white, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoWidget(faceImageUri, faceImageBase64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow("PATIENT ID", cardId),
                    const SizedBox(height: 8),
                    _buildInfoRow("DATE DE NAISSANCE", birthDate),
                    const SizedBox(height: 8),
                    _buildInfoRow("GENRE", gender),
                    const SizedBox(height: 8),
                    _buildInfoRow("PAYS", country),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("INFORMATIONS"),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.teal.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("Prénom", firstName),
                const Divider(height: 12),
                _buildDetailRow("Nom", lastName),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text("Ajouter"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildPhotoWidget(String? faceImageUri, String? faceImageBase64) {
    debugPrint('\n================================');
    debugPrint('_buildPhotoWidget called');
    debugPrint('faceImageUri: $faceImageUri');
    debugPrint('faceImageBase64 is null: ${faceImageBase64 == null}');
    debugPrint('faceImageBase64 is empty: ${faceImageBase64?.isEmpty}');
    if (faceImageBase64 != null) {
      debugPrint('faceImageBase64 length: ${faceImageBase64.length}');
      debugPrint(
          'faceImageBase64 first 50 chars: ${faceImageBase64.substring(0, faceImageBase64.length > 50 ? 50 : faceImageBase64.length)}');
    }
    debugPrint('================================\n');

    // if we have base64 content, try to render it directly
    if (faceImageBase64 != null && faceImageBase64.isNotEmpty) {
      final previewLen =
          faceImageBase64.length > 100 ? 100 : faceImageBase64.length;
      debugPrint(
          'Base64 processing: length=${faceImageBase64.length}, first${previewLen}chars=${faceImageBase64.substring(0, previewLen)}');
      try {
        final bytes = base64Decode(faceImageBase64);
        debugPrint('✓ Decoded base64 successfully: ${bytes.length} bytes');

        // Show hex dump of first 16 bytes
        String hexDump = '';
        final hexLen = bytes.length > 16 ? 16 : bytes.length;
        for (int i = 0; i < hexLen; i++) {
          hexDump += '${bytes[i].toRadixString(16).padLeft(2, '0')} ';
        }
        debugPrint('First $hexLen bytes (hex): $hexDump');

        // Check if this might be a JP2 format based on magic bytes
        // JP2 signature: 00 00 00 0C 6A 50 20 20
        bool isJp2 = bytes.length >= 8 &&
            bytes[0] == 0x00 &&
            bytes[1] == 0x00 &&
            bytes[2] == 0x00 &&
            bytes[3] == 0x0C &&
            bytes[4] == 0x6A &&
            bytes[5] == 0x50 &&
            // corrected byte 6 (was 0x32 previously)
            bytes[6] == 0x20 &&
            bytes[7] == 0x20;
        // J2K signature: FF 4F
        bool isJ2k = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0x4F;

        debugPrint(
            'JP2/J2K detection: isJp2=$isJp2, isJ2k=$isJ2k, bytes[0]=0x${bytes[0].toRadixString(16)}, bytes[1]=0x${bytes[1].toRadixString(16)}');

        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Image.memory error: $error\nStackTrace: $stackTrace');
              // Check if it's a JP2/J2K format that's not supported
              if (isJp2 || isJ2k) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported,
                        color: Colors.orange.shade600, size: 30),
                    SizedBox(height: 4),
                    Text('Format\nJP2 non\nsupporté',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 7, color: Colors.orange.shade600)),
                  ],
                );
              }
              return Icon(Icons.image_not_supported,
                  color: Colors.red.shade600, size: 40);
            },
          ),
        );
      } catch (e) {
        debugPrint('Base64 decode failed: $e');
        // fall through to file handling
      }
    }

    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        border: Border.all(color: Colors.teal, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: faceImageUri != null &&
              faceImageUri.isNotEmpty &&
              faceImageUri != 'null'
          ? FutureBuilder<bool>(
              future: _checkFileExists(faceImageUri),
              builder: (context, snapshot) {
                debugPrint(
                    'File existence check for "$faceImageUri": ${snapshot.data}, state: ${snapshot.connectionState}');

                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.data == true) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(faceImageUri),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint(
                              'Image.file() load error: $error\nStackTrace: $stackTrace');
                          // Check if it's likely a JP2 file based on extension
                          if (faceImageUri.endsWith('.jp2') ||
                              faceImageUri.endsWith('.j2k')) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported,
                                    color: Colors.orange.shade600, size: 30),
                                SizedBox(height: 4),
                                Text('Format\nJP2 non\nsupporté',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 7,
                                        color: Colors.orange.shade600)),
                              ],
                            );
                          }
                          return Icon(Icons.image_not_supported,
                              color: Colors.red.shade600, size: 40);
                        },
                      ),
                    );
                  } else {
                    debugPrint('File does not exist at: $faceImageUri');
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.file_present,
                            color: Colors.red.shade600, size: 30),
                        SizedBox(height: 4),
                        Text('Fichier\nintrouvable',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 8, color: Colors.red)),
                      ],
                    );
                  }
                } else {
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  );
                }
              },
            )
          : Icon(Icons.image, color: Colors.grey.shade600, size: 40),
    );
  }

  Future<void> _readCard() async {
    setState(() {
      isLoading = true;
      status = "Connecting...";
      cardData = null;
    });

    bool connected = await takaUsb.connect();
    if (!connected) {
      setState(() {
        status = "USB NOT FOUND";
        isLoading = false;
      });
      return;
    }

    setState(() => status = "USB CONNECTING...");

    String response = "NO PERMISSION";
    int retries = 10;
    while (retries-- > 0 && response == "NO PERMISSION") {
      await Future.delayed(const Duration(seconds: 1));
      response = await takaUsb.readCard();
    }

    try {
      Map<String, dynamic> parsedData = _parseMRZResponse(response);

      debugPrint('\n=== BEFORE setState in _readCard ===');
      debugPrint('parsedData keys: ${parsedData.keys.toList()}');
      debugPrint('parsedData["faceImagePath"]: ${parsedData["faceImagePath"]}');
      debugPrint(
          'parsedData["faceImageBase64"] present: ${parsedData.containsKey("faceImageBase64")}');
      if (parsedData.containsKey("faceImageBase64")) {
        debugPrint(
            'parsedData["faceImageBase64"] length: ${(parsedData["faceImageBase64"] as String?)?.length}');
      }

      setState(() {
        cardData = parsedData;
        status = "CARD READ SUCCESS";
        isLoading = false;
      });

      debugPrint('\n=== AFTER setState in _readCard ===');
      debugPrint('this.cardData keys: ${cardData?.keys.toList()}');
    } catch (e) {
      setState(() {
        status = "ERROR: $e";
        isLoading = false;
      });
    }
  }

  Map<String, dynamic> _parseMRZResponse(String response) {
    debugPrint('\n\n=== COMPLETE RESPONSE ===');
    debugPrint('Full response:\n$response');
    debugPrint('Response length: ${response.length}');

    final lines = response.split('\n');
    String mrzLine = '';
    String faceImageUri = '';
    String faceBase64 = ''; // may contain raw bytes of JP2 or other formats

    debugPrint('\n=== PARSING RESPONSE ===');
    debugPrint('Number of lines: ${lines.length}');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      debugPrint('Line[$i] length=${line.length} content="$line"');

      if (line.startsWith('MRZ:')) {
        mrzLine = line.substring(4).trim();
        debugPrint('  ✓ Found MRZ line: "$mrzLine"');
      } else if (line.startsWith('FACE:')) {
        faceImageUri = line.substring(5).trim();
        debugPrint('  ✓ Found FACE line: "$faceImageUri"');
        debugPrint('    - Is empty: ${faceImageUri.isEmpty}');
        debugPrint('    - Is "null" string: ${faceImageUri == "null"}');
        debugPrint('    - Contains spaces: ${faceImageUri.contains(" ")}');
      } else if (line.startsWith('FACE_BASE64:')) {
        faceBase64 = line.substring(12).trim();
        debugPrint('  ✓ Found FACE_BASE64 (len=${faceBase64.length})');
      }
    }

    debugPrint('\n=== EXTRACTION RESULTS ===');
    debugPrint('MRZ: "$mrzLine" (empty: ${mrzLine.isEmpty})');
    debugPrint('Face URI: "$faceImageUri" (empty: ${faceImageUri.isEmpty})');
    debugPrint('Face base64 length: ${faceBase64.length}');
    if (mrzLine.isEmpty) {
      throw Exception('No MRZ data found in response');
    }

    var parsedData = _parseMRZ(mrzLine);

    if (faceImageUri.isNotEmpty && faceImageUri != 'null') {
      parsedData['faceImagePath'] = faceImageUri;
      debugPrint('✓ Added faceImagePath to parsedData: "${faceImageUri}"');
    } else if (faceBase64.isNotEmpty) {
      parsedData['faceImageBase64'] = faceBase64;
      debugPrint(
          '✓ Added faceImageBase64 to parsedData (len=${faceBase64.length})');
    } else {
      debugPrint('✗ No face image added to parsedData');
    }

    debugPrint('=== PARSING COMPLETE ===\n');
    return parsedData;
  }

  Map<String, dynamic> _parseMRZ(String mrz) {
    final parsedData = {
      'mrz': mrz,
      'countryCode': null,
      'cardId': null,
      'gender': null,
      'deliveryDate': null,
      'uniqueId': null,
      'lastName': null,
      'firstName': null,
      'date_naissance': null,
    };

    try {
      var rev = mrz.split('').reversed.join();
      rev = rev.replaceAll(RegExp(r'^<+'), '');
      var firstNameIdx = rev.indexOf('<<');
      if (firstNameIdx < 0) return parsedData;
      var firstName = rev.substring(0, firstNameIdx);
      rev = rev.replaceFirst(firstName, '');
      rev = rev.replaceFirst(RegExp(r'^<<+'), '');

      // Find first digit in lastName
      var lastNameIdx = _findFirstDigitIndex(rev);
      if (lastNameIdx < 0) return parsedData;
      var lastName = rev.substring(0, lastNameIdx);
      rev = rev.replaceFirst(lastName, '');
      if (rev.length > 1) rev = rev.substring(1);
      var nextPos = rev.indexOf('<');
      if (nextPos < 0) nextPos = rev.indexOf('N');
      if (nextPos < 0) nextPos = rev.length;
      var uniqueId = rev.substring(0, nextPos);
      rev = rev.replaceFirst(uniqueId, '');
      if (rev.length > 1) rev = rev.substring(1);
      var ccDateIdx = rev.indexOf('<');
      if (ccDateIdx < 0) ccDateIdx = rev.length;
      var cc_date = rev.substring(0, ccDateIdx);

      parsedData['firstName'] =
          firstName.split('').reversed.join().replaceAll('<', ' ');
      parsedData['lastName'] = lastName.split('').reversed.join();
      parsedData['uniqueId'] =
          uniqueId.split('').reversed.join().replaceAll('<', '');
      rev = rev.replaceFirst(cc_date, '');

      if (cc_date.contains('NEB')) {
        cc_date = cc_date.replaceAll('NEB', '');
        parsedData['countryCode'] = 'BEN';
      } else if (cc_date.contains('EB')) {
        cc_date = cc_date.replaceAll('EB', '');
        parsedData['countryCode'] = 'BEN';
      }

      cc_date = cc_date.split('').reversed.join();
      if (cc_date.length >= 6) {
        parsedData['date_naissance'] = cc_date.substring(0, 6);
      }

      if (cc_date.contains('M')) {
        parsedData['gender'] = 'M';
      } else if (cc_date.contains('F')) {
        parsedData['gender'] = 'F';
      }

      rev = rev.replaceAll(RegExp(r'^<+'), '');
      var cardNumIdx = rev.indexOf('<');
      if (cardNumIdx > 1) {
        var cardNumber = rev.substring(1, cardNumIdx);
        parsedData['cardId'] = cardNumber
            .split('')
            .reversed
            .join()
            .replaceAll(RegExp(r'[A-Za-z]+'), '');
      }

      var dateStr = parsedData['date_naissance'] as String?;
      if (dateStr != null && dateStr.length >= 6) {
        var yearSuffix = int.tryParse(dateStr.substring(0, 2)) ?? 0;
        var year = yearSuffix < 50 ? 2000 + yearSuffix : 1900 + yearSuffix;
        var month = dateStr.substring(2, 4);
        var day = dateStr.substring(4, 6);
        parsedData['date_naissance'] = '$day-$month-$year';
      }
    } catch (e) {
      debugPrint('MRZ_PARSE Error parsing MRZ: $e');
    }

    return parsedData;
  }

  int _findFirstDigitIndex(String str) {
    for (int i = 0; i < str.length; i++) {
      int code = str.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        // 0-9 in ASCII
        return i;
      }
    }
    return -1;
  }

  Future<bool> _checkFileExists(String filePath) async {
    try {
      final file = File(filePath);
      bool exists = await file.exists();
      debugPrint('File check: $filePath exists=$exists');
      if (exists) {
        final fileSize = await file.length();
        debugPrint('File size: $fileSize bytes');
      }
      return exists;
    } catch (e) {
      debugPrint('Error checking file existence: $e');
      return false;
    }
  }

  Future<void> _disconnect() async {
    await takaUsb.disconnect();
    setState(() => status = "DISCONNECTED");
  }
}
