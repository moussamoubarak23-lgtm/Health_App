import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Services/pdf_service.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum PatientTab { consultations, vaccination, actes, ordonnances, bilanBio, bilanRx, certificats, compteRendu, comptabilite, factures }

class PatientDetailScreen extends StatefulWidget {
  final Map patient;
  const PatientDetailScreen({super.key, required this.patient});
  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  PatientTab _activeTab = PatientTab.consultations;
  List records = [];
  List bpMeasurements = [];
  List bodyMeasurements = [];
  List availableActs = [];
  List selectedActs = [];
  bool loading = true;
  bool sehatiMeasuresEnabled = false;
  late Map currentPatient;

  // Infos Cabinet pour Ordonnances/Certificats
  String doctorName = '';
  String cabinetAddress = '';
  String cabinetPhone = '';
  String cabinetEmail = '';
  String cabinetFax = '';
  String? cabinetLogoPath;
  String specialtyFr = '';
  String specialtyAr = '';
  String experienceFr = '';
  String experienceAr = '';

  final GlobalKey qrKey = GlobalKey();

  static const List<String> nationalities = [
    "Marocaine", "Française", "Algérienne", "Tunisienne", "Espagnole", "Italienne", "Sénégalaise", "Malienne", "Ivoirienne", "Américaine", "Canadienne", "Allemande", "Belge", "Suisse", "Libyenne", "Égyptienne", "Saoudienne", "Émiratie", "Qatarienne", "Koweïtienne", "Bahreïnie", "Omanaise", "Jordanienne", "Libanaise", "Syrienne", "Irakienne", "Yéménite", "Soudanaise", "Mauritanienne", "Portugaise", "Néerlandaise", "Nigérienne", "Gabonaise", "Togolaise"
  ];

  @override
  void initState() {
    super.initState();
    currentPatient = Map.from(widget.patient);
    _loadData();
    _loadCabinetSettings();
    _loadModulesSettings();
  }

  String _s(dynamic val) => (val is String && val != "false") ? val : '';

  /// Extrait la nationalité depuis le commentaire Odoo (souvent avec HTML type `<p>`).
  String _nationalityFromComment(dynamic comment) {
    if (comment == null || comment.toString().isEmpty) return 'Marocaine';
    final s = comment.toString();
    if (!s.contains('Nationalité:')) return 'Marocaine';
    final parts = s.split('Nationalité:');
    if (parts.length < 2) return 'Marocaine';
    var raw = parts[1].trim();
    raw = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
    raw = raw.replaceAll('&nbsp;', ' ');
    raw = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.contains('|')) raw = raw.split('|').first.trim();
    raw = raw.split(RegExp(r'[\n\r]')).first.trim();
    raw = raw.replaceAll('/p>', '').trim();
    if (raw.isEmpty) return 'Marocaine';
    return raw;
  }

  /// Affiche une valeur numérique issue de la balance avec 2 décimales.
  String _fmt2(dynamic val) {
    if (val == null) return '—';
    final n = val is num ? val.toDouble() : double.tryParse(val.toString().trim().replaceAll(',', '.'));
    if (n == null || n.isNaN) return '—';
    return n.toStringAsFixed(2);
  }

  Future<void> _loadCabinetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        doctorName = prefs.getString('doctor_name') ?? 'Médecin';
        cabinetAddress = prefs.getString('cabinet_address') ?? '';
        cabinetPhone = prefs.getString('cabinet_phone') ?? '';
        cabinetEmail = prefs.getString('cabinet_email') ?? '';
        cabinetFax = prefs.getString('cabinet_fax') ?? '';
        cabinetLogoPath = prefs.getString('cabinet_logo_path');
        specialtyFr = prefs.getString('cabinet_specialty_fr') ?? 'Médecin Généraliste';
        specialtyAr = prefs.getString('cabinet_specialty_ar') ?? 'طبيب عام';
        experienceFr = prefs.getString('cabinet_experience_fr') ?? '';
        experienceAr = prefs.getString('cabinet_experience_ar') ?? '';
      });
    }
  }

  Future<void> _loadModulesSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      sehatiMeasuresEnabled = prefs.getBool('module_sehati_measures_enabled') ?? false;
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => loading = true);
    final res = await Future.wait([
      OdooApi.getMedicalRecords(patientId: currentPatient['id']),
      OdooApi.getBpMeasurements(patientId: currentPatient['id']),
      OdooApi.getMedicalActs(),
      OdooApi.getBodyMeasurements(patientId: currentPatient['id']),
    ]);
    if (mounted) {
      setState(() {
        records = res[0];
        bpMeasurements = res[1];
        availableActs = res[2];
        bodyMeasurements = res[3];
        loading = false;
      });
    }
  }

  void _showCertificateDialog() {
    final loc = AppLocalizations.of(context);
    final patientNameCtrl = TextEditingController(text: _s(currentPatient['name']));
    final contentCtrl = TextEditingController(text: "L'état de santé de l'intéressé(e) nécessite un repos de ... jours à compter du ...");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.description, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(loc.t('medicalCertificate'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: patientNameCtrl,
                decoration: InputDecoration(
                  labelText: loc.t('patientNameLabel'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: loc.t('certificateContent'),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))),
          ElevatedButton.icon(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await PdfService.generateAndPrintCertificate(
                doctorName: doctorName,
                patientName: patientNameCtrl.text,
                content: contentCtrl.text,
                date: DateTime.now(),
                cabinetAddress: cabinetAddress,
                cabinetPhone: cabinetPhone,
                cabinetEmail: cabinetEmail,
                cabinetFax: cabinetFax,
                logoPath: cabinetLogoPath,
                specialtyFr: specialtyFr,
                experienceFr: experienceFr,
              );
              if (!mounted) return;
              if (navigator.canPop()) navigator.pop();
            },
            icon: const Icon(Icons.print),
            label: Text(loc.t('printPdf')),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showPrescriptionDialog() {
    final loc = AppLocalizations.of(context);
    final patientNameCtrl = TextEditingController(text: _s(currentPatient['name']));
    final contentCtrl = TextEditingController(text: "1. \n2. \n3. ");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.green),
            const SizedBox(width: 10),
            Text(loc.t('newPrescription'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: patientNameCtrl,
                decoration: InputDecoration(
                  labelText: loc.t('patientNameLabel'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentCtrl,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: loc.t('medicationPosology'),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))),
          ElevatedButton.icon(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await PdfService.generateAndPrintPrescription(
                doctorName: doctorName,
                patientName: patientNameCtrl.text,
                content: contentCtrl.text,
                date: DateTime.now(),
                cabinetAddress: cabinetAddress,
                cabinetPhone: cabinetPhone,
                cabinetEmail: cabinetEmail,
                cabinetFax: cabinetFax,
                logoPath: cabinetLogoPath,
                specialtyFr: specialtyFr,
                specialtyAr: specialtyAr,
                experienceFr: experienceFr,
                experienceAr: experienceAr,
              );
              if (!mounted) return;
              if (navigator.canPop()) navigator.pop();
            },
            icon: const Icon(Icons.print),
            label: Text(loc.t('printPdf')),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showPatientEditDialog(AppLocalizations loc) {
    final nameCtrl = TextEditingController(text: _s(currentPatient['name']));
    final phoneCtrl = TextEditingController(text: _s(currentPatient['phone']));
    final ageCtrl = TextEditingController(text: currentPatient['age']?.toString() ?? '');
    final cinCtrl = TextEditingController(text: _s(currentPatient['patient_code']));
    final dossierCtrl = TextEditingController(text: _s(currentPatient['medical_file_number']));
    String couverture = _s(currentPatient['insurance_id']).isEmpty ? "Sans" : _s(currentPatient['insurance_id']);
    if (!["Sans", "AMO", "RAMED", "CNOPS", "Privé"].contains(couverture)) couverture = "Sans";

    String nationalite = _nationalityFromComment(currentPatient['comment']);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(loc.t('editPatientSheet'), style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const Divider(height: 32),
                _editField("Nom Complet (*)", nameCtrl, Icons.person_rounded),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _editField("Numéro de Dossier", dossierCtrl, Icons.folder_shared_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _editField("CIN (Carte Nationale)", cinCtrl, Icons.badge_rounded)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _editField("Téléphone", phoneCtrl, Icons.phone_rounded, inputType: TextInputType.phone)),
                  const SizedBox(width: 16),
                  Expanded(child: _editField("Âge", ageCtrl, Icons.cake_rounded, inputType: TextInputType.number)),
                ]),
                const SizedBox(height: 16),
                _dropdownSearch("Nationalité (*)", nationalite, (v) => setDialogState(() => nationalite = v)),
                const SizedBox(height: 16),
                _editDropdown("Couverture sociale", couverture, ["Sans", "AMO", "RAMED", "CNOPS", "Privé"], (v) => setDialogState(() => couverture = v!)),
                const SizedBox(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      if (nameCtrl.text.isEmpty) return;
                      final res = await OdooApi.updatePatient(
                        patientId: currentPatient['id'],
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        email: '',
                        insuranceId: couverture,
                        height: currentPatient['height'] is num ? (currentPatient['height'] as num).toDouble() : 0.0,
                        age: int.tryParse(ageCtrl.text.trim()) ?? 0,
                        patientCode: cinCtrl.text.trim(),
                        medicalFileNumber: dossierCtrl.text.trim(),
                        comment: currentPatient['comment'] is String ? currentPatient['comment'].toString().replaceAll(RegExp(r'Nationalité:.*'), 'Nationalité: $nationalite') : 'Nationalité: $nationalite',
                      );
                      if (res['success']) {
                        setState(() {
                          currentPatient['name'] = nameCtrl.text.trim();
                          currentPatient['phone'] = phoneCtrl.text.trim();
                          currentPatient['age'] = int.tryParse(ageCtrl.text.trim()) ?? 0;
                          currentPatient['insurance_id'] = couverture;
                          currentPatient['patient_code'] = cinCtrl.text.trim();
                          currentPatient['medical_file_number'] = dossierCtrl.text.trim();
                          currentPatient['comment'] = currentPatient['comment'] is String ? currentPatient['comment'].toString().replaceAll(RegExp(r'Nationalité:.*'), 'Nationalité: $nationalite') : 'Nationalité: $nationalite';
                        });
                        if (!mounted) return;
                        if (navigator.canPop()) navigator.pop();
                        messenger.showSnackBar(SnackBar(content: Text(loc.t('profileUpdatedSuccess'))));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: Text(loc.t('save')),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, IconData icon, {TextInputType inputType = TextInputType.text}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
    const SizedBox(height: 6),
    TextField(
      controller: ctrl, keyboardType: inputType,
      decoration: InputDecoration(prefixIcon: Icon(icon, size: 18), filled: true, fillColor: AppColors.inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    ),
  ]);

  Widget _editDropdown(String label, String value, List<String> items, Function(String?) onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
    const SizedBox(height: 6),
    Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: AppColors.inputFill, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged))),
  ]);

  Widget _dropdownSearch(String label, String current, Function(String) onSelected) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
      const SizedBox(height: 6),
      InkWell(
        onTap: () => _showNationalityPicker(onSelected),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: AppColors.inputFill, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.public_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(current, style: GoogleFonts.dmSans())),
            const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
          ]),
        ),
      ),
    ],
  );

  void _showNationalityPicker(Function(String) onSelected) {
    String query = "";
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final list = query.isEmpty ? nationalities : nationalities.where((n) => n.toLowerCase().contains(query.toLowerCase())).toList();
          return AlertDialog(
            title: Text(loc.t('selectNationality')),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(decoration: InputDecoration(hintText: loc.t('searchHint'), prefixIcon: const Icon(Icons.search)), onChanged: (v) => setDialogState(() => query = v)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) => ListTile(
                        title: Text(list[i]),
                        onTap: () { onSelected(list[i]); Navigator.pop(context); },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _viewRecordDetails(Map record, AppLocalizations loc) {
    String dossier = _s(record['medical_file_number']);
    if (dossier.isEmpty) dossier = _s(currentPatient['medical_file_number']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [const Icon(Icons.description_outlined, color: AppColors.primary), const SizedBox(width: 10), Text(loc.t('consultDetails'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold))]),
        content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_detailItem(loc.t('medicalFileNumber'), dossier), _detailItem(loc.t('colDate'), _s(record['date_consultation'])), _detailItem(loc.t('reason'), _s(record['motif'])), const Divider(), _detailItem(loc.t('diagnostic'), _s(record['diagnostic'])), _detailItem(loc.t('prescription'), _s(record['prescription'])), _detailItem(loc.t('observations'), _s(record['observations']))]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('close')))],
      ),
    );
  }

  Widget _detailItem(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMuted)), const SizedBox(height: 4), Text(value.isEmpty ? "—" : value, style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textPrimary))]));

  Future<void> _createInvoiceFromActs(Map record) async {
    if (selectedActs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('selectAtLeastOneAct')))); return; }
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    final lines = selectedActs.map((act) => {'product_id': act['id'], 'name': act['name'], 'price': act['list_price']}).toList();
    final result = await OdooApi.createInvoice(patientId: currentPatient['id'], lines: lines);

    if (result['success']) {
      final selectedActNames = selectedActs.map((act) => act['name']).join(', ');
      await OdooApi.updateMedicalRecord(
        recordId: record['id'],
        motif: selectedActNames,
        diagnostic: _s(record['diagnostic']),
        prescription: _s(record['prescription']),
        observations: _s(record['observations']),
        state: 'invoiced',
        medicalFileNumber: _s(record['medical_file_number']),
      );
      setState(() => selectedActs = []);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('invoiceCreated'))));
      _loadData();
    }
    if (mounted) Navigator.pop(context);
  }

  void _showActSelectionDialog(Map record, AppLocalizations loc) {
    setState(() => selectedActs = []);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(loc.t('invoiceConsultation'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.t('selectPerformedActs'), style: GoogleFonts.dmSans(fontSize: 14)),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableActs.length,
                    itemBuilder: (context, index) {
                      final act = availableActs[index];
                      final isSelected = selectedActs.contains(act);
                      return CheckboxListTile(
                        title: Text(act['name']),
                        subtitle: Text("${act['list_price']} DH"),
                        value: isSelected,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedActs.add(act);
                            } else {
                              selectedActs.remove(act);
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _createInvoiceFromActs(record);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text(loc.t('createInvoice')),
            )
          ],
        ),
      ),
    );
  }

  String _generateFullQrData() {
    String text = "--- DOSSIER PATIENT ---\n";
    text += "Patient: ${_s(currentPatient['name'])}\n";
    text += "ID: ${currentPatient['id']}\n";
    text += "CIN: ${_s(currentPatient['patient_code'])}\n";
    text += "Dossier: ${_s(currentPatient['medical_file_number'])}";
    return text;
  }

  void _showQRCodeDialog() {
    final loc = AppLocalizations.of(context);
    final qrData = _generateFullQrData();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('recordOptions'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text(loc.t('recordOptionsQuestion')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _displayQrCodeOnly(qrData);
            },
            child: Text(loc.t('showQr')),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await PdfService.generateAndPrintPatientReport(
                patient: currentPatient,
                records: records,
                measurements: bpMeasurements,
                bodyMeasurements: bodyMeasurements,
              );
            },
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: Text(loc.t('pdfReport')),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<String> _generateQrPdf() async {
    final pdf = pw.Document();
    
    RenderRepaintBoundary boundary =
        qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Dossier Patient',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                _s(currentPatient['name']),
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 24),
              pw.Image(pw.MemoryImage(pngBytes), width: 200, height: 200),
              pw.SizedBox(height: 16),
              pw.Text(
                'CIN: ${_s(currentPatient['patient_code'])}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Dossier: ${_s(currentPatient['medical_file_number'])}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );

    final fileName = 'qr_patient_${_s(currentPatient['name']).replaceAll(' ', '_')}.pdf';
    final pdfBytes = await pdf.save();

    if (kIsWeb) {
      // Sur Web: déclenche le téléchargement local via le navigateur.
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      return fileName;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final file = File('${docsDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  Future<void> _shareQrAsPdf() async {
    try {
      final path = await _generateQrPdf();
      String phone = _s(currentPatient['phone']).replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.startsWith('0')) {
        phone = "212${phone.substring(1)}";
      } else if (!phone.startsWith('212') && phone.length == 9) {
        phone = "212$phone";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF QR enregistré : $path"),
            action: kIsWeb
                ? null
                : SnackBarAction(
                    label: "Ouvrir",
                    onPressed: () => launchUrl(Uri.file(path)),
                  ),
            duration: const Duration(seconds: 6),
          ),
        );
      }

      if (phone.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Numéro patient absent: WhatsApp non ouvert.")),
          );
        }
        return;
      }

      final waUrl = Uri.parse("https://wa.me/$phone");
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
      }
    }
  }

  Future<void> _saveQrAsPdf() async {
    try {
      final path = await _generateQrPdf();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("PDF enregistré : $path"),
          action: kIsWeb
              ? null
              : SnackBarAction(
                  label: "Ouvrir",
                  onPressed: () => launchUrl(Uri.file(path)),
                ),
          duration: const Duration(seconds: 6),
        ),
      );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
      }
    }
  }

  void _displayQrCodeOnly(String qrData) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Text(loc.t('qrRecord'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(_s(currentPatient['name']), style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted)),
          ],
        ),
        content: SizedBox(
          width: 350,
          height: _min(MediaQuery.of(context).size.height * 0.7, 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              RepaintBoundary(
                key: qrKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border)
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 250.0,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _shareQrAsPdf,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text("WhatsApp"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _saveQrAsPdf,
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: Text(loc.t('savePdf')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('close'))),
        ],
      ),
    );
  }

  double _min(double a, double b) => a < b ? a : b;

  void _showScheduleAppointmentDialog(AppLocalizations loc) {
    DateTime selectedDate = intl.DateFormat('dd/MM/yyyy').parse(intl.DateFormat('dd/MM/yyyy').format(DateTime.now().add(const Duration(days: 1))));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final motifCtrl = TextEditingController(text: loc.t('exampleConsultation').replaceAll("ex: ", ""));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [const Icon(Icons.calendar_month_rounded, color: AppColors.primary), const SizedBox(width: 10), Text(loc.t('scheduleAppointment'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18))]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _editField(loc.t('appointmentReason'), motifCtrl, Icons.notes_rounded),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (date != null) setDialogState(() => selectedDate = date);
                },
                child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.event, size: 18, color: AppColors.primary), const SizedBox(width: 12), Text(intl.DateFormat('dd/MM/yyyy').format(selectedDate), style: GoogleFonts.dmSans())])),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final time = await showTimePicker(context: context, initialTime: selectedTime);
                  if (time != null) setDialogState(() => selectedTime = time);
                },
                child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary), const SizedBox(width: 12), Text(selectedTime.format(context), style: GoogleFonts.dmSans())])),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scheduledDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
                final prefs = await SharedPreferences.getInstance();
                final doctorId = prefs.getInt('uid') ?? 0;
                final res = await OdooApi.addMedicalRecord(
                  patientId: currentPatient['id'],
                  doctorId: doctorId,
                  datetime: scheduledDateTime.toString().substring(0, 19),
                  consultationReason: motifCtrl.text.trim(),
                  diagnostic: '',
                  prescription: '',
                  observations: '',
                  status: 'waiting',
                  medicalFileNumber: _s(currentPatient['medical_file_number']),
                );

                if (!mounted) return;
                if (navigator.canPop()) navigator.pop(); // Close loader
                if (navigator.canPop()) navigator.pop(); // Close dialog

                if (res['success']) {
                  _showQRCodeDialog();
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text(loc.t('scheduleAppointment')),
            )
          ],
        ),
      ),
    );
  }

  void _showQuickEditRecord(Map record, AppLocalizations loc) {
    String initialDossier = _s(record['medical_file_number']);
    if (initialDossier.isEmpty) initialDossier = _s(currentPatient['medical_file_number']);

    final fileNumCtrl = TextEditingController(text: initialDossier);
    final diagCtrl = TextEditingController(text: _s(record['diagnostic']));
    final presCtrl = TextEditingController(text: _s(record['prescription']));
    final infoObsCtrl = TextEditingController(text: _s(record['observations']));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('confirmConsultation'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: fileNumCtrl, decoration: InputDecoration(labelText: loc.t('consultRecordNumber'))), TextField(controller: diagCtrl, decoration: InputDecoration(labelText: loc.t('diagnosticLabel'))), TextField(controller: presCtrl, decoration: InputDecoration(labelText: loc.t('prescription')), maxLines: 2), TextField(controller: infoObsCtrl, decoration: InputDecoration(labelText: loc.t('observations')), maxLines: 2)])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))), ElevatedButton(onPressed: () async {
          final navigator = Navigator.of(context);
          final newDossier = fileNumCtrl.text.trim();
          final res = await OdooApi.updateMedicalRecord(recordId: record['id'], motif: _s(record['motif']), diagnostic: diagCtrl.text, prescription: presCtrl.text, observations: infoObsCtrl.text, state: 'confirmed', medicalFileNumber: newDossier);

          if (newDossier.isNotEmpty && newDossier != _s(currentPatient['medical_file_number'])) {
            await OdooApi.updatePatient(
              patientId: currentPatient['id'],
              name: _s(currentPatient['name']),
              phone: _s(currentPatient['phone']),
              email: '',
              insuranceId: _s(currentPatient['insurance_id']),
              height: currentPatient['height'] is num ? (currentPatient['height'] as num).toDouble() : 0.0,
              age: currentPatient['age'] is int ? currentPatient['age'] : 0,
              patientCode: _s(currentPatient['patient_code']),
              medicalFileNumber: newDossier,
            );
            setState(() {
              currentPatient['medical_file_number'] = newDossier;
            });
          }

          if (!mounted) return;
          if (navigator.canPop()) navigator.pop();
          if (res['success']) _loadData();
        }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: Text(loc.t('validateAndConfirm')))],
      ),
    );
  }

  void _showQuickActions(AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: Text(loc.t('quickActions'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18))),
          ListTile(leading: const Icon(Icons.receipt_long, color: AppColors.primary), title: Text(loc.t('newInvoice')), onTap: () { Navigator.pop(context); setState(() => _activeTab = PatientTab.actes); }),
          ListTile(leading: const Icon(Icons.calendar_today, color: AppColors.green), title: Text(loc.t('scheduleAppointment')), onTap: () { Navigator.pop(context); _showScheduleAppointmentDialog(loc); }),
          ListTile(leading: const Icon(Icons.receipt_long_rounded, color: Colors.green), title: Text(loc.t('newPrescription')), onTap: () { Navigator.pop(context); _showPrescriptionDialog(); }),
          ListTile(leading: const Icon(Icons.assignment_rounded, color: AppColors.yellow), title: Text(loc.t('medicalCertificate')), onTap: () { Navigator.pop(context); _showCertificateDialog(); }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRtl = lang.isArabic;
    final loc = AppLocalizations.of(context);
    final p = currentPatient;

    final nationalite = _nationalityFromComment(p['comment']);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(children: [
          const Sidebar(currentRoute: '/patients'),
          Expanded(
            child: Column(children: [
              _topBar(p, loc),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: _mainContent(loc)),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: GestureDetector(onTap: () => _showPatientEditDialog(loc), child: _rightSidebar(p, loc, nationalite))),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _topBar(Map p, AppLocalizations loc) => Container(
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      Text("${loc.t('navPatients')} / ${_s(p['name'])}", style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
      const Spacer(),
      IconButton(icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary), onPressed: _showQRCodeDialog),
      const SizedBox(width: 8),
      IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)
    ]),
  );

  Widget _mainContent(AppLocalizations loc) => Column(children: [
    Row(children: [
      _actionBtn("+ ${loc.t('newConsultation')}", AppColors.primary, () => Navigator.pushNamed(context, '/add_record', arguments: currentPatient)),
      const SizedBox(width: 10),
      _actionBtn('📅 ${loc.t("scheduleRdv")}', AppColors.green, () => _showScheduleAppointmentDialog(loc)),
      const SizedBox(width: 10),
      _actionBtn("⚡ ${loc.t('quickActions')}", AppColors.primaryLight, () => _showQuickActions(loc), isSecondary: true)
    ]),
    const SizedBox(height: 16),
    _tabBar(loc),
    const SizedBox(height: 16),
    Expanded(child: _tabView(loc)),
  ]);

  Widget _actionBtn(String label, Color color, VoidCallback onTap, {bool isSecondary = false}) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: isSecondary ? AppColors.primary : Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: isSecondary ? const BorderSide(color: AppColors.border) : BorderSide.none), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    child: Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13)),
  );

  Widget _tabBar(AppLocalizations loc) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: PatientTab.values.map((t) {
      final active = _activeTab == t;
      return GestureDetector(onTap: () => setState(() => _activeTab = t), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: active ? AppColors.green : AppColors.surface, borderRadius: BorderRadius.circular(8)), child: Text(_getTranslatedTab(t, loc), style: GoogleFonts.dmSans(color: active ? Colors.white : AppColors.textSecond, fontSize: 12, fontWeight: FontWeight.bold))));
    }).toList()),
  );

  Widget _tabView(AppLocalizations loc) {
    if (_activeTab == PatientTab.consultations) { return Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Column(children: [_tableHeader(loc), Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : _consultationList(loc))])); }
    else if (_activeTab == PatientTab.actes) { return _actesTabView(loc); }
    else if (_activeTab == PatientTab.ordonnances) { return _ordonnancesTabView(loc); }
    else if (_activeTab == PatientTab.certificats) { return _certificatsTabView(loc); }
    return Center(child: Text(loc.t('loading')));
  }

  Widget _ordonnancesTabView(AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(loc.t('prescriptionSub'), style: GoogleFonts.dmSans(color: AppColors.textSecond)),
          const SizedBox(height: 24),
          _actionBtn(loc.t('newPrescription'), AppColors.green, _showPrescriptionDialog),
        ],
      ),
    );
  }

  Widget _certificatsTabView(AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_rounded, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(loc.t('certificateSub'), style: GoogleFonts.dmSans(color: AppColors.textSecond)),
          const SizedBox(height: 24),
          _actionBtn(loc.t('medicalCertificate'), AppColors.yellow, _showCertificateDialog),
        ],
      ),
    );
  }

  Widget _actesTabView(AppLocalizations loc) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(loc.t('medicalActsTitle'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16)), if (selectedActs.isNotEmpty) _actionBtn(loc.t('createInvoice'), AppColors.primary, () => _createInvoiceFromActs({}))]), const Divider(), Expanded(child: ListView.builder(itemCount: availableActs.length, itemBuilder: (context, index) { final act = availableActs[index]; final isSelected = selectedActs.contains(act); return CheckboxListTile(title: Text(act['name']), subtitle: Text("${act['list_price']} DH"), value: isSelected, onChanged: (val) { setState(() { if (val == true) {
      selectedActs.add(act);
    } else {
      selectedActs.remove(act);
    } }); }, activeColor: AppColors.primary); }))]));
  }

  Widget _tableHeader(AppLocalizations loc) => Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.textPrimary, width: 2))), child: Row(children: [Expanded(flex: 2, child: _th(loc.t('medicalFileNumber').toUpperCase())), Expanded(flex: 2, child: _th(loc.t('colDate').toUpperCase())), Expanded(flex: 4, child: _th(loc.t('reason').toUpperCase())), Expanded(flex: 3, child: _th(loc.t('colStatus').toUpperCase()))]));

  Widget _consultationList(AppLocalizations loc) => ListView.builder(
    itemCount: records.length,
    itemBuilder: (_, i) {
      final r = records[i];
      String dossier = _s(r['medical_file_number']);
      if (dossier.isEmpty) dossier = _s(currentPatient['medical_file_number']);

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Row(children: [
          Expanded(flex: 2, child: Text(dossier.isEmpty ? "—" : dossier, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text(_s(r['date_consultation']).substring(0, _s(r['date_consultation']).length >= 10 ? 10 : 0))),
          Expanded(flex: 4, child: Text(_s(r['motif']), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 3, child: Row(children: [
            _statusBadge(r['state'], loc),
            const SizedBox(width: 8),
            Tooltip(message: loc.t('seeAll'), child: InkWell(onTap: () => _viewRecordDetails(r, loc), child: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 22))),
            if (r['state'] == 'confirmed') ...[
              const SizedBox(width: 8),
              Tooltip(message: loc.t('invoiceConsultation'), child: InkWell(onTap: () => _showActSelectionDialog(r, loc), child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 22))),
            ],
            if (r['state'] == 'waiting') ...[
              const SizedBox(width: 8),
              Tooltip(message: loc.t('confirm'), child: InkWell(onTap: () => _showQuickEditRecord(r, loc), child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24))),
            ]
          ])),
        ]),
      );
    },
  );

  String _getTranslatedState(String? state, AppLocalizations loc) {
    switch (state) {
      case 'draft': return loc.t('statusDraft');
      case 'confirmed': return loc.t('statusConfirmed');
      case 'waiting': return loc.t('statusWaiting');
      case 'invoiced': return loc.t('statusInvoiced');
      default: return state ?? loc.t('statusDraft');
    }
  }

  Widget _rightSidebar(Map p, AppLocalizations loc, String nationalite) => Container(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _patientInfoCard(p, loc, nationalite),
        const SizedBox(height: 16),
        if (sehatiMeasuresEnabled) _sehatiMeasuresCard(loc),
      ]),
    ),
  );

  Widget _patientInfoCard(Map p, AppLocalizations loc, String nationalite) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(_s(p['name']), style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16))), const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 18)]),
      const SizedBox(height: 12),
      _infoChip(Icons.folder_shared_rounded, "${loc.t('medicalFileNumber')}: ${_s(p['medical_file_number'])}"),
      _infoChip(Icons.badge_rounded, "CIN: ${_s(p['patient_code'])}"),
      _infoChip(Icons.public_rounded, "${loc.t('nationality')}: $nationalite"),
      _infoChip(Icons.cake_rounded, '${p['age'] ?? 0} ${loc.t('years')}'),
      _infoChip(Icons.phone_rounded, _s(p['phone'])),
    ]),
  );

  Widget _th(String text) => Text(text, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecond));

  String _getTranslatedTab(PatientTab tab, AppLocalizations loc) {
    switch (tab) {
      case PatientTab.consultations: return loc.t('navRecords').toUpperCase();
      case PatientTab.vaccination: return loc.t('vaccination').toUpperCase();
      case PatientTab.actes: return loc.t('medicalActsTitle').toUpperCase();
      case PatientTab.ordonnances: return loc.t('prescriptions').toUpperCase();
      case PatientTab.bilanBio: return loc.t('bilanBio').toUpperCase();
      case PatientTab.bilanRx: return loc.t('bilanRx').toUpperCase();
      case PatientTab.certificats: return loc.t('medicalCertificate').toUpperCase();
      case PatientTab.compteRendu: return loc.t('reports').toUpperCase();
      case PatientTab.comptabilite: return loc.t('accounting').toUpperCase();
      case PatientTab.factures: return loc.t('statusInvoiced').toUpperCase();
    }
  }

  Widget _infoChip(IconData icon, String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Icon(icon, color: AppColors.primary, size: 14), const SizedBox(width: 8), Expanded(child: Text(text.contains(": ") && text.split(": ")[1].isEmpty ? "${text.split(": ")[0]}: —" : text, style: GoogleFonts.dmSans(color: AppColors.textSecond, fontSize: 12, fontWeight: FontWeight.w500)))]));
  
  Widget _sehatiMeasuresCard(AppLocalizations loc) => InkWell(
    onTap: () => _showSehatiMeasuresDialog(loc),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withOpacity(0.2)), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.health_and_safety_rounded, size: 20, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text(loc.t('measuresSehati'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)))]),
        const Divider(),
        Text(loc.t('sehatiModuleSwitchSub'), style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecond)),
      ]),
    ),
  );

  void _showSehatiMeasuresDialog(AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [const Icon(Icons.health_and_safety_rounded, color: AppColors.primary), const SizedBox(width: 10), Text(loc.t('measuresSehati'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold))]),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _measuresCardContent(loc),
                const SizedBox(height: 16),
                _bodyMeasuresCardContent(loc),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('close')))],
      ),
    );
  }

  Widget _measuresCardContent(AppLocalizations loc) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Icon(Icons.monitor_heart_rounded, size: 18, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text(loc.t('recentMeasures'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)))]),
    const Divider(),
    if (bpMeasurements.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(loc.t('noMeasure'), style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)))
    else ...bpMeasurements.take(3).map((m) => _bpMeasureItem(m, loc))
  ]);

  Widget _bodyMeasuresCardContent(AppLocalizations loc) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Icon(Icons.scale_rounded, size: 18, color: AppColors.green), const SizedBox(width: 8), Expanded(child: Text(loc.t('bodyMeasuresTitle'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)))]),
    const Divider(),
    if (bodyMeasurements.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(loc.t('noMeasure'), style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)))
    else ...bodyMeasurements.take(3).map((m) => _bodyMeasureItem(m, loc))
  ]);

  Widget _bodyMeasureItem(Map m, AppLocalizations loc) {
    final date = _s(m['date']).substring(0, _s(m['date']).length >= 10 ? 10 : 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(date, style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _bodyValueSmall(loc.t('weight'), "${_fmt2(m['weight'])} kg"),
            _bodyValueSmall(loc.t('bmi'), _fmt2(m['bmi'])),
            _bodyValueSmall(loc.t('bodyFat'), "${_fmt2(m['body_fat'])}%"),
            _bodyValueSmall(loc.t('muscleMass'), "${_fmt2(m['muscle_mass'])} kg"),
            _bodyValueSmall(loc.t('bodyWater'), "${_fmt2(m['water'])}%"),
            _bodyValueSmall(loc.t('visceralFat'), _fmt2(m['visceral_fat'])),
            _bodyValueSmall(loc.t('metabolicAge'), "${_fmt2(m['metabolic_age'])} ${loc.t('years')}"),
          ],
        ),
        const Divider(height: 24),
      ]),
    );
  }

  Widget _bodyValueSmall(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.dmSans(color: AppColors.textSecond, fontSize: 10)),
      Text(value, style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
    ],
  );

  Widget _statusBadge(String? state, AppLocalizations loc) { Color color; Color bgColor; switch (state) { case 'draft': color = AppColors.textMuted; bgColor = AppColors.textMuted.withOpacity(0.1); break; case 'waiting': color = AppColors.yellow; bgColor = AppColors.yellowLight; break; case 'confirmed': color = AppColors.green; bgColor = AppColors.greenLight; break; case 'invoiced': color = AppColors.primary; bgColor = AppColors.primaryLight; break; default: color = AppColors.textMuted; bgColor = AppColors.textMuted.withOpacity(0.1); } return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.25))), child: Text(_getTranslatedState(state, loc), style: GoogleFonts.dmSans(color: color, fontSize: 10, fontWeight: FontWeight.w700))); }
  Widget _bpMeasureItem(Map m, AppLocalizations loc) { final sys = (m['systolique'] as num).toDouble(); final dia = (m['diastolique'] as num).toDouble(); final date = _s(m['date_mesure']).substring(0, _s(m['date_mesure']).length >= 10 ? 10 : 0); return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(date, style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Wrap(spacing: 10, children: [_bpValue('SYS', sys.toStringAsFixed(0), 'mmHg', sys <= 120 ? AppColors.green : AppColors.red), _bpValue('DIA', dia.toStringAsFixed(0), 'mmHg', dia <= 80 ? AppColors.green : AppColors.red)])])); }
  Widget _bpValue(String label, String val, String unit, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [Text('$label: ', style: GoogleFonts.dmSans(color: AppColors.textSecond, fontSize: 11)), Text(val, style: GoogleFonts.dmSans(color: color, fontSize: 11, fontWeight: FontWeight.w700))]);
}
