import 'dart:io';
import 'package:flutter/material.dart';
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
        _snack("Patient non trouvé", isError: true);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _snack("Erreur d'identification", isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? AppColors.red : AppColors.green, behavior: SnackBarBehavior.floating));
  }

  void _showAddActDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Nouvel Acte Médical", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nom de l'acte", hintText: "ex: Consultation")),
            const SizedBox(height: 16),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Prix (DH)"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                final res = await OdooApi.createMedicalAct(name: nameCtrl.text, price: price);
                Navigator.pop(context);
                if (res['success']) {
                  _loadActs();
                  _snack("Acte créé avec succès");
                } else {
                  _snack("Erreur: ${res['error']}", isError: true);
                }
              }
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  void _showActsListDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Mes Actes Médicaux", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              IconButton(onPressed: () {
                _showAddActDialog();
                Navigator.pop(context);
              }, icon: const Icon(Icons.add_circle, color: AppColors.primary)),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 500,
            child: loadingActs
                ? const Center(child: CircularProgressIndicator())
                : myActs.isEmpty
                    ? Center(child: Text("Aucun acte configuré", style: GoogleFonts.dmSans(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: myActs.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) => ListTile(
                          title: Text(myActs[i]['name'], style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                          trailing: Text("${myActs[i]['list_price']} DH", style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer"))],
        ),
      ),
    );
  }

  void _showScanDialog() {
    final idCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Identification Patient", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 450,
          height: 550,
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: QRCodeDartScanView(
                    onCapture: (Result result) {
                      Navigator.pop(context);
                      _handleQRCode(result.text);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text("Si la caméra ne s'affiche pas, saisissez l'ID :", style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: idCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Saisir ID Patient", hintText: "Ex: 42", prefixIcon: Icon(Icons.numbers)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              final id = int.tryParse(idCtrl.text);
              if (id != null) {
                Navigator.pop(context);
                _identifyAndRedirect(id);
              }
            },
            child: const Text("Valider ID"),
          ),
        ],
      ),
    );
  }

  void _showCertificateDialog() {
    final patientNameCtrl = TextEditingController();
    final contentCtrl = TextEditingController(text: "L'état de santé de l'intéressé(e) nécessite un repos de ... jours à compter du ...");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.description, color: AppColors.primary),
            const SizedBox(width: 10),
            Text("Certificat Médical Personnalisé", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: patientNameCtrl,
                decoration: const InputDecoration(
                  labelText: "Nom du Patient",
                  hintText: "Ex: Mohamed Alami",
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: "Contenu du certificat",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton.icon(
            onPressed: () async {
              if (patientNameCtrl.text.isEmpty) {
                _snack("Veuillez saisir le nom du patient", isError: true);
                return;
              }
              await PdfService.generateAndPrintCertificate(
                doctorName: doctorName,
                patientName: patientNameCtrl.text,
                content: contentCtrl.text,
                date: DateTime.now(),
                cabinetAddress: cabinetAddress,
                cabinetPhone: cabinetPhone,
                logoPath: cabinetLogoPath,
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.print),
            label: const Text("Imprimer / PDF"),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showPrescriptionDialog() {
    final patientNameCtrl = TextEditingController();
    final contentCtrl = TextEditingController(text: "1. \n2. \n3. ");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.green),
            const SizedBox(width: 10),
            Text("Nouvelle Ordonnance", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: patientNameCtrl,
                decoration: const InputDecoration(
                  labelText: "Nom du Patient",
                  hintText: "Ex: Mohamed Alami",
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentCtrl,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: "Médicaments et posologie",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton.icon(
            onPressed: () async {
              if (patientNameCtrl.text.isEmpty) {
                _snack("Veuillez saisir le nom du patient", isError: true);
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
              Navigator.pop(context);
            },
            icon: const Icon(Icons.print),
            label: const Text("Imprimer / PDF"),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showCabinetInfoDialog() {
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
          title: Text("Configuration de l'ordonnance papier", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
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
                            Text("Logo", style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
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
                              Expanded(child: TextField(controller: specFrCtrl, decoration: const InputDecoration(labelText: "Spécialité (FR)"))),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(controller: specArCtrl, decoration: const InputDecoration(labelText: "Spécialité (AR)"), textDirection: TextDirection.rtl)),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: TextField(controller: expFrCtrl, decoration: const InputDecoration(labelText: "Titres / Expérience (FR)"), maxLines: 2)),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(controller: expArCtrl, decoration: const InputDecoration(labelText: "Titres / Expérience (AR)"), textDirection: TextDirection.rtl, maxLines: 2)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Row(children: [
                    Expanded(child: TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: "Adresse du Cabinet", prefixIcon: Icon(Icons.location_on)))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Téléphone", prefixIcon: Icon(Icons.phone)))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: faxCtrl, decoration: const InputDecoration(labelText: "Fax", prefixIcon: Icon(Icons.print)))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email))),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () async {
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
                Navigator.pop(context);
                _snack("Configuration enregistrée");
              },
              child: const Text("Enregistrer"),
            ),
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
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.t('navSettings'), style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text("Personnalisez votre expérience et gérez vos outils.", style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textSecond)),
                  const SizedBox(height: 12),
                  AppBreadcrumb(
                    items: [
                      BreadcrumbItem(label: loc.t('home'), route: '/dashboard'),
                      BreadcrumbItem(label: loc.t('settingsLabel')),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      if (userRole == 'doctor')
                        _buildMenuTile(
                          title: "Actes Médicaux",
                          subtitle: "Gérer vos services et tarifs",
                          icon: Icons.medical_services_rounded,
                          color: Colors.blue,
                          onTap: _showActsListDialog,
                        ),
                      if (userRole == 'doctor')
                        _buildMenuTile(
                          title: "Infos Cabinet",
                          subtitle: "Configuration ordonnance papier",
                          icon: Icons.business_rounded,
                          color: Colors.indigo,
                          onTap: _showCabinetInfoDialog,
                        ),
                      if (userRole == 'doctor')
                        _buildMenuTile(
                          title: "Ordonnances",
                          subtitle: "Générer une ordonnance",
                          icon: Icons.receipt_long_rounded,
                          color: Colors.green,
                          onTap: _showPrescriptionDialog,
                        ),
                      if (userRole == 'doctor')
                        _buildMenuTile(
                          title: "Certificats",
                          subtitle: "Générer un document médical",
                          icon: Icons.assignment_rounded,
                          color: Colors.orange,
                          onTap: _showCertificateDialog,
                        ),
                      _buildMenuTile(
                        title: "Identification",
                        subtitle: "Scanner ou chercher un patient",
                        icon: Icons.person_search_rounded,
                        color: Colors.teal,
                        onTap: _showScanDialog,
                      ),
                      _buildMenuTile(
                        title: "Langue",
                        subtitle: "Changer la langue de l'app",
                        icon: Icons.language_rounded,
                        color: Colors.purple,
                        onTap: () {
                          _snack("Fonctionnalité accessible via la sidebar");
                        },
                      ),
                    ],
                  ),
                ],
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
        width: 280,
        padding: const EdgeInsets.all(24),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
