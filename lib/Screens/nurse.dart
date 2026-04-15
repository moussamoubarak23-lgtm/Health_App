import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';
import 'package:medical_app/Screens/nurse_detail.dart';
import 'package:medical_app/Widgets/app_breadcrumb.dart';

class NursesScreen extends StatefulWidget {
  const NursesScreen({super.key});
  @override
  State<NursesScreen> createState() => _NursesScreenState();
}

class _NursesScreenState extends State<NursesScreen> {
  List nurses = [];
  List filtered = [];
  bool loading = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final data = await OdooApi.getNurses();
      if (mounted) {
        setState(() {
          nurses = data;
          filtered = data;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
        _snack("Erreur lors du chargement des infirmiers", isError: true);
      }
    }
  }

  String _s(dynamic val) => (val is String) ? val : (val == null || val == false ? '' : val.toString());

  void _filter(String q) {
    setState(() {
      final needle = q.toLowerCase();
      filtered = q.isEmpty
          ? nurses
          : nurses.where((n) {
              return _s(n['name']).toLowerCase().contains(needle) ||
                  _s(n['phone']).contains(q) ||
                  _s(n['license_number']).toLowerCase().contains(needle) ||
                  _s(n['specialization']).toLowerCase().contains(needle);
            }).toList();
    });
  }

  void _confirmDelete(Map nurse) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Supprimer l'infirmier", style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.red)),
        content: Text("Confirmer la suppression de ${_s(nurse['name'])} ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => loading = true);
              final res = await OdooApi.deleteNurse(nurse['id']);
              if (res['success'] == true) {
                _snack("Infirmier supprimé");
                _load();
              } else {
                setState(() => loading = false);
                _snack("Erreur lors de la suppression", isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog({Map? nurse}) {
    final nameCtrl = TextEditingController(text: _s(nurse?['name']));
    final ageCtrl = TextEditingController(text: _s(nurse?['age']));
    final phoneCtrl = TextEditingController(text: _s(nurse?['phone']));
    final emailCtrl = TextEditingController(text: _s(nurse?['email']));
    final licenseCtrl = TextEditingController(text: _s(nurse?['license_number']));
    final notesCtrl = TextEditingController(text: _s(nurse?['notes']));
    final departmentCtrl = TextEditingController(text: _s(nurse?['department_id']));

    String gender = _s(nurse?['gender']).isEmpty ? 'male' : _s(nurse?['gender']);
    String state = _s(nurse?['state']).isEmpty ? 'active' : _s(nurse?['state']);
    String specialization = _s(nurse?['specialization']).isEmpty ? 'generaliste' : _s(nurse?['specialization']);
    String? expiryDate = _s(nurse?['license_expiry_date']).isEmpty ? null : _s(nurse?['license_expiry_date']);
    bool active = nurse?['active'] is bool ? nurse!['active'] : true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(nurse == null ? "Nouvel infirmier" : "Modifier infirmier",
                      style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _field("Nom complet (*)", nameCtrl, Icons.person_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _field("Age", ageCtrl, Icons.cake_rounded)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _field("Téléphone", phoneCtrl, Icons.phone_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _field("Email", emailCtrl, Icons.email_rounded)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _field("Numéro de licence (*)", licenseCtrl, Icons.badge_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _field("Département", departmentCtrl, Icons.local_hospital_rounded)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: gender,
                      decoration: _ddDeco("Genre"),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text("Homme")),
                        DropdownMenuItem(value: 'female', child: Text("Femme")),
                      ],
                      onChanged: (v) => setDialogState(() => gender = v ?? 'male'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: specialization,
                      decoration: _ddDeco("Spécialisation"),
                      items: const [
                        DropdownMenuItem(value: 'generaliste', child: Text("Généraliste")),
                        DropdownMenuItem(value: 'urgences', child: Text("Urgences")),
                        DropdownMenuItem(value: 'pediatrie', child: Text("Pédiatrie")),
                        DropdownMenuItem(value: 'bloc', child: Text("Bloc")),
                      ],
                      onChanged: (v) => setDialogState(() => specialization = v ?? 'generaliste'),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: state,
                      decoration: _ddDeco("Statut"),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text("Actif")),
                        DropdownMenuItem(value: 'leave', child: Text("En congé")),
                        DropdownMenuItem(value: 'inactive', child: Text("Inactif")),
                      ],
                      onChanged: (v) => setDialogState(() => state = v ?? 'active'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _datePickerField("Expiration licence", expiryDate, (d) => setDialogState(() => expiryDate = d))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Checkbox(value: active, onChanged: (v) => setDialogState(() => active = v ?? true)),
                  const Text("Actif"),
                ]),
                _field("Notes", notesCtrl, Icons.note_rounded, maxLines: 2),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty || licenseCtrl.text.trim().isEmpty) {
                        _snack("Nom et numéro de licence obligatoires", isError: true);
                        return;
                      }
                      final vals = {
                        'name': nameCtrl.text.trim(),
                        'age': int.tryParse(ageCtrl.text.trim()),
                        'gender': gender,
                        'phone': phoneCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'license_number': licenseCtrl.text.trim(),
                        'license_expiry_date': expiryDate,
                        'specialization': specialization,
                        'department_id': departmentCtrl.text.trim(),
                        'state': state,
                        'active': active,
                        'notes': notesCtrl.text.trim(),
                      }..removeWhere((k, v) => v == null);

                      final result = nurse == null ? await OdooApi.createNurse(vals) : await OdooApi.updateNurse(nurse['id'], vals);
                      if (!mounted) return;
                      Navigator.of(this.context).pop();
                      if (result['success'] == true) {
                        _snack(nurse == null ? "Infirmier créé" : "Infirmier mis à jour");
                        _load();
                      } else {
                        _snack("Erreur lors de l'enregistrement", isError: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: const Text("Enregistrer"),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _ddDeco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      );

  Widget _field(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ]);

  Widget _datePickerField(String label, String? value, Function(String) onSelected) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecond)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: (value != null && value.isNotEmpty) ? DateTime.parse(value) : DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (date != null) onSelected(date.toString().substring(0, 10));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: AppColors.inputFill, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 12),
              Text((value == null || value.isEmpty) ? "Sélectionner une date" : value, style: GoogleFonts.dmSans(color: (value == null || value.isEmpty) ? AppColors.textHint : AppColors.textPrimary)),
            ]),
          ),
        ),
      ]);

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? AppColors.red : AppColors.green, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = context.watch<LanguageProvider>().isArabic;
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(children: [
          const Sidebar(currentRoute: '/nurses'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("Infirmiers", style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Nouvel infirmier"),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  ),
                ]),
                const SizedBox(height: 12),
                AppBreadcrumb(
                  items: [
                    BreadcrumbItem(label: l10n.t('home'), route: '/dashboard'),
                    const BreadcrumbItem(label: 'Infirmiers'),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                  child: TextField(controller: _search, onChanged: _filter, decoration: const InputDecoration(hintText: "Rechercher par nom, tél, licence...", border: InputBorder.none, icon: Icon(Icons.search))),
                ),
                const SizedBox(height: 16),
                Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : _buildTable()),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTable() => Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primary, width: 2))),
            child: Row(children: [
              Expanded(flex: 3, child: _th("NOM")),
              Expanded(flex: 2, child: _th("LICENCE")),
              Expanded(flex: 2, child: _th("SPÉCIALISATION")),
              Expanded(flex: 2, child: _th("DÉPARTEMENT")),
              Expanded(flex: 1, child: _th("STATUT")),
              Expanded(flex: 2, child: _th("ACTIONS")),
            ]),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text("Aucun infirmier trouvé"))
                : ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) => _row(filtered[i], i)),
          ),
        ]),
      );

  Widget _row(Map n, int index) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: index % 2 == 0 ? AppColors.surface : AppColors.surfaceAlt,
        child: Row(children: [
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NurseDetailScreen(nurse: n))),
              child: Text(_s(n['name']).isEmpty ? '—' : _s(n['name']), style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ),
          Expanded(flex: 2, child: Text(_s(n['license_number']).isEmpty ? '—' : _s(n['license_number']))),
          Expanded(flex: 2, child: Text(_s(n['specialization']).isEmpty ? '—' : _s(n['specialization']))),
          Expanded(flex: 2, child: Text(_s(n['department_id']).isEmpty ? '—' : _s(n['department_id']))),
          Expanded(flex: 1, child: Text(_s(n['state']).isEmpty ? '—' : _s(n['state']))),
          Expanded(
            flex: 2,
            child: Row(children: [
              IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary), onPressed: () => _showAddEditDialog(nurse: n)),
              IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.red), onPressed: () => _confirmDelete(n)),
            ]),
          ),
        ]),
      );

  Widget _th(String text) => Text(text, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecond));
}
