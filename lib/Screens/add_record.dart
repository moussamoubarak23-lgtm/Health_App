import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';
import 'package:medical_app/Widgets/app_breadcrumb.dart';

class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({super.key});
  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _reasonCtrl   = TextEditingController();
  final _fileNumCtrl  = TextEditingController();
  final _diagnostic   = TextEditingController();
  final _prescription = TextEditingController();
  final _observations = TextEditingController();

  bool    _saving           = false;
  String? _success;
  String? _error;
  List    patients          = [];
  int?    selectedPatientId;
  String  selectedStatus    = 'draft';
  DateTime selectedDate     = DateTime.now();
  int     _uid              = 0;

  @override
  void initState() { super.initState(); _init(); }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Map && selectedPatientId == null) {
      setState(() {
        selectedPatientId = arg['id'];
        // Synchronisation : on récupère le medical_file_number du patient s'il existe
        final dossier = arg['medical_file_number'];
        if (dossier != null && dossier != false && dossier.toString().isNotEmpty) {
          _fileNumCtrl.text = dossier.toString();
        }
      });
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _uid = prefs.getInt('uid') ?? 0);
    final p = await OdooApi.getPatients();
    setState(() => patients = p);
    
    // Si un patient est déjà sélectionné, on s'assure d'avoir son numéro de dossier
    if (selectedPatientId != null && _fileNumCtrl.text.isEmpty) {
      try {
        final selected = patients.firstWhere((pat) => pat['id'] == selectedPatientId);
        final dossier = selected['medical_file_number'];
        if (dossier != null && dossier != false) {
          setState(() => _fileNumCtrl.text = dossier.toString());
        }
      } catch (_) {}
    }
  }

  Future<void> _save(AppLocalizations l10n) async {
    setState(() { _error = null; _success = null; });
    if (selectedPatientId == null) {
      setState(() => _error = l10n.t('patientRequired')); return;
    }
    if (_uid == 0) {
      setState(() => _error = l10n.t('sessionExpired')); return;
    }
    if (_diagnostic.text.trim().isEmpty) {
      setState(() => _error = l10n.t('diagnosticRequired')); return;
    }

    setState(() => _saving = true);
    final dt  = selectedDate;
    final now = TimeOfDay.now();
    final datetimeStr =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';

    final result = await OdooApi.addMedicalRecord(
      patientId: selectedPatientId!,
      doctorId: _uid,
      datetime: datetimeStr,
      consultationReason: _reasonCtrl.text.trim(),
      diagnostic: _diagnostic.text.trim(),
      prescription: _prescription.text.trim(),
      observations: _observations.text.trim(),
      status: selectedStatus,
      medicalFileNumber: _fileNumCtrl.text.trim(),
    );
    setState(() => _saving = false);

    if (result['success'] == true) {
      setState(() {
        _success = '${l10n.t('consultCreated')} (ID: ${result['id']})';
        _reasonCtrl.clear(); _fileNumCtrl.clear(); _diagnostic.clear();
        _prescription.clear(); _observations.clear();
        selectedPatientId = null; selectedStatus = 'draft'; selectedDate = DateTime.now();
      });
    } else {
      setState(() => _error = result['error'] ?? l10n.t('error'));
    }
  }

  Color _statusColor(String? v) {
    switch (v) {
      case 'confirmed': return AppColors.green;
      case 'invoiced':  return AppColors.primary;
      default:          return AppColors.yellow;
    }
  }

  String _selectedPatientName(AppLocalizations l10n) {
    for (final p in patients) {
      if (p['id'] == selectedPatientId) {
        return p['name']?.toString() ?? l10n.t('selectPatient');
      }
    }
    return l10n.t('selectPatient');
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final lang  = context.watch<LanguageProvider>();
    final isRtl = lang.isArabic;

    final statusOptions = [
      {'value': 'draft',     'label': l10n.t('statusDraft')},
      {'value': 'confirmed', 'label': l10n.t('statusConfirmed')},
      {'value': 'invoiced',  'label': l10n.t('statusInvoiced')},
    ];
    final selectedPatientName = _selectedPatientName(l10n);
    final selectedStatusLabel = statusOptions.firstWhere(
      (s) => s['value'] == selectedStatus,
      orElse: () => statusOptions.first,
    )['label']!;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(children: [
          const Sidebar(currentRoute: '/add_record'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.t('newConsultation'), style: _titleLg(isRtl)),
                Text(l10n.t('newConsultSubtitle'), style: _mutedStyle(isRtl)),
                const SizedBox(height: 12),
                AppBreadcrumb(
                  items: [
                    BreadcrumbItem(label: l10n.t('home'), route: '/dashboard'),
                    BreadcrumbItem(label: l10n.t('recordsLabel'), route: '/records'),
                    BreadcrumbItem(label: l10n.t('newConsultLabel')),
                  ],
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _summaryTile(l10n.t('selectedPatient'), selectedPatientName, Icons.person_rounded, AppColors.primary, AppColors.primaryLight, isRtl)),
                  const SizedBox(width: 12),
                  Expanded(child: _summaryTile(l10n.t('consultDate'), '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}', Icons.calendar_today_rounded, AppColors.green, AppColors.greenLight, isRtl)),
                  const SizedBox(width: 12),
                  Expanded(child: _summaryTile(l10n.t('status'), selectedStatusLabel, Icons.flag_rounded, _statusColor(selectedStatus), AppColors.surfaceAlt, isRtl)),
                ]),
                const SizedBox(height: 20),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    flex: 3,
                    child: _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionTitle(l10n.t('patientInfo'), Icons.person_rounded, AppColors.primary, AppColors.primaryLight, isRtl),
                      const SizedBox(height: 20),
                      _fieldLabel(l10n.t('patientRequired2'), isRtl),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: selectedPatientId,
                        dropdownColor: AppColors.surface,
                        style: isRtl ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 14) : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14),
                        decoration: _inputDeco(l10n.t('selectPatient'), isRtl),
                        items: patients.map<DropdownMenuItem<int>>((p) => DropdownMenuItem(
                          value: p['id'] as int,
                          child: Text(p['name'].toString(), style: isRtl ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 14) : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14)),
                        )).toList(),
                        onChanged: (v) {
                          setState(() {
                            selectedPatientId = v;
                            try {
                              final selected = patients.firstWhere((pat) => pat['id'] == v);
                              final dossier = selected['medical_file_number'];
                              if (dossier != null && dossier != false) {
                                _fileNumCtrl.text = dossier.toString();
                              } else {
                                _fileNumCtrl.clear();
                              }
                            } catch (_) {
                              _fileNumCtrl.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel("Numéro de Dossier", isRtl),
                      const SizedBox(height: 8),
                      _textArea(_fileNumCtrl, "Numéro du dossier (automatique si déjà renseigné sur le patient)", 1, isRtl, accentColor: AppColors.primary),
                      const SizedBox(height: 18),
                      _fieldLabel(l10n.t('consultDate'), isRtl),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            locale: isRtl ? const Locale('ar') : const Locale('fr'),
                            builder: (ctx, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
                          );
                          if (d != null) setState(() => selectedDate = d);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                          child: Row(children: [
                            const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 10),
                            Text(isRtl ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}' : '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}', style: isRtl ? GoogleFonts.cairo(color: AppColors.textSecond, fontSize: 14) : GoogleFonts.dmSans(color: AppColors.textSecond, fontSize: 14)),
                            const Spacer(),
                            Text(l10n.t('modifyDate'), style: isRtl ? GoogleFonts.cairo(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600) : GoogleFonts.dmSans(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel(l10n.t('status'), isRtl),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        dropdownColor: AppColors.surface,
                        style: isRtl ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 14) : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14),
                        decoration: _inputDeco(l10n.t('consultStatus'), isRtl),
                        items: statusOptions.map((s) => DropdownMenuItem(
                          value: s['value'],
                          child: Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: _statusColor(s['value']), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(s['label']!, style: isRtl ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 14) : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14)),
                          ]),
                        )).toList(),
                        onChanged: (v) => setState(() => selectedStatus = v ?? 'draft'),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel(l10n.t('consultReason'), isRtl),
                      const SizedBox(height: 8),
                      _textArea(_reasonCtrl, l10n.t('reasonHint'), 2, isRtl, accentColor: AppColors.yellow),
                    ])),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionTitle(l10n.t('medicalData'), Icons.medical_information_rounded, AppColors.red, AppColors.redLight, isRtl),
                      const SizedBox(height: 20),
                      _fieldLabel(l10n.t('diagnosticLabel'), isRtl),
                      const SizedBox(height: 8),
                      _textArea(_diagnostic, l10n.t('diagnosticHint'), 3, isRtl, accentColor: AppColors.primary),
                      const SizedBox(height: 18),
                      _fieldLabel(l10n.t('prescription'), isRtl),
                      const SizedBox(height: 8),
                      _textArea(_prescription, l10n.t('prescriptionHint'), 3, isRtl, accentColor: AppColors.purple),
                      const SizedBox(height: 18),
                      _fieldLabel(l10n.t('observationsFollowUp'), isRtl),
                      const SizedBox(height: 8),
                      _textArea(_observations, l10n.t('observationsHint'), 3, isRtl, accentColor: AppColors.green),
                    ])),
                  ),
                ]),
                const SizedBox(height: 18),
                _card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _sectionTitle(l10n.t('consultationGuide'), Icons.checklist_rounded, AppColors.purple, AppColors.purpleLight, isRtl),
                    const SizedBox(height: 12),
                    Text(l10n.t('consultationGuideHint'), style: _mutedStyle(isRtl)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _guideStep(Icons.info_rounded, l10n.t('consultReason'), AppColors.yellow, AppColors.yellowLight, isRtl),
                        _guideStep(Icons.medical_information_rounded, l10n.t('diagnostic'), AppColors.primary, AppColors.primaryLight, isRtl),
                        _guideStep(Icons.medication_rounded, l10n.t('prescription'), AppColors.purple, AppColors.purpleLight, isRtl),
                        _guideStep(Icons.notes_rounded, l10n.t('observationsFollowUp'), AppColors.green, AppColors.greenLight, isRtl),
                      ],
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                if (_error != null) ...[_alertBox(_error!, true, isRtl), const SizedBox(height: 10)],
                if (_success != null) ...[_alertBox(_success!, false, isRtl), const SizedBox(height: 10)],
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/records'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.textMuted, side: const BorderSide(color: AppColors.border), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(l10n.t('cancel'), style: _btnTxt(isRtl)),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : () => _save(l10n),
                    icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 18),
                    label: Text(l10n.t('saveConsultation'), style: _btnTxt(isRtl, white: true)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: child);
  Widget _summaryTile(String label, String value, IconData icon, Color color, Color bg, bool isRtl) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: color)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: isRtl ? GoogleFonts.cairo(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700) : GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(value, overflow: TextOverflow.ellipsis, style: isRtl ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700) : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700))]))]));
  Widget _guideStep(IconData icon, String text, Color color, Color bg, bool isRtl) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: color), const SizedBox(width: 8), Text(text, style: isRtl ? GoogleFonts.cairo(color: color, fontSize: 12, fontWeight: FontWeight.w700) : GoogleFonts.dmSans(color: color, fontSize: 12, fontWeight: FontWeight.w700))]));
  Widget _sectionTitle(String title, IconData icon, Color color, Color bg, bool isRtl) => Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 17, color: color)), const SizedBox(width: 10), Text(title, style: isRtl ? GoogleFonts.cairo(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15) : GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15))]);
  Widget _fieldLabel(String text, bool isRtl) => Text(text, style: isRtl ? GoogleFonts.cairo(color: AppColors.textSecond, fontSize: 12, fontWeight: FontWeight.w600) : GoogleFonts.dmSans(color: AppColors.textSecond, fontSize: 12, fontWeight: FontWeight.w600));
  InputDecoration _inputDeco(String hint, bool isRtl) => InputDecoration(hintText: hint, hintStyle: isRtl ? GoogleFonts.cairo(color: AppColors.textHint, fontSize: 14) : GoogleFonts.dmSans(color: AppColors.textHint, fontSize: 14), filled: true, fillColor: AppColors.inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14));
  Widget _textArea(TextEditingController ctrl, String hint, int lines, bool isRtl, {Color accentColor = AppColors.primary}) => TextField(controller: ctrl, maxLines: lines, textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, style: isRtl ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 14) : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14), decoration: InputDecoration(hintText: hint, hintStyle: isRtl ? GoogleFonts.cairo(color: AppColors.textHint, fontSize: 13) : GoogleFonts.dmSans(color: AppColors.textHint, fontSize: 13), filled: true, fillColor: AppColors.inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 2)), contentPadding: const EdgeInsets.all(14)));
  Widget _alertBox(String msg, bool isError, bool isRtl) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: isError ? AppColors.redLight : AppColors.greenLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: (isError ? AppColors.red : AppColors.green).withOpacity(0.3))), child: Row(children: [Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: isError ? AppColors.red : AppColors.green, size: 16), const SizedBox(width: 10), Expanded(child: Text(msg, style: isRtl ? GoogleFonts.cairo(color: isError ? AppColors.red : AppColors.green, fontSize: 13) : GoogleFonts.dmSans(color: isError ? AppColors.red : AppColors.green, fontSize: 13)))]));
  TextStyle _titleLg(bool r) => r ? GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary) : GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary);
  TextStyle _mutedStyle(bool r) => r ? GoogleFonts.cairo(fontSize: 14, color: AppColors.textMuted) : GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted);
  TextStyle _btnTxt(bool r, {bool white = false}) => r ? GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: white ? Colors.white : AppColors.textSecond) : GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: white ? Colors.white : AppColors.textSecond);
}
