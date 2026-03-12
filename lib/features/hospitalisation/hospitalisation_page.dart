import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../../core/services/taka_usb_service.dart';

// ─── Couleurs principales ────────────────────────────────────────────────────
const kGreen = Color(0xFF4CAF8C);
const kGreenLight = Color(0xFFE8F5F0);
const kGreenBorder = Color(0xFFB2DFCF);
const kGreenDark = Color(0xFF2E7D5E);

class HospitalisationPage extends StatefulWidget {
  const HospitalisationPage({super.key});

  @override
  State<HospitalisationPage> createState() => _HospitalisationPageState();
}

class _HospitalisationPageState extends State<HospitalisationPage> {
  // ── Taka USB ──────────────────────────────────────────────────────────────
  final takaUsb = TakaUsbService();
  String status = "Press READ";
  bool isLoading = false;
  Map<String, dynamic>? cardData;

  // ── Formulaire ────────────────────────────────────────────────────────────
  DateTime? dateDebut;
  DateTime? dateFin;
  final TextEditingController medecinCtrl = TextEditingController();
  final TextEditingController anesthesisteCtrl = TextEditingController();
  final TextEditingController adresseCtrl = TextEditingController();
  final TextEditingController telephoneCtrl = TextEditingController();

  List<Map<String, dynamic>> actes = [];
  List<String> medicaments = [];
  List<String> analyses = [];
  List<String> imageries = [];
  List<String> affections = [];

  // ── Statut workflow ───────────────────────────────────────────────────────
  int statusStep = 0; // 0=Brouillon, 1=Pré-validée, 2=Validée

  @override
  void dispose() {
    medecinCtrl.dispose();
    anesthesisteCtrl.dispose();
    adresseCtrl.dispose();
    telephoneCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LECTURE CARTE TAKA (même logique que ActeConsultationPage)
  // ─────────────────────────────────────────────────────────────────────────
  // Copie exacte de ActeConsultationPage._readCard()
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
      debugPrint('parsedData["faceImageBase64"] present: ${parsedData.containsKey("faceImageBase64")}');
      if (parsedData.containsKey("faceImageBase64")) {
        debugPrint('parsedData["faceImageBase64"] length: ${(parsedData["faceImageBase64"] as String?)?.length}');
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

  Future<void> _disconnect() async {
    await takaUsb.disconnect();
    setState(() => status = "DISCONNECTED");
  }

  // Copie exacte de ActeConsultationPage._parseMRZResponse()
  Map<String, dynamic> _parseMRZResponse(String response) {
    debugPrint('\n\n=== COMPLETE RESPONSE ===');
    debugPrint('Full response:\n$response');
    debugPrint('Response length: ${response.length}');

    final lines = response.split('\n');
    String mrzLine = '';
    String faceImageUri = '';
    String faceBase64 = '';

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
      debugPrint('✓ Added faceImagePath to parsedData: "$faceImageUri"');
    } else if (faceBase64.isNotEmpty) {
      parsedData['faceImageBase64'] = faceBase64;
      debugPrint('✓ Added faceImageBase64 to parsedData (len=${faceBase64.length})');
    } else {
      debugPrint('✗ No face image added to parsedData');
    }

    debugPrint('=== PARSING COMPLETE ===\n');
    return parsedData;
  }

  // Copie exacte de ActeConsultationPage._parseMRZ()
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
      final code = str.codeUnitAt(i);
      if (code >= 48 && code <= 57) return i;
    }
    return -1;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  int get _dureeHospitalisation {
    if (dateDebut == null || dateFin == null) return 0;
    return dateFin!.difference(dateDebut!).inDays;
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pickDate(bool isDebut) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isDebut) {
          dateDebut = picked;
        } else {
          dateFin = picked;
        }
      });
    }
  }

  void _calculer() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calcul en cours...'),
        backgroundColor: kGreen,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPatientCard(),
                  const SizedBox(height: 12),
                  _buildHospitalisationCard(),
                  const SizedBox(height: 8),
                  _buildDureeCard(),
                  const SizedBox(height: 8),
                  _buildSectionRow("Affection", "+ Choisir une affection",
                      () => _addItem('affection')),
                  if (affections.isEmpty)
                    _buildEmptyLabel("Aucune affection choisie."),
                  ...affections.map((a) => _buildChip(a, () {
                        setState(() => affections.remove(a));
                      })),
                  const SizedBox(height: 8),
                  _buildSectionRow("Acte et consultation", "+ Ajouter un acte",
                      () => _addItem('acte')),
                  ...actes.map((a) => _buildChip(
                        a['label'] ?? '',
                        () => setState(() => actes.remove(a)),
                      )),
                  const SizedBox(height: 8),
                  _buildSectionRow("Pharmacie", "+ Ajouter un médicament",
                      () => _addItem('medicament')),
                  ...medicaments.map((m) => _buildChip(
                        m,
                        () => setState(() => medicaments.remove(m)),
                      )),
                  const SizedBox(height: 8),
                  _buildSectionRow(
                      "Labo", "+ Ajouter une analyse", () => _addItem('labo')),
                  ...analyses.map((a) => _buildChip(
                        a,
                        () => setState(() => analyses.remove(a)),
                      )),
                  const SizedBox(height: 8),
                  _buildSectionRow("Radio", "+ Ajouter une imagerie",
                      () => _addItem('radio')),
                  ...imageries.map((i) => _buildChip(
                        i,
                        () => setState(() => imageries.remove(i)),
                      )),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          _buildCalculerButton(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    const steps = ['Brouillon', 'Pré-validée', 'Validée'];
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            );
          }
          final idx = i ~/ 2;
          final isActive = idx == statusStep;
          return GestureDetector(
            onTap: () => setState(() => statusStep = idx),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isActive ? kGreen : Colors.white,
                border: Border.all(
                    color: isActive ? kGreen : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                steps[idx],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.white : Colors.grey,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Carte patient ─────────────────────────────────────────────────────────
  // Si la carte n'est pas encore lue → état vide avec bouton READ CARD
  // Si la carte est lue → affichage identique à ActeConsultationPage._buildCardDataDisplay()
  Widget _buildPatientCard() {
    if (cardData == null) {
      return _buildEmptyPatientCard();
    }
    return _buildCardDataDisplay();
  }

  // État vide avant lecture
  Widget _buildEmptyPatientCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kGreenLight,
        border: Border.all(color: kGreenBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Photo placeholder
          Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              border: Border.all(color: kGreenBorder, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person, size: 40, color: Colors.grey.shade500),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Patient',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Icon(Icons.people, color: kGreen, size: 22),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.credit_card, color: Colors.blue.shade400, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isLoading ? status : 'Appuyez sur READ CARD pour lire la carte',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      if (isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _readCard,
                        icon: isLoading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.nfc, size: 16),
                        label: Text(
                          isLoading ? 'Lecture...' : 'READ CARD',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.usb_off, size: 16),
                      label: const Text('USB', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Copie exacte de ActeConsultationPage._buildCardDataDisplay()
  // + boutons READ/DISCONNECT/CLEAR intégrés en bas
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
    debugPrint('faceImageBase64 present: ${faceImageBase64 != null}, length: ${faceImageBase64?.length}');
    if (faceImageBase64 != null && faceImageBase64.length < 100) {
      debugPrint('faceImageBase64 content: "$faceImageBase64"');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        border: Border.all(color: Colors.teal, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header "Affiliation" — identique à ActeConsultationPage ──────
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
                const Icon(Icons.person, color: Colors.white, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Photo + infos identiques à ActeConsultationPage ──────────────
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
          const SizedBox(height: 16),
          // ── Section INFORMATIONS — identique à ActeConsultationPage ──────
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
          const SizedBox(height: 12),
          // ── Champs Adresse / Téléphone ───────────────────────────────────
          Row(
            children: [
              Expanded(child: _buildInputField('ADRESSE', adresseCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _buildInputField('TÉLÉPHONE', telephoneCtrl, keyboardType: TextInputType.phone)),
            ],
          ),
          const SizedBox(height: 12),
          // ── Boutons READ / DISCONNECT / CLEAR ────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : _readCard,
                icon: isLoading
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Icon(Icons.nfc, size: 16),
                label: Text(isLoading ? 'Lecture...' : 'READ CARD', style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.usb_off, size: 16),
                label: const Text('DISCONNECT', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => cardData = null),
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('CLEAR', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Copie exacte de ActeConsultationPage._buildSectionHeader()
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

  // Copie exacte de ActeConsultationPage._buildInfoRow()
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
        ),
      ],
    );
  }

  // Copie exacte de ActeConsultationPage._buildDetailRow()
  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text("$label: ", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87)),
      ],
    );
  }

  // ── Photo widget — copie exacte de ActeConsultationPage._buildPhotoWidget() ──
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
            bytes[6] == 0x20 &&
            bytes[7] == 0x20;
        // J2K signature: FF 4F
        bool isJ2k = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0x4F;

        debugPrint(
            'JP2/J2K detection: isJp2=$isJp2, isJ2k=$isJ2k, bytes[0]=0x${bytes[0].toRadixString(16)}, bytes[1]=0x${bytes[1].toRadixString(16)}');

        return Container(
          width: 80,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            border: Border.all(color: kGreenBorder, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Image.memory error: $error\nStackTrace: $stackTrace');
                if (isJp2 || isJ2k) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported,
                          color: Colors.orange.shade600, size: 30),
                      const SizedBox(height: 4),
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
        border: Border.all(color: kGreenBorder, width: 2),
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
                          if (faceImageUri.endsWith('.jp2') ||
                              faceImageUri.endsWith('.j2k')) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported,
                                    color: Colors.orange.shade600, size: 30),
                                const SizedBox(height: 4),
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
                        const SizedBox(height: 4),
                        Text('Fichier\nintrouvable',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 8, color: Colors.red)),
                      ],
                    );
                  }
                } else {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
              },
            )
          : Icon(Icons.image, color: Colors.grey.shade600, size: 40),
    );
  }

  // Copie exacte de ActeConsultationPage._checkFileExists()
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

  // ── Hospitalisation card ──────────────────────────────────────────────────
  Widget _buildHospitalisationCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kGreenBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel("DATE DÉBUT D'HOSPITALISATION"),
                    const SizedBox(height: 4),
                    _buildDatePicker(dateDebut, () => _pickDate(true)),
                    const SizedBox(height: 8),
                    _buildFieldLabel("DATE FIN D'HOSPITALISATION"),
                    const SizedBox(height: 4),
                    _buildDatePicker(dateFin, () => _pickDate(false)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel("MÉDECIN"),
                    const SizedBox(height: 4),
                    _buildTextInput(medecinCtrl),
                    const SizedBox(height: 8),
                    _buildFieldLabel("ANESTHÉSISTE"),
                    const SizedBox(height: 4),
                    _buildTextInput(anesthesisteCtrl),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null ? _formatDate(date) : 'jj/mm/aaaa',
                style: TextStyle(
                  fontSize: 13,
                  color: date != null
                      ? Colors.black87
                      : Colors.grey.shade500,
                ),
              ),
            ),
            Icon(Icons.calendar_today,
                size: 16, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput(TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: kGreen),
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 2),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: kGreen),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
      ),
    );
  }

  // ── Durée card ────────────────────────────────────────────────────────────
  Widget _buildDureeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: kGreen, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Durée d'hospitalisation (jours)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_dureeHospitalisation} Jour(s)',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // ── Section row ───────────────────────────────────────────────────────────
  Widget _buildSectionRow(
      String title, String btnLabel, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: kGreen, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14),
            ),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child:
                  Text(btnLabel, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      child: Text(text,
          style:
              const TextStyle(fontSize: 13, color: Colors.black54)),
    );
  }

  Widget _buildChip(String label, VoidCallback onDelete) {
    return Container(
      margin: const EdgeInsets.only(left: 12, top: 4),
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kGreenLight,
        border: Border.all(color: kGreenBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Calculer button ───────────────────────────────────────────────────────
  Widget _buildCalculerButton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _calculer,
          style: ElevatedButton.styleFrom(
            backgroundColor: kGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text(
            'Calculer',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.black54),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.home, color: Colors.black54),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.description, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ── Ajout d'items (dialog simple) ─────────────────────────────────────────
  void _addItem(String type) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Ajouter $type'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nom...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) {
                setState(() {
                  switch (type) {
                    case 'affection':
                      affections.add(v);
                      break;
                    case 'acte':
                      actes.add({'label': v});
                      break;
                    case 'medicament':
                      medicaments.add(v);
                      break;
                    case 'labo':
                      analyses.add(v);
                      break;
                    case 'radio':
                      imageries.add(v);
                      break;
                  }
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kGreen),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}