import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';
import 'package:medical_app/Screens/patient_detail.dart';
import 'package:medical_app/Widgets/app_breadcrumb.dart';
import 'package:medical_app/utils/duplicate_guard.dart';
import 'package:medical_app/utils/medical_file_number_suggest.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});
  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  List patients = [];
  List filtered = [];
  bool loading = true;
  final _search = TextEditingController();
  int _currentPage = 1;
  static const int _perPage = 30;

  static const List<String> nationalities = [
    "Marocaine", "Française", "Algérienne", "Tunisienne", "Espagnole", "Italienne", "Sénégalaise", "Malienne", "Ivoirienne", "Américaine", "Canadienne", "Allemande", "Belge", "Suisse", "Libyenne", "Égyptienne", "Saoudienne", "Émiratie", "Qatarienne", "Koweïtienne", "Bahreïnie", "Omanaise", "Jordanienne", "Libanaise", "Syrienne", "Irakienne", "Yéménite", "Soudanaise", "Mauritanienne", "Portugaise", "Néerlandaise"
  ];

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
      final p = await OdooApi.getPatients();
      if (mounted) {
        setState(() {
          patients = p;
          filtered = p;
          loading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() => loading = false);
        _snack(l10n.t('error'), isError: true);
      }
    }
  }

  void _filter(String q) {
    setState(() {
      _currentPage = 1;
      filtered = q.isEmpty
          ? patients
          : patients.where((p) =>
              p['name'].toString().toLowerCase().contains(q.toLowerCase()) ||
              p['phone'].toString().contains(q) ||
              p['patient_code'].toString().toLowerCase().contains(q.toLowerCase()) ||
              p['medical_file_number'].toString().toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  List get _paginated {
    final start = (_currentPage - 1) * _perPage;
    final end = (start + _perPage).clamp(0, filtered.length);
    if (start >= filtered.length) return [];
    return filtered.sublist(start, end);
  }

  int get _totalPages => (filtered.length / _perPage).ceil().clamp(1, 999);

  String _s(dynamic val) => (val is String) ? val : (val == null || val == false ? '' : val.toString());

  void _confirmDelete(Map p) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('deletePatientTitle'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.red)),
        content: Text("${l10n.t('deletePatientWarn')} ${p['name']} ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.t('cancel'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => loading = true);
              final res = await OdooApi.deletePatient(p['id']);
              if (res['success']) {
                _snack(l10n.t('patientUpdated'));
                _load();
              } else {
                setState(() => loading = false);
                _snack(l10n.t('error'), isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            child: Text(l10n.t('deleteAll')),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(AppLocalizations l10n, bool isRtl) {
    final dossierCtrl = TextEditingController(text: MedicalFileNumberSuggest.suggestNext(patients));
    final cinCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final prenomCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String sexe = 'H';
    String couverture = 'Sans';
    String nationalite = 'Marocaine';

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
                    Text(l10n.t('newPatientTitle2'), style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    IconButton(onPressed: () => Navigator.pop(dialogCtx), icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
                  ]),
                  const SizedBox(height: 24),
                  _sectionHeader(l10n.t('essentialInfo'), Icons.person_add_rounded),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _field("${l10n.t('lastName')} (*)", nomCtrl, Icons.person_rounded)),
                    const SizedBox(width: 16),
                    Expanded(child: _field("${l10n.t('firstName')} (*)", prenomCtrl, Icons.person_outline_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field("${l10n.t('age')} (*)", ageCtrl, Icons.cake_rounded, inputType: TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("${l10n.t('gender')} (*)", style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        Row(children: [
                          Radio<String>(value: 'H', groupValue: sexe, onChanged: (v) => setDialogState(() => sexe = v!), activeColor: AppColors.primary),
                          Text(l10n.t('maleLabel')),
                          const SizedBox(width: 10),
                          Radio<String>(value: 'F', groupValue: sexe, onChanged: (v) => setDialogState(() => sexe = v!), activeColor: AppColors.primary),
                          Text(l10n.t('femaleLabel')),
                        ]),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _sectionHeader(l10n.t('contactIdentity'), Icons.contact_phone_rounded),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _field(l10n.t('medicalFileNumber'), dossierCtrl, Icons.folder_shared_rounded, hintText: l10n.t('fileNumHint'))),
                    const SizedBox(width: 16),
                    Expanded(child: _field(l10n.t('nationalId'), cinCtrl, Icons.badge_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field(l10n.t('phone'), phoneCtrl, Icons.phone_rounded, inputType: TextInputType.phone)),
                    const SizedBox(width: 16),
                    Expanded(child: _dropdownSearch("${l10n.t('nationality')} (*)", nationalite, (v) => setDialogState(() => nationalite = v))),
                  ]),
                  const SizedBox(height: 16),
                  _dropdown(l10n.t('socialCoverage'), couverture, ["Sans", "AMO", "RAMED", "CNOPS", "Privé"], (v) => setDialogState(() => couverture = v!)),
                  const SizedBox(height: 32),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton(onPressed: () => Navigator.pop(dialogCtx), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(l10n.t('cancel'))),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (nomCtrl.text.trim().isEmpty || prenomCtrl.text.trim().isEmpty || ageCtrl.text.trim().isEmpty) {
                          _snack(l10n.t('allFieldsRequired'), isError: true);
                          return;
                        }
                        final fullName = "${nomCtrl.text.trim()} ${prenomCtrl.text.trim()}";
                        final warnings = DuplicateGuard.patientWarnings(
                          patients,
                          fullName: fullName,
                          phone: phoneCtrl.text.trim(),
                          cin: cinCtrl.text.trim(),
                          dossier: dossierCtrl.text.trim(),
                        );
                        if (warnings.isNotEmpty) {
                          final proceed = await showDuplicateProceedDialog(
                            dialogCtx,
                            title: l10n.t('duplicateWarn'),
                            warnings: warnings,
                          );
                          if (!proceed) return;
                        }
                        final result = await OdooApi.createPatient(
                          name: fullName,
                          medicalFileNumber: dossierCtrl.text.trim(),
                          patientCode: cinCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          insuranceId: couverture,
                          height: 0.0,
                          age: int.tryParse(ageCtrl.text.trim()) ?? 0,
                          comment: "Sexe: $sexe | Nationalité: $nationalite",
                        );
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        if (result['success']) {
                          _load();
                          _showPostCreateOptions(fullName, result['id'], dossierCtrl.text.trim(), l10n);
                        } else {
                          _snack(l10n.t('error'), isError: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<bool> _shouldShowCalendarQuickAccess() async {
    final records = await OdooApi.getMedicalRecords();
    final today = DateTime.now();
    final todayPatientIds = <int>{};
    for (final raw in records) {
      if (raw is! Map) continue;
      final rec = Map<String, dynamic>.from(raw);
      final rawDate = rec['date_consultation']?.toString() ?? '';
      if (rawDate.isEmpty) continue;
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null || !_isSameDay(parsed, today)) continue;
      final patientRef = rec['patient_id'];
      if (patientRef is List && patientRef.isNotEmpty && patientRef.first is int) {
        todayPatientIds.add(patientRef.first as int);
      }
    }
    return todayPatientIds.length >= 2;
  }

  Future<void> _showPostCreateOptions(String name, int id, String dossier, AppLocalizations l10n) async {
    final showCalendarButton = await _shouldShowCalendarQuickAccess();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (postCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.t('patientCreatedTitle'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        content: Text(l10n.t('patientCreatedQuestion')),
        actions: [
          OutlinedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final doctorId = prefs.getInt('uid') ?? 0;
              final now = DateTime.now().toString().substring(0, 19);
              
              await OdooApi.addMedicalRecord(
                patientId: id,
                doctorId: doctorId,
                datetime: now,
                consultationReason: "Consultation",
                diagnostic: '', prescription: '', observations: '',
                status: 'waiting',
                medicalFileNumber: dossier,
              );
              if (!postCtx.mounted) return;
              Navigator.pop(postCtx);
              _snack(l10n.t('consultationAdded'));
            },
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(l10n.t('addConsultation')),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(postCtx);
              _showScheduleFromPatient(id, name, dossier, l10n);
            },
            icon: const Icon(Icons.calendar_month),
            label: Text(l10n.t('scheduleRdv')),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
          if (showCalendarButton)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(postCtx);
                Navigator.pushNamed(context, '/calendar');
              },
              icon: const Icon(Icons.event_note_rounded),
              label: Text(l10n.t('calendarLabel')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  void _showScheduleFromPatient(int id, String name, String dossier, AppLocalizations loc) {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final motifCtrl = TextEditingController(text: "Consultation");

    showDialog(
      context: context,
      builder: (schedCtx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("${loc.t('scheduleFor')} $name"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(loc.t('reason'), motifCtrl, Icons.notes),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(context: schedCtx, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (date != null) setDialogState(() => selectedDate = date);
                },
                child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.event, color: AppColors.primary), const SizedBox(width: 12), Text(intl.DateFormat('dd/MM/yyyy').format(selectedDate))])),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final time = await showTimePicker(context: schedCtx, initialTime: selectedTime);
                  if (time != null) setDialogState(() => selectedTime = time);
                },
                child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.access_time, color: AppColors.primary), const SizedBox(width: 12), Text(selectedTime.format(schedCtx))])),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(schedCtx), child: Text(loc.t('cancel'))),
            ElevatedButton(
              onPressed: () async {
                final scheduledDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                final prefs = await SharedPreferences.getInstance();
                final doctorId = prefs.getInt('uid') ?? 0;
                
                final res = await OdooApi.addMedicalRecord(
                  patientId: id,
                  doctorId: doctorId,
                  datetime: scheduledDateTime.toString().substring(0, 19),
                  consultationReason: motifCtrl.text.trim(),
                  diagnostic: '', prescription: '', observations: '',
                  status: 'waiting',
                  medicalFileNumber: dossier,
                );
                
                if (!schedCtx.mounted) return;
                Navigator.pop(schedCtx);
                if (res['success']) {
                  _snack(loc.t('appointmentPlanned'));
                }
              },
              child: Text(loc.t('confirm')),
            )
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Map p, AppLocalizations l10n, bool isRtl) {
    final name = _s(p['name']);
    final parts = name.split(' ');
    final nomCtrl = TextEditingController(text: parts.first);
    final prenomCtrl = TextEditingController(text: parts.length > 1 ? parts.sublist(1).join(' ') : '');
    
    final cinCtrl = TextEditingController(text: _s(p['patient_code']));
    final dossierCtrl = TextEditingController(text: _s(p['medical_file_number']));
    final phoneCtrl = TextEditingController(text: _s(p['phone']));
    final insuranceCtrl = TextEditingController(text: _s(p['insurance_id']));
    final ageCtrl = TextEditingController(text: p['age']?.toString() ?? '');
    
    String sexe = 'H';
    String nationalite = 'Marocaine';
    
    final comment = _s(p['comment']);
    if (comment.contains('Sexe: F')) sexe = 'F';
    if (comment.contains('Nationalité:')) {
      nationalite = comment.split('Nationalité:')[1].split('|').first.trim();
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 800, padding: const EdgeInsets.all(32),
            child: StatefulBuilder(
              builder: (_, setDialogState) => SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(l10n.t('editPatient'), style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    IconButton(onPressed: () => Navigator.pop(dialogCtx), icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
                  ]),
                  const SizedBox(height: 24),
                  _sectionHeader(l10n.t('personalInfo'), Icons.person_rounded),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _field("${l10n.t('lastName')} (*)", nomCtrl, Icons.person_rounded)),
                    const SizedBox(width: 16),
                    Expanded(child: _field("${l10n.t('firstName')} (*)", prenomCtrl, Icons.person_outline_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field("${l10n.t('age')} (*)", ageCtrl, Icons.cake_rounded, inputType: TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("${l10n.t('gender')} (*)", style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        Row(children: [
                          Radio<String>(value: 'H', groupValue: sexe, onChanged: (v) => setDialogState(() => sexe = v!), activeColor: AppColors.primary),
                          Text(l10n.t('maleLabel')),
                          const SizedBox(width: 10),
                          Radio<String>(value: 'F', groupValue: sexe, onChanged: (v) => setDialogState(() => sexe = v!), activeColor: AppColors.primary),
                          Text(l10n.t('femaleLabel')),
                        ]),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _sectionHeader(l10n.t('contactIdentity'), Icons.contact_phone_rounded),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _field(l10n.t('medicalFileNumber'), dossierCtrl, Icons.folder_shared_rounded)),
                    const SizedBox(width: 16),
                    Expanded(child: _field(l10n.t('nationalId'), cinCtrl, Icons.badge_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field(l10n.t('phone'), phoneCtrl, Icons.phone_rounded, inputType: TextInputType.phone)),
                    const SizedBox(width: 16),
                    Expanded(child: _dropdownSearch("${l10n.t('nationality')} (*)", nationalite, (v) => setDialogState(() => nationalite = v))),
                  ]),
                  const SizedBox(height: 32),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(l10n.t('cancel'))),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (nomCtrl.text.trim().isEmpty || prenomCtrl.text.trim().isEmpty || ageCtrl.text.trim().isEmpty) {
                          _snack(l10n.t('allFieldsRequired'), isError: true);
                          return;
                        }
                        final fullName = "${nomCtrl.text.trim()} ${prenomCtrl.text.trim()}";
                        final pid = p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString());
                        final warnings = DuplicateGuard.patientWarnings(
                          patients,
                          fullName: fullName,
                          phone: phoneCtrl.text.trim(),
                          cin: cinCtrl.text.trim(),
                          dossier: dossierCtrl.text.trim(),
                          excludePatientId: pid,
                        );
                        if (warnings.isNotEmpty) {
                          final proceed = await showDuplicateProceedDialog(
                            dialogCtx,
                            title: l10n.t('duplicateConflict'),
                            warnings: warnings,
                            confirmLabel: l10n.t('saveAnyway'),
                          );
                          if (!proceed) return;
                        }
                        await OdooApi.updatePatient(
                          patientId: p['id'],
                          name: fullName,
                          phone: phoneCtrl.text.trim(),
                          email: '',
                          insuranceId: insuranceCtrl.text.trim(),
                          height: 0.0,
                          age: int.tryParse(ageCtrl.text.trim()) ?? 0,
                          patientCode: cinCtrl.text.trim(),
                          medicalFileNumber: dossierCtrl.text.trim(),
                          comment: "Sexe: $sexe | Nationalité: $nationalite",
                        );
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        _load();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(l10n.t('save')),
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

  Widget _field(String label, TextEditingController ctrl, IconData icon, {TextInputType inputType = TextInputType.text, String? hintText}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecond)),
    const SizedBox(height: 8),
    TextField(
      controller: ctrl, keyboardType: inputType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.dmSans(color: AppColors.textHint, fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
        filled: true, fillColor: AppColors.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  ]);

  Widget _dropdown(String label, String value, List<String> items, Function(String?) onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecond)),
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.inputFill, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged)),
    ),
  ]);

  Widget _dropdownSearch(String label, String current, Function(String) onSelected) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecond)),
      const SizedBox(height: 8),
      InkWell(
        onTap: () => _showNationalityPicker(onSelected),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: AppColors.inputFill, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.public_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(current, style: GoogleFonts.dmSans())),
            const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
          ]),
        ),
      ),
    ],
  );

  void _showNationalityPicker(Function(String) onSelected) {
    String query = "";
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final list = query.isEmpty ? nationalities : nationalities.where((n) => n.toLowerCase().contains(query.toLowerCase())).toList();
          return AlertDialog(
            title: Text(loc.t('selectNationality')),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(decoration: InputDecoration(hintText: loc.t('searchHint'), prefixIcon: const Icon(Icons.search)), onChanged: (v) => setDialogState(() => query = v)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) => ListTile(
                        title: Text(list[i]),
                        onTap: () { onSelected(list[i]); Navigator.pop(context); },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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
          const Sidebar(currentRoute: '/patients'),
          Expanded(
            child: Column(children: [
              _buildAppBar(l10n),
              Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : _buildContent(l10n, isRtl)),
            ]),
          ),
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
        BreadcrumbItem(label: l10n.t('navPatients')),
      ]),
      const Spacer(),
      Container(
        width: 300,
        height: 44,
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: TextField(
          controller: _search,
          onChanged: _filter,
          decoration: InputDecoration(hintText: l10n.t('searchPatient'), hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted), prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 10)),
        ),
      ),
      const SizedBox(width: 16),
      ElevatedButton.icon(
        onPressed: () => _showAddDialog(l10n, context.read<LanguageProvider>().isArabic),
        icon: const Icon(Icons.add, size: 20),
        label: Text(l10n.t('newPatientAction'), style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
      ),
    ]),
  );

  Widget _buildContent(AppLocalizations l10n, bool isRtl) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primary, width: 2))),
            child: Row(children: [
              Expanded(flex: 3, child: _th(l10n.t('fullName'))),
              Expanded(flex: 2, child: _th(l10n.t('nationalId'))),
              Expanded(flex: 2, child: _th(l10n.t('medicalFileNumber'))),
              Expanded(flex: 1, child: _th(l10n.t('age'))),
              Expanded(flex: 2, child: _th(l10n.t('phone'))),
              Expanded(flex: 2, child: _th(l10n.t('colActions'))),
            ]),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(l10n.t('noPatientFound')))
                : ListView.builder(
                    itemCount: _paginated.length,
                    itemBuilder: (context, index) => _buildPatientRow(_paginated[index], index, l10n, isRtl),
                  ),
          ),
          _buildPaginationControls(l10n),
        ]),
      ),
    );
  }

  Widget _buildPatientRow(Map p, int index, AppLocalizations l10n, bool isRtl) {
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: p))),
            child: Row(children: [
              CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withOpacity(0.1), child: Text(_s(p['name'])[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12))),
              const SizedBox(width: 12),
              Expanded(child: Text(_s(p['name']), style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppColors.primary))),
            ]),
          ),
        ),
        Expanded(flex: 2, child: Text(_s(p['patient_code']))),
        Expanded(flex: 2, child: Text(_s(p['medical_file_number']))),
        Expanded(flex: 1, child: Text(_s(p['age']))),
        Expanded(flex: 2, child: Text(_s(p['phone']))),
        Expanded(
          flex: 2,
          child: Row(children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary), onPressed: () => _showEditDialog(p, l10n, isRtl)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.red), onPressed: () => _confirmDelete(p)),
            IconButton(icon: const Icon(Icons.visibility, size: 20, color: AppColors.primary), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: p)))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPaginationControls(AppLocalizations l10n) => Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))), child: Row(children: [Text(l10n.t('pageOf', args: {'page': '$_currentPage', 'total': '$_totalPages'}), style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecond, fontWeight: FontWeight.w500)), const Spacer(), IconButton(icon: const Icon(Icons.chevron_left), onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null), IconButton(icon: const Icon(Icons.chevron_right), onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null)]));

  Widget _th(String text) => Text(text.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecond));
}
