import 'dart:io';
import 'package:flutter/foundation.dart';
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
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:medical_app/Screens/patient_detail.dart';

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

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code.startsWith("PATIENT_ID:")) {
        final idStr = code.split(":")[1];
        final id = int.tryParse(idStr);
        if (id != null) {
          Navigator.pop(context); // Close dialog
          _identifyAndRedirect(id);
          break;
        }
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
              IconButton(onPressed: _showAddActDialog, icon: const Icon(Icons.add_circle, color: AppColors.primary)),
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
    // Le plugin mobile_scanner ne supporte pas nativement Windows et Linux.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Scanner non supporté"),
          content: const Text("Le scan de QR code via webcam n'est pas encore disponible sur cette version desktop de l'application.\n\nCette fonctionnalité est optimisée pour Android, iOS, macOS et le Web."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Compris"))
          ],
        ),
      );
      return;
    }

    final MobileScannerController scannerController = MobileScannerController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Scanner QR Code", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MobileScanner(
                    controller: scannerController,
                    onDetect: _onDetect,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text("Placez le QR Code devant la webcam", style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              scannerController.dispose();
              Navigator.pop(context);
            },
            child: const Text("Annuler"),
          )
        ],
      ),
    ).then((_) {
      try {
        scannerController.dispose();
      } catch (_) {}
    });
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
                          title: "Certificats",
                          subtitle: "Générer un document médical",
                          icon: Icons.assignment_rounded,
                          color: Colors.orange,
                          onTap: _showCertificateDialog,
                        ),
                      _buildMenuTile(
                        title: "Scanner QR",
                        subtitle: "Identifier un patient (Caméra)",
                        icon: Icons.qr_code_scanner_rounded,
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
