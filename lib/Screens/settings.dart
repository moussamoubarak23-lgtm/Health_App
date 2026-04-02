import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List myActs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadActs();
  }

  Future<void> _loadActs() async {
    setState(() => loading = true);
    final acts = await OdooApi.getMedicalActs();
    setState(() {
      myActs = acts;
      loading = false;
    });
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
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Nom de l'acte (ex: Consultation)"),
            ),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: "Prix (DH)"),
              keyboardType: TextInputType.number,
            ),
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acte créé avec succès")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${res['error']}")));
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(loc.t('navSettings'), style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _showAddActDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("Ajouter un acte"),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  ),
                ]),
                const SizedBox(height: 24),
                Text("Mes Actes Médicaux Personnalisés", style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primary)),
                const SizedBox(height: 8),
                Text("Seuls les actes que vous créez ici seront visibles lors de vos facturations.", style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted)),
                const SizedBox(height: 24),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : Container(
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                          child: myActs.isEmpty
                              ? const Center(child: Text("Aucun acte configuré"))
                              : ListView.separated(
                                  itemCount: myActs.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, i) => ListTile(
                                    leading: const CircleAvatar(backgroundColor: AppColors.primaryLight, child: Icon(Icons.medical_services, color: AppColors.primary, size: 20)),
                                    title: Text(myActs[i]['name'], style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                                    trailing: Text("${myActs[i]['list_price']} DH", style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
                                  ),
                                ),
                        ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
