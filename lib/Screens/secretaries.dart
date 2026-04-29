import 'dart:math';
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
import 'package:medical_app/utils/duplicate_guard.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
        final l10n = AppLocalizations.of(context);
        setState(() => loading = false);
        _snack(l10n.t('secLoadError'), isError: true);
      }
    }
  }

  void _filter(String q) {
    setState(() {
      filtered = q.isEmpty
          ? secretaries
          : secretaries.where((s) =>
              _s(s['full_name']).toLowerCase().contains(q.toLowerCase()) ||
              _s(s['first_name']).toLowerCase().contains(q.toLowerCase()) ||
              _s(s['last_name']).toLowerCase().contains(q.toLowerCase()) ||
              _s(s['phone']).contains(q) ||
              _s(s['secretary_code']).toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  void _confirmDelete(Map s) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('deleteSecretaryTitle'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.red)),
        content: Text("${l10n.t('deleteSecretaryConfirm')} ${_s(s['full_name'])} ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.t('cancel'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => loading = true);
              final res = await OdooApi.deleteSecretary(s['id']);
              if (res['success']) {
                _snack(l10n.t('secretaryDeleted'));
                _load();
              } else {
                setState(() => loading = false);
                _snack(l10n.t('error'), isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            child: Text(l10n.t('delete')),
          ),
        ],
      ),
    );
  }

  String _s(dynamic val) => (val is String) ? val : (val == null || val == false ? '' : val.toString());

  String _generateRandomCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  void _showAddEditDialog({Map? secretary}) {
    final l10n = AppLocalizations.of(context);
    final isRtl = context.read<LanguageProvider>().isArabic;
    
    final firstNameCtrl = TextEditingController(text: _s(secretary?['first_name']));
    final lastNameCtrl = TextEditingController(text: _s(secretary?['last_name']));
    final phoneCtrl = TextEditingController(text: _s(secretary?['phone']));
    final mobileCtrl = TextEditingController(text: _s(secretary?['mobile']));
    final emailCtrl = TextEditingController(text: _s(secretary?['email']));
    final codeCtrl = TextEditingController(text: _s(secretary?['secretary_code']).isEmpty ? (secretary == null ? _generateRandomCode() : '') : _s(secretary?['secretary_code']));
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
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialogState) => Directionality(
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
                    IconButton(onPressed: () => Navigator.pop(dialogCtx), icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
                  ]),
                  const SizedBox(height: 24),
                  
                  _sectionHeader(l10n.t('personalInfo'), Icons.person_rounded),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field("${l10n.t('firstName')} (*)", firstNameCtrl, Icons.person_outline)),
                    const SizedBox(width: 16),
                    Expanded(child: _field("${l10n.t('lastName')} (*)", lastNameCtrl, Icons.person_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("${l10n.t('gender')} (*)", style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      Row(children: [
                        Radio<String>(value: 'male', groupValue: gender, onChanged: (v) => setDialogState(() => gender = v!), activeColor: AppColors.primary),
                        Text(l10n.t('maleLabel')),
                        const SizedBox(width: 10),
                        Radio<String>(value: 'female', groupValue: gender, onChanged: (v) => setDialogState(() => gender = v!), activeColor: AppColors.primary),
                        Text(l10n.t('femaleLabel')),
                      ]),
                    ])),
                    const SizedBox(width: 16),
                    Expanded(child: _datePickerField("${l10n.t('birthDate')} (*)", birthDate, (d) => setDialogState(() => birthDate = d))),
                  ]),
                  
                  const SizedBox(height: 24),
                  _sectionHeader(l10n.t('contactIdentity'), Icons.contact_phone_rounded),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field(l10n.t('phone'), phoneCtrl, Icons.phone_rounded)),
                    const SizedBox(width: 16),
                    Expanded(child: _field("${l10n.t('email')} (*)", emailCtrl, Icons.email_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field(l10n.t('nationalId'), cinCtrl, Icons.badge_rounded)),
                    const SizedBox(width: 16),
                    Expanded(child: _field(l10n.t('address'), addressCtrl, Icons.location_on_rounded)),
                  ]),

                  const SizedBox(height: 24),
                  _sectionHeader(l10n.t('professional'), Icons.work_rounded),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("${l10n.t('secretaryCode')} (*)", style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecond)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: codeCtrl,
                        maxLength: 8,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.qr_code_rounded, size: 18, color: AppColors.primary),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            onPressed: () => setDialogState(() => codeCtrl.text = _generateRandomCode()),
                          ),
                          filled: true, fillColor: AppColors.inputFill,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                          counterText: '',
                        ),
                      ),
                    ])),
                    const SizedBox(width: 16),
                    Expanded(child: _field("${l10n.t('employeeId')} (*)", employeeIdCtrl, Icons.assignment_ind_rounded)),
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
                    OutlinedButton(onPressed: () => Navigator.pop(dialogCtx), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(l10n.t('cancel'))),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (firstNameCtrl.text.isEmpty || 
                            lastNameCtrl.text.isEmpty || 
                            emailCtrl.text.isEmpty || 
                            employeeIdCtrl.text.isEmpty || 
                            codeCtrl.text.isEmpty || 
                            birthDate == null || 
                            birthDate!.isEmpty) {
                          _snack(l10n.t('allFieldsRequired'), isError: true);
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
                        
                        final sid = secretary?['id'] is int ? secretary!['id'] as int : int.tryParse(secretary?['id']?.toString() ?? '');
                        final warnings = DuplicateGuard.secretaryWarnings(
                          secretaries,
                          firstName: firstNameCtrl.text.trim(),
                          lastName: lastNameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          mobile: mobileCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          code: codeCtrl.text.trim(),
                          nationalId: cinCtrl.text.trim(),
                          excludeId: sid,
                        );
                        if (warnings.isNotEmpty) {
                          final proceed = await showDuplicateProceedDialog(
                            dialogCtx,
                            title: secretary == null ? l10n.t('duplicateWarn') : l10n.t('duplicateConflict'),
                            warnings: warnings,
                            confirmLabel: l10n.t('saveAnyway'),
                          );
                          if (!proceed) return;
                        }

                        Map<String, dynamic> result;
                        if (secretary == null) {
                          result = await OdooApi.createSecretary(vals);
                        } else {
                          result = await OdooApi.updateSecretary(secretary['id'], vals);
                        }

                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        if (result['success']) {
                          _snack(secretary == null ? l10n.t('secretaryCreated') : l10n.t('secretaryUpdated'));
                          _load();
                        } else {
                          _snack(l10n.t('error'), isError: true);
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

  Widget _datePickerField(String label, String? value, Function(String) onSelected) {
    final l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            Text((value == null || value.isEmpty) ? l10n.t('selectDate') : value, style: GoogleFonts.dmSans(color: (value == null || value.isEmpty) ? AppColors.textHint : AppColors.textPrimary)),
          ]),
        ),
      ),
    ]);
  }

  Widget _sectionHeader(String title, IconData icon) => Row(children: [Icon(icon, size: 18, color: AppColors.textMuted), const SizedBox(width: 8), Text(title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1.2))]);

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.red : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = context.watch<LanguageProvider>().isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(children: [
          const Sidebar(currentRoute: '/secretaries'),
          Expanded(child: Column(children: [
            _buildAppBar(l10n),
            Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : _buildContent(l10n)),
          ])),
        ]),
      ),
    );
  }

  Widget _buildAppBar(AppLocalizations l10n) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
    child: Row(children: [
      AppBreadcrumb(items: [
        BreadcrumbItem(label: l10n.t('home'), route: '/dashboard'),
        BreadcrumbItem(label: l10n.t('secretariesLabel')),
      ]),
      const Spacer(),
      Container(
        width: 300,
        height: 44,
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: TextField(
          controller: _search,
          onChanged: _filter,
          decoration: InputDecoration(hintText: l10n.t('searchSecretary'), hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted), prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 10)),
        ),
      ),
      const SizedBox(width: 16),
      ElevatedButton.icon(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add, size: 20),
        label: Text(l10n.t('newSecretary'), style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
      ),
    ]),
  );

  Widget _buildContent(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primary, width: 2))),
            child: Row(children: [
              Expanded(flex: 3, child: _th(l10n.t('colName'))),
              Expanded(flex: 2, child: _th(l10n.t('employeeId'))),
              Expanded(flex: 2, child: _th(l10n.t('phone'))),
              Expanded(flex: 3, child: _th(l10n.t('email'))),
              Expanded(flex: 2, child: _th(l10n.t('secretaryCode'))),
              Expanded(flex: 1, child: _th(l10n.t('colStatus'))),
              Expanded(flex: 2, child: _th(l10n.t('colActions'))),
            ]),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(l10n.t('noSecretaryFound')))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildSecretaryRow(filtered[index], index, l10n),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSecretaryRow(Map s, int index, AppLocalizations l10n) {
    String name = _s(s['full_name']);
    if (name.isEmpty) name = "${_s(s['first_name'])} ${_s(s['last_name'])}".trim();
    if (name.isEmpty) name = "—";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : AppColors.surfaceAlt,
        border: const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SecretaryDetailScreen(secretary: s))),
            child: Row(children: [
              CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withOpacity(0.1), child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12))),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppColors.primary))),
            ]),
          ),
        ),
        Expanded(flex: 2, child: Text(_s(s['employee_id']))),
        Expanded(flex: 2, child: Text(_s(s['phone']))),
        Expanded(flex: 3, child: Text(_s(s['email']))),
        Expanded(flex: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)), child: Text(_s(s['secretary_code']), style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)))),
        Expanded(flex: 1, child: _statusBadge(s['active'] == true)),
        Expanded(
          flex: 2,
          child: Row(children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary), onPressed: () => _showAddEditDialog(secretary: s)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.red), onPressed: () => _confirmDelete(s)),
          ]),
        ),
      ]),
    );
  }

  Widget _th(String text) => Text(text.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecond));

  Widget _statusBadge(bool active) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: active ? AppColors.green.withOpacity(0.1) : AppColors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(active ? "ACTIF" : "INACTIF", style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: active ? AppColors.green : AppColors.red)));
}
