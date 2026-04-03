import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_app/Services/odoo_api.dart';
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
  bool isScanning = false;
  MobileScannerController cameraController = MobileScannerController();
  String userRole = 'doctor';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString('user_role') ?? 'doctor';
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
          setState(() => isScanning = false);
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
      Navigator.pop(context);
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
        title: const Text("Nouvel Acte Médical"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nom de l'acte (ex: Consultation)")),
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
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.t('navSettings'), style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 32),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // BLOC 1: ACTES MÉDICAUX (Only for Doctor)
                        if (userRole == 'doctor')
                          Expanded(
                            flex: 3,
                            child: _buildSectionCard(
                              title: "Gestion des Actes",
                              subtitle: "Configurez vos tarifs et services",
                              icon: Icons.medical_services_rounded,
                              action: ElevatedButton.icon(
                                onPressed: _showAddActDialog,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text("Ajouter"),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              ),
                              child: loadingActs
                                  ? const Center(child: CircularProgressIndicator())
                                  : myActs.isEmpty
                                      ? Center(child: Text("Aucun acte configuré", style: GoogleFonts.dmSans(color: AppColors.textMuted)))
                                      : ListView.separated(
                                          itemCount: myActs.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1),
                                          itemBuilder: (context, i) => ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                            title: Text(myActs[i]['name'], style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14)),
                                            trailing: Text("${myActs[i]['list_price']} DH", style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                          ),
                                        ),
                            ),
                          ),
                        if (userRole == 'doctor') const SizedBox(width: 24),
                        // BLOC 2: SCANNAGE / IDENTIFICATION (For both, but centered if secretary)
                        Expanded(
                          flex: 2,
                          child: _buildSectionCard(
                            title: "Identification Patient",
                            subtitle: "Scannez le QR Code de la fiche",
                            icon: Icons.qr_code_scanner_rounded,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!isScanning) ...[
                                  Container(
                                    width: 120, height: 120,
                                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
                                    child: const Icon(Icons.qr_code_2_rounded, size: 64, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 24),
                                  Text("Identification Rapide", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 8),
                                  Text("Scannez le code QR généré lors de la planification pour ouvrir instantanément la fiche du patient.", textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: AppColors.textSecond, fontSize: 13)),
                                  const SizedBox(height: 32),
                                  ElevatedButton.icon(
                                    onPressed: () => setState(() => isScanning = true),
                                    icon: const Icon(Icons.camera_alt_rounded),
                                    label: const Text("Démarrer le Scan"),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  ),
                                ] else ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      height: 300,
                                      child: MobileScanner(
                                        controller: cameraController,
                                        onDetect: _onDetect,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton.icon(
                                    onPressed: () => setState(() => isScanning = false),
                                    icon: const Icon(Icons.stop_rounded),
                                    label: const Text("Arrêter le scan"),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.red),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (userRole == 'secretary') const Spacer(flex: 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required String subtitle, required IconData icon, Widget? action, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.primary, size: 24)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
                      Text(subtitle, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (action != null) action,
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: Padding(padding: const EdgeInsets.all(20), child: child)),
        ],
      ),
    );
  }
}
