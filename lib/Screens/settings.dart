import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Services/pdf_service.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';
import 'package:medical_app/Widgets/app_breadcrumb.dart';
import 'package:qr_code_dart_scan/qr_code_dart_scan.dart';
import 'package:medical_app/Screens/patient_detail.dart';
import 'package:file_picker/file_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List myActs = [];
  bool loadingActs = true;
  String userRole = 'doctor';
  String doctorName = '';
  bool sehatiMeasuresEnabled = false;
  
  // Infos Cabinet
  String cabinetAddress = '';
  String cabinetPhone = '';
  String cabinetEmail = '';
  String cabinetFax = '';
  String? cabinetLogoPath;
  String specialtyFr = '';
  String specialtyAr = '';
  String experienceFr = '';
  String experienceAr = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString('user_role') ?? 'doctor';
      doctorName = prefs.getString('doctor_name') ?? 'Médecin';
      sehatiMeasuresEnabled = prefs.getBool('module_sehati_measures_enabled') ?? false;
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
    if (userRole == 'doctor') {
      _loadActs();
    } else {
      setState(() => loadingActs = false);
    }
  }

  Future<void> _loadActs() async {
    setState(() => loadingActs = true);
    final acts = await OdooApi.getMedicalActs();
    setState(() {
      myActs = acts;
      loadingActs = false;
    });
  }

  void _handleQRCode(String code) {
    // Check if it's our medical report format
    if (code.contains("--- RAPPORT MEDICAL ---") && code.contains("ID:")) {
      try {
        final lines = code.split('\n');
        final idLine = lines.firstWhere((l) => l.trim().startsWith("ID:"));
        final idStr = idLine.split(":")[1].trim();
        final id = int.tryParse(idStr);
        if (id != null) {
          _identifyAndRedirect(id);
          return;
        }
      } catch (e) {
        // Fallback
      }
    }

    // Standard PATIENT_ID check
    if (code.startsWith("PATIENT_ID:")) {
      final idStr = code.split(":")[1];
      final id = int.tryParse(idStr);
      if (id != null) {
        _identifyAndRedirect(id);
      }
    }
  }

  Future<void> _identifyAndRedirect(int id) async {
    final loc = AppLocalizations.of(context);
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final patients = await OdooApi.getPatients();
      if (!mounted) return;
      Navigator.pop(context); // Close loader
      final patient = patients.firstWhere((p) => p['id'] == id, orElse: () => null);
      if (patient != null) {
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: patient)));
        }
      } else {
        _snack(loc.t('patientNotFound'), isError: true);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _snack(loc.t('identificationError'), isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? AppColors.red : AppColors.green, behavior: SnackBarBehavior.floating));
  }

  void _showAddActDialog() {
    final loc = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('newMedicalActTitle'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: loc.t('actName'), hintText: loc.t('exampleConsultation'))),
            const SizedBox(height: 16),
            TextField(controller: priceCtrl, decoration: InputDecoration(labelText: loc.t('priceDh')), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final name = nameCtrl.text.trim();
              final priceText = priceCtrl.text.trim();
              if (name.isEmpty || priceText.isEmpty) {
                _snack(loc.t('actNameRequired'), isError: true);
                return;
              }

              final price = double.tryParse(priceText);
              if (price == null || price <= 0) {
                _snack(loc.t('invalidPrice'), isError: true);
                return;
              }

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                final res = await OdooApi.createMedicalAct(name: name, price: price);
                if (!mounted) return;
                if (navigator.canPop()) navigator.pop(); // loader
                if (navigator.canPop()) navigator.pop(); // add dialog

                if (res['success'] == true) {
                  await _loadActs();
                  _snack(loc.t('actCreated'));
                } else {
                  _snack("${loc.t('error')}: ${res['error'] ?? 'création impossible'}", isError: true);
                }
              } catch (e) {
                if (!mounted) return;
                if (navigator.canPop()) navigator.pop(); // loader
                _snack(loc.t('error'), isError: true);
              }
            },
            child: Text(loc.t('save')),
          ),
        ],
      ),
    );
  }

  void _showActsListDialog() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(loc.t('medicalActsTitle'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              IconButton(onPressed: () {
                Navigator.pop(dialogContext);
                Future.microtask(_showAddActDialog);
              }, icon: const Icon(Icons.add_circle, color: AppColors.primary)),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 500,
            child: loadingActs
                ? const Center(child: CircularProgressIndicator())
                : myActs.isEmpty
                    ? Center(child: Text(loc.t('noActConfigured'), style: GoogleFonts.dmSans(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: myActs.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) => ListTile(
                          title: Text(myActs[i]['name'], style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                          trailing: Text("${myActs[i]['list_price']} DH", style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('close')))],
        ),
      ),
    );
  }

  void _showScanDialog() {
    final loc = AppLocalizations.of(context);
    final idCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('identificationPatient'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 450,
          height: 550,
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: kIsWeb
                      ? Container(
                          color: AppColors.surfaceAlt,
                          alignment: Alignment.center,
                          child: Text(
                            loc.t('manualIdWeb'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(color: AppColors.textSecond),
                          ),
                        )
                      : QRCodeDartScanView(
                          onCapture: (Result result) {
                            Navigator.pop(context);
                            _handleQRCode(result.text);
                          },
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Text(loc.t('idManualHint'), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: idCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: loc.t('enterPatientId'), hintText: "Ex: 42", prefixIcon: const Icon(Icons.numbers)),
                onSubmitted: (v) {
                  final id = int.tryParse(v);
                  if (id != null) {
                    Navigator.pop(context);
                    _identifyAndRedirect(id);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))),
          ElevatedButton(
            onPressed: () {
              final id = int.tryParse(idCtrl.text);
              if (id != null) {
                Navigator.pop(context);
                _identifyAndRedirect(id);
              }
            },
            child: Text(loc.t('validateId')),
          ),
        ],
      ),
    );
  }

  void _showCertificateDialog() {
    final loc = AppLocalizations.of(context);
    final patientNameCtrl = TextEditingController();
    final contentCtrl = TextEditingController(text: "L'état de santé de l'intéressé(e) nécessite un repos de ... jours à compter du ...");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.description, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(loc.t('customMedicalCertificate'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
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
                  hintText: loc.t('patientNameExample'),
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
              if (patientNameCtrl.text.isEmpty) {
                _snack(loc.t('patientNameRequired'), isError: true);
                return;
              }
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
    final patientNameCtrl = TextEditingController();
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
                  hintText: loc.t('patientNameExample'),
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
              if (patientNameCtrl.text.isEmpty) {
                _snack(loc.t('patientNameRequired'), isError: true);
                return;
              }
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

  void _showCabinetInfoDialog() {
    final loc = AppLocalizations.of(context);
    final addrCtrl = TextEditingController(text: cabinetAddress);
    final phoneCtrl = TextEditingController(text: cabinetPhone);
    final emailCtrl = TextEditingController(text: cabinetEmail);
    final faxCtrl = TextEditingController(text: cabinetFax);
    final specFrCtrl = TextEditingController(text: specialtyFr);
    final specArCtrl = TextEditingController(text: specialtyAr);
    final expFrCtrl = TextEditingController(text: experienceFr);
    final expArCtrl = TextEditingController(text: experienceAr);
    String? tempLogoPath = cabinetLogoPath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(loc.t('paperConfigTitle'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo Column
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Text(loc.t('logoLabel'), style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                                if (result != null) setDialogState(() => tempLogoPath = result.files.single.path);
                              },
                              child: Container(
                                height: 100, width: 100,
                                decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!)),
                                child: tempLogoPath != null
                                    ? ClipOval(child: Image.file(File(tempLogoPath!), fit: BoxFit.cover))
                                    : const Icon(Icons.add_a_photo, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Fields Column
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            Row(children: [
                              Expanded(child: TextField(controller: specFrCtrl, decoration: InputDecoration(labelText: loc.t('specialtyFr')))),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(controller: specArCtrl, decoration: InputDecoration(labelText: loc.t('specialtyAr')), textDirection: TextDirection.rtl)),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: TextField(controller: expFrCtrl, decoration: InputDecoration(labelText: loc.t('experienceFr')), maxLines: 2)),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(controller: expArCtrl, decoration: InputDecoration(labelText: loc.t('experienceAr')), textDirection: TextDirection.rtl, maxLines: 2)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Row(children: [
                    Expanded(child: TextField(controller: addrCtrl, decoration: InputDecoration(labelText: loc.t('cabinetAddressLabel'), prefixIcon: const Icon(Icons.location_on)))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: loc.t('phone'), prefixIcon: const Icon(Icons.phone)))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: faxCtrl, decoration: InputDecoration(labelText: loc.t('faxLabel'), prefixIcon: const Icon(Icons.print)))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: emailCtrl, decoration: InputDecoration(labelText: loc.t('email'), prefixIcon: const Icon(Icons.email))),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('cabinet_address', addrCtrl.text.trim());
                await prefs.setString('cabinet_phone', phoneCtrl.text.trim());
                await prefs.setString('cabinet_email', emailCtrl.text.trim());
                await prefs.setString('cabinet_fax', faxCtrl.text.trim());
                await prefs.setString('cabinet_specialty_fr', specFrCtrl.text.trim());
                await prefs.setString('cabinet_specialty_ar', specArCtrl.text.trim());
                await prefs.setString('cabinet_experience_fr', expFrCtrl.text.trim());
                await prefs.setString('cabinet_experience_ar', expArCtrl.text.trim());
                if (tempLogoPath != null) await prefs.setString('cabinet_logo_path', tempLogoPath!);
                
                setState(() {
                  cabinetAddress = addrCtrl.text.trim();
                  cabinetPhone = phoneCtrl.text.trim();
                  cabinetEmail = emailCtrl.text.trim();
                  cabinetFax = faxCtrl.text.trim();
                  specialtyFr = specFrCtrl.text.trim();
                  specialtyAr = specArCtrl.text.trim();
                  experienceFr = expFrCtrl.text.trim();
                  experienceAr = expArCtrl.text.trim();
                  cabinetLogoPath = tempLogoPath;
                });
                if (!mounted) return;
                if (navigator.canPop()) navigator.pop();
                _snack(loc.t('configSaved'));
              },
              child: Text(loc.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showModulesDialog() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.extension_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(loc.t('modulesTitle'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SwitchListTile.adaptive(
                    value: sehatiMeasuresEnabled,
                    onChanged: (v) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('module_sehati_measures_enabled', v);
                      if (!mounted) return;
                      setState(() => sehatiMeasuresEnabled = v);
                      setDialogState(() {});
                    },
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(loc.t('sehatiModuleTitle'), style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                        ),
                        Tooltip(
                          message: loc.t('sehatiModuleDetail'),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  title: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                                      const SizedBox(width: 10),
                                      Text(loc.t('sehatiModuleTitle'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  content: Text(
                                    loc.t('sehatiModuleDesc'),
                                    style: GoogleFonts.dmSans(color: AppColors.textSecond, height: 1.35),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('close'))),
                                  ],
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.help_outline_rounded, size: 18, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      loc.t('sehatiModuleSwitchSub'),
                      style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12),
                    ),
                    secondary: const Icon(Icons.health_and_safety_rounded, color: AppColors.primary),
                    activeColor: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    loc.t('modulesTip'),
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecond),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('close'))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isRtl = context.watch<LanguageProvider>().isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(children: [
          const Sidebar(currentRoute: '/settings'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.t('navSettings'), style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text(loc.t('settingsSubtitle'), style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecond)),
                    const SizedBox(height: 10),
                    AppBreadcrumb(
                      items: [
                        BreadcrumbItem(label: loc.t('home'), route: '/dashboard'),
                        BreadcrumbItem(label: loc.t('settingsLabel')),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: [
                        _buildMenuTile(
                          title: loc.t('modulesTitle'),
                          subtitle: loc.t('modulesSub'),
                          icon: Icons.extension_rounded,
                          color: AppColors.primary,
                          onTap: _showModulesDialog,
                        ),
                        if (userRole == 'doctor')
                          _buildMenuTile(
                            title: loc.t('medicalActsTitle'),
                            subtitle: loc.t('actManagementSub'),
                            icon: Icons.medical_services_rounded,
                            color: Colors.blue,
                            onTap: _showActsListDialog,
                          ),
                        if (userRole == 'doctor')
                          _buildMenuTile(
                            title: loc.t('paperConfigTitle'),
                            subtitle: loc.t('cabinetInfoSub'),
                            icon: Icons.business_rounded,
                            color: Colors.indigo,
                            onTap: _showCabinetInfoDialog,
                          ),
                        if (userRole == 'doctor')
                          _buildMenuTile(
                            title: loc.t('prescription'),
                            subtitle: loc.t('prescriptionSub'),
                            icon: Icons.receipt_long_rounded,
                            color: Colors.green,
                            onTap: _showPrescriptionDialog,
                          ),
                        if (userRole == 'doctor')
                          _buildMenuTile(
                            title: loc.t('medicalCertificate'),
                            subtitle: loc.t('certificateSub'),
                            icon: Icons.assignment_rounded,
                            color: Colors.orange,
                            onTap: _showCertificateDialog,
                          ),
                        _buildMenuTile(
                          title: loc.t('identificationPatient'),
                          subtitle: loc.t('idSub'),
                          icon: Icons.person_search_rounded,
                          color: Colors.teal,
                          onTap: _showScanDialog,
                        ),
                        _buildMenuTile(
                          title: loc.t('language'),
                          subtitle: loc.t('langSub'),
                          icon: Icons.language_rounded,
                          color: Colors.purple,
                          onTap: () {
                            _snack(loc.t('langSidebarHint'));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMenuTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
