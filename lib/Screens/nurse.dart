import 'dart:math';
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
import 'package:medical_app/utils/duplicate_guard.dart';

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
        final l10n = AppLocalizations.of(context);
        setState(() => loading = false);
        _snack(l10n.t('nurseLoadError'), isError: true);
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

  String _generateRandomLicense() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  void _confirmDelete(Map nurse) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('nurseDeleteTitle'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.red)),
        content: Text("${l10n.t('nurseDeleteConfirm')} ${_s(nurse['name'])} ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.t('cancel'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => loading = true);
              final res = await OdooApi.deleteNurse(nurse['id']);
              if (res['success'] == true) {
                _snack(l10n.t('nurseDeleted'));
                _load();
              } else {
                setState(() => loading = false);
                _snack(l10n.t('nurseDeleteError'), isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            child: Text(l10n.t('delete')),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog({Map? nurse}) {
    final l10n = AppLocalizations.of(context);
    final isRtl = context.read<LanguageProvider>().isArabic;
    
    final nameCtrl = TextEditingController(text: _s(nurse?['name']));
    final emailCtrl = TextEditingController(text: _s(nurse?['email']));
    final phoneCtrl = TextEditingController(text: _s(nurse?['phone']));
    final licenseCtrl = TextEditingController(text: _s(nurse?['license_number']).isEmpty ? (nurse == null ? _generateRandomLicense() : '') : _s(nurse?['license_number']));
    final ageCtrl = TextEditingController(text: _s(nurse?['age']));
    final departmentCtrl = TextEditingController(text: _s(nurse?['department_id']));
    final notesCtrl = TextEditingController(text: _s(nurse?['notes']));

    String gender = _s(nurse?['gender']).isEmpty ? 'male' : _s(nurse?['gender']);
    String state = _s(nurse?['state']).isEmpty ? 'active' : _s(nurse?['state']);
    String specialization = _s(nurse?['specialization']).isEmpty ? 'generaliste' : _s(nurse?['specialization']);
    String? expiryDate = _s(nurse?['license_expiry_date']).isEmpty ? null : _s(nurse?['license_expiry_date']);
    bool active = nurse?['active'] is bool ? nurse!['active'] : true;

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
                    Text(nurse == null ? l10n.t('newNurse') : l10n.t('editNurse'),
                        style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    IconButton(onPressed: () => Navigator.pop(dialogCtx), icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
                  ]),
                  const SizedBox(height: 24),
                  
                  _sectionHeader(l10n.t('personalInfo'), Icons.person_rounded),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field("${l10n.t('fullName')} (*)", nameCtrl, Icons.person_rounded)),
                    const SizedBox(width: 16),
                    Expanded(child: _field(l10n.t('age'), ageCtrl, Icons.cake_rounded)),
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
                    Expanded(child: _datePickerField("${l10n.t('licenseExpiry')} (*)", expiryDate, (d) => setDialogState(() => expiryDate = d))),
                  ]),

                  const SizedBox(height: 24),
                  _sectionHeader(l10n.t('contactIdentity'), Icons.contact_phone_rounded),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field("${l10n.t('email')} (*)", emailCtrl, Icons.email_rounded)),
                    const SizedBox(width: 16),
                    Expanded(child: _field(l10n.t('phone'), phoneCtrl, Icons.phone_rounded)),
                  ]),

                  const SizedBox(height: 24),
                  _sectionHeader(l10n.t('professional'), Icons.work_rounded),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("${l10n.t('licenseNumber')} (*)", style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecond)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: licenseCtrl,
                        maxLength: 8,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.badge_rounded, size: 18, color: AppColors.primary),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            onPressed: () => setDialogState(() => licenseCtrl.text = _generateRandomLicense()),
                          ),
                          filled: true, fillColor: AppColors.inputFill,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                          counterText: '',
                        ),
                      ),
                    ])),
                    const SizedBox(width: 16),
                    Expanded(child: _field(l10n.t('department'), departmentCtrl, Icons.local_hospital_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: specialization,
                        decoration: _ddDeco(l10n.t('specialization')),
                        items: [
                          DropdownMenuItem(value: 'generaliste', child: Text(l10n.t('generalist'))),
                          DropdownMenuItem(value: 'urgences', child: Text(l10n.t('emergencies'))),
                          DropdownMenuItem(value: 'pediatrie', child: Text(l10n.t('pediatrics'))),
                          DropdownMenuItem(value: 'bloc', child: Text(l10n.t('bloc'))),
                        ],
                        onChanged: (v) => setDialogState(() => specialization = v ?? 'generaliste'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: state,
                        decoration: _ddDeco(l10n.t('status')),
                        items: [
                          DropdownMenuItem(value: 'active', child: Text(l10n.t('active'))),
                          DropdownMenuItem(value: 'leave', child: Text(l10n.t('onLeave'))),
                          DropdownMenuItem(value: 'inactive', child: Text(l10n.t('inactive'))),
                        ],
                        onChanged: (v) => setDialogState(() => state = v ?? 'active'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Checkbox(value: active, onChanged: (v) => setDialogState(() => active = v!), activeColor: AppColors.primary),
                    Text(l10n.t('active')),
                  ]),
                  _field(l10n.t('notes'), notesCtrl, Icons.note_rounded, maxLines: 2),

                  const SizedBox(height: 32),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton(onPressed: () => Navigator.pop(dialogCtx), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(l10n.t('cancel'))),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty || 
                            emailCtrl.text.isEmpty || 
                            licenseCtrl.text.isEmpty || 
                            expiryDate == null || 
                            expiryDate!.isEmpty) {
                          _snack(l10n.t('allFieldsRequired'), isError: true);
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

                        final nid = nurse?['id'] is int ? nurse!['id'] as int : int.tryParse(nurse?['id']?.toString() ?? '');
                        final warnings = DuplicateGuard.nurseWarnings(
                          nurses,
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          license: licenseCtrl.text.trim(),
                          excludeId: nid,
                        );
                        if (warnings.isNotEmpty) {
                          final proceed = await showDuplicateProceedDialog(
                            dialogCtx,
                            title: nurse == null ? l10n.t('duplicateWarn') : l10n.t('duplicateConflict'),
                            warnings: warnings,
                            confirmLabel: l10n.t('saveAnyway'),
                          );
                          if (!proceed) return;
                        }

                        final result = nurse == null ? await OdooApi.createNurse(vals) : await OdooApi.updateNurse(nurse['id'], vals);
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        if (result['success'] == true) {
                          _snack(nurse == null ? l10n.t('nurseCreated') : l10n.t('nurseUpdated'));
                          _load();
                        } else {
                          _snack(l10n.t('nurseSaveError'), isError: true);
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
          const Sidebar(currentRoute: '/nurses'),
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
        BreadcrumbItem(label: l10n.t('nursesTitle')),
      ]),
      const Spacer(),
      Container(
        width: 300,
        height: 44,
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: TextField(
          controller: _search,
          onChanged: _filter,
          decoration: InputDecoration(hintText: l10n.t('nurseSearchHint'), hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted), prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 10)),
        ),
      ),
      const SizedBox(width: 16),
      ElevatedButton.icon(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add, size: 20),
        label: Text(l10n.t('newNurse'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
              Expanded(flex: 2, child: _th(l10n.t('colLicense'))),
              Expanded(flex: 2, child: _th(l10n.t('phone'))),
              Expanded(flex: 3, child: _th(l10n.t('email'))),
              Expanded(flex: 2, child: _th(l10n.t('specialization'))),
              Expanded(flex: 1, child: _th(l10n.t('colStatus'))),
              Expanded(flex: 2, child: _th(l10n.t('colActions'))),
            ]),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(l10n.t('noNurseFound')))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildNurseRow(filtered[index], index, l10n),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _buildNurseRow(Map n, int index, AppLocalizations l10n) {
    String name = _s(n['name']).isEmpty ? '—' : _s(n['name']);

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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NurseDetailScreen(nurse: n))),
            child: Row(children: [
              CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withOpacity(0.1), child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12))),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppColors.primary))),
            ]),
          ),
        ),
        Expanded(flex: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)), child: Text(_s(n['license_number']), style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)))),
        Expanded(flex: 2, child: Text(_s(n['phone']))),
        Expanded(flex: 3, child: Text(_s(n['email']))),
        Expanded(flex: 2, child: Text(_getSpecializationLabel(n['specialization'], l10n))),
        Expanded(flex: 1, child: _statusBadge(n['state'], l10n)),
        Expanded(
          flex: 2,
          child: Row(children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary), onPressed: () => _showAddEditDialog(nurse: n)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.red), onPressed: () => _confirmDelete(n)),
          ]),
        ),
      ]),
    );
  }

  String _getSpecializationLabel(dynamic spec, AppLocalizations l10n) {
    final s = _s(spec);
    switch(s) {
      case 'generaliste': return l10n.t('generalist');
      case 'urgences': return l10n.t('emergencies');
      case 'pediatrie': return l10n.t('pediatrics');
      case 'bloc': return l10n.t('bloc');
      default: return s.isEmpty ? '—' : s;
    }
  }

  Widget _th(String text) => Text(text.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecond));

  Widget _statusBadge(String? state, AppLocalizations l10n) {
    final s = _s(state);
    Color color;
    Color bgColor;
    String label;
    switch(s) {
      case 'active': color = AppColors.green; bgColor = AppColors.green.withOpacity(0.1); label = "ACTIF"; break;
      case 'leave': color = AppColors.yellow; bgColor = AppColors.yellow.withOpacity(0.1); label = "CONGÉ"; break;
      case 'inactive': color = AppColors.red; bgColor = AppColors.red.withOpacity(0.1); label = "INACTIF"; break;
      default: color = AppColors.textMuted; bgColor = AppColors.textMuted.withOpacity(0.1); label = "INCONNU";
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)), child: Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: color)));
  }
}
