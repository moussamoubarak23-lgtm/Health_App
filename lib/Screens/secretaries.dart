import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';
import 'package:medical_app/Screens/secretary_detail.dart';
import 'package:medical_app/Widgets/app_breadcrumb.dart';

class SecretariesScreen extends StatefulWidget {
  const SecretariesScreen({super.key});
  @override
  State<SecretariesScreen> createState() => _SecretariesScreenState();
}

class _SecretariesScreenState extends State<SecretariesScreen> {
  List secretaries = [];
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
      final s = await OdooApi.getSecretaries();
      if (mounted) {
        setState(() {
          secretaries = s;
          filtered = s;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _snack("Erreur lors du chargement des secrétaires", isError: true);
      }
    }
  }

  void _filter(String q) {
    setState(() {
      filtered = q.isEmpty
          ? secretaries
          : secretaries.where((s) =>
              s['full_name'].toString().toLowerCase().contains(q.toLowerCase()) ||
              s['phone'].toString().contains(q) ||
              s['secretary_code'].toString().toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  void _confirmDelete(Map s) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('deleteSecretaryTitle'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.red)),
        content: Text("${l10n.t('deleteSecretaryConfirm')} ${s['full_name']} ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.t('cancel'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => loading = true);
              final res = await OdooApi.deleteSecretary(s['id']);
              if (res['success']) {
                _snack("Secrétaire supprimée");
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

  String _s(dynamic val) => (val is String) ? val : (val == null || val == false ? '' : val.toString());

  void _showAddEditDialog({Map? secretary}) {
    final l10n = AppLocalizations.of(context);
    final isRtl = context.read<LanguageProvider>().isArabic;
    
    final firstNameCtrl = TextEditingController(text: _s(secretary?['first_name']));
    final lastNameCtrl = TextEditingController(text: _s(secretary?['last_name']));
    final phoneCtrl = TextEditingController(text: _s(secretary?['phone']));
    final mobileCtrl = TextEditingController(text: _s(secretary?['mobile']));
    final emailCtrl = TextEditingController(text: _s(secretary?['email']));
    final codeCtrl = TextEditingController(text: _s(secretary?['secretary_code']));
    final cinCtrl = TextEditingController(text: _s(secretary?['national_id']));
    final addressCtrl = TextEditingController(text: _s(secretary?['address']));
    final employeeIdCtrl = TextEditingController(text: _s(secretary?['employee_id']));
    final officeCtrl = TextEditingController(text: _s(secretary?['office_number']));
    final hoursCtrl = TextEditingController(text: _s(secretary?['working_hours']));
    final notesCtrl = TextEditingController(text: _s(secretary?['notes']));
    
    String gender = secretary?['gender'] is String ? secretary!['gender'] : 'male';
    String? birthDate = secretary?['birth_date'] is String ? secretary!['birth_date'] : null;
    String? hireDate = secretary?['hire_date'] is String ? secretary!['hire_date'] : null;
    bool active = secretary?['active'] is bool ? secretary!['active'] : true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: 800,
              padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(secretary == null ? l10n.t('newSecretary') : l10n.t('editSecretary'), 
                         style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
                  ]),
                  const SizedBox(height: 24),
                  
                  _sectionHeader("INFORMATIONS PERSONNELLES", Icons.person_rounded),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field(l10n.t('firstName') + " (*)", firstNameCtrl, Icons.person_outline)),
                    const SizedBox(width: 16),
                    Expanded(child: _field(l10n.t('lastName') + " (*)", lastNameCtrl, Icons.person_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l10n.t('gender'), style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      Row(children: [
                        Radio<String>(value: 'male', groupValue: gender, onChanged: (v) => setDialogState(() => gender = v!), activeColor: AppColors.primary),
                        Text(l10n.t('male')),
                        const SizedBox(width: 10),
                        Radio<String>(value: 'female', groupValue: gender, onChanged: (v) => setDialogState(() => gender = v!), activeColor: AppColors.primary),
                        Text(l10n.t('female')),
                      ]),
                    ])),
                    const SizedBox(width: 16),
                    Expanded(child: _datePickerField(l10n.t('birthDate'), birthDate, (d) => setDialogState(() => birthDate = d))),
                  ]),
                  
                  const SizedBox(height: 24),
                  _sectionHeader("CONTACT & IDENTITÉ", Icons.contact_phone_rounded),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field(l10n.t('phone'), phoneCtrl, Icons.phone_rounded)),
                    const SizedBox(width: 16),
                    Expanded(child: _field(l10n.t('email'), emailCtrl, Icons.email_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field(l10n.t('nationalId'), cinCtrl, Icons.badge_rounded)),
                    const SizedBox(width: 16),
                    Expanded(child: _field(l10n.t('address'), addressCtrl, Icons.location_on_rounded)),
                  ]),

                  const SizedBox(height: 24),
                  _sectionHeader("PROFESSIONNEL", Icons.work_rounded),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field(l10n.t('secretaryCode'), codeCtrl, Icons.qr_code_rounded)),
                    const SizedBox(width: 16),
                    Expanded(child: _field(l10n.t('employeeId'), employeeIdCtrl, Icons.assignment_ind_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _datePickerField(l10n.t('hireDate'), hireDate, (d) => setDialogState(() => hireDate = d))),
                    const SizedBox(width: 16),
                    Expanded(child: _field(l10n.t('officeNumber'), officeCtrl, Icons.meeting_room_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field(l10n.t('workingHours'), hoursCtrl, Icons.access_time_rounded)),
                    const SizedBox(width: 16),
                    Expanded(child: Row(children: [
                      Checkbox(value: active, onChanged: (v) => setDialogState(() => active = v!), activeColor: AppColors.primary),
                      Text(l10n.t('activeStatus')),
                    ])),
                  ]),
                  const SizedBox(height: 16),
                  _field(l10n.t('notes'), notesCtrl, Icons.note_rounded, maxLines: 2),

                  const SizedBox(height: 32),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(l10n.t('cancel'))),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (firstNameCtrl.text.isEmpty || lastNameCtrl.text.isEmpty) {
                          _snack("Nom et Prénom sont obligatoires", isError: true);
                          return;
                        }
                        final vals = {
                          'first_name': firstNameCtrl.text.trim(),
                          'last_name': lastNameCtrl.text.trim(),
                          'gender': gender,
                          'birth_date': birthDate,
                          'phone': phoneCtrl.text.trim(),
                          'mobile': mobileCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'secretary_code': codeCtrl.text.trim(),
                          'national_id': cinCtrl.text.trim(),
                          'address': addressCtrl.text.trim(),
                          'employee_id': employeeIdCtrl.text.trim(),
                          'hire_date': hireDate,
                          'office_number': officeCtrl.text.trim(),
                          'working_hours': hoursCtrl.text.trim(),
                          'active': active,
                          'notes': notesCtrl.text.trim(),
                        };
                        
                        Map<String, dynamic> result;
                        if (secretary == null) {
                          result = await OdooApi.createSecretary(vals);
                        } else {
                          result = await OdooApi.updateSecretary(secretary['id'], vals);
                        }

      if (mounted) {
                          Navigator.pop(context);
                          if (result['success']) {
                            _snack(secretary == null ? l10n.t('secretaryCreated') : l10n.t('secretaryUpdated'));
                            _load();
                          } else {
                            _snack("Erreur lors de l'enregistrement", isError: true);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(l10n.t('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecond)),
    const SizedBox(height: 8),
    TextField(
      controller: ctrl, maxLines: maxLines,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
        filled: true, fillColor: AppColors.inputFill,
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
          lastDate: DateTime.now().add(const Duration(days: 365)),
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

  Widget _sectionHeader(String title, IconData icon) => Row(children: [Icon(icon, size: 18, color: AppColors.textMuted), const SizedBox(width: 8), Text(title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1.2))]);

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
          const Sidebar(currentRoute: '/secretaries'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(l10n.t('secretariesTitle'), style: _titleLg(isRtl)),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(), 
                    icon: const Icon(Icons.add_rounded), 
                    label: Text(l10n.t('newSecretary')), 
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
                ]),
                const SizedBox(height: 12),
                AppBreadcrumb(
                  items: [
                    BreadcrumbItem(label: l10n.t('home'), route: '/dashboard'),
                    BreadcrumbItem(label: l10n.t('secretariesLabel')),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSearchBar(l10n),
                const SizedBox(height: 16),
                Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : _buildTable(isRtl, l10n)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)), child: TextField(controller: _search, onChanged: _filter, decoration: InputDecoration(hintText: l10n.t('searchSecretary'), border: InputBorder.none, icon: const Icon(Icons.search))));

  Widget _buildTable(bool isRtl, AppLocalizations l10n) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primary, width: 2))), child: Row(children: [
        Expanded(flex: 3, child: _thLabel(l10n.t('fullName').toUpperCase(), isRtl)),
        Expanded(flex: 2, child: _thLabel(l10n.t('secretaryCode').toUpperCase(), isRtl)),
        Expanded(flex: 2, child: _thLabel(l10n.t('phone').toUpperCase(), isRtl)),
        Expanded(flex: 2, child: _thLabel(l10n.t('workingHours').toUpperCase(), isRtl)),
        Expanded(flex: 1, child: _thLabel(l10n.t('colStatus').toUpperCase(), isRtl)),
        Expanded(flex: 2, child: _thLabel("ACTIONS", isRtl)),
      ])),
      Expanded(child: filtered.isEmpty ? Center(child: Text(l10n.t('noSecretaryFound'))) : ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) => _row(filtered[i], i, l10n, isRtl))),
    ]),
  );

  Widget _row(Map s, int index, AppLocalizations l10n, bool isRtl) {
    String name = _s(s['full_name']);
    if (name.isEmpty) {
      name = "${_s(s['first_name'])} ${_s(s['last_name'])}".trim();
    }
    if (name.isEmpty) name = '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: index % 2 == 0 ? AppColors.surface : AppColors.surfaceAlt,
      child: Row(children: [
        Expanded(flex: 3, child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SecretaryDetailScreen(secretary: s))),
          child: Text(name, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppColors.primary)))),
        Expanded(flex: 2, child: Text(_s(s['secretary_code']).isEmpty ? '—' : _s(s['secretary_code']))),
        Expanded(flex: 2, child: Text(_s(s['phone']).isEmpty ? '—' : _s(s['phone']))),
        Expanded(flex: 2, child: Text(_s(s['working_hours']).isEmpty ? '—' : _s(s['working_hours']))),
        Expanded(flex: 1, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: (s['active'] == true) ? AppColors.greenLight : AppColors.redLight, borderRadius: BorderRadius.circular(8)),
          child: Text((s['active'] == true) ? "Actif" : "Inactif", style: TextStyle(color: (s['active'] == true) ? AppColors.green : AppColors.red, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        )),
        Expanded(flex: 2, child: Row(children: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary), onPressed: () => _showAddEditDialog(secretary: s)),
          IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.red), onPressed: () => _confirmDelete(s)),
        ])),
      ]),
    );
  }

  Widget _thLabel(String text, bool isRtl) => Text(text, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecond));
  TextStyle _titleLg(bool isRtl) => isRtl ? GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary) : GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary);
}
