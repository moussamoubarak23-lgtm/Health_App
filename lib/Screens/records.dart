import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';
import 'package:medical_app/Widgets/app_breadcrumb.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List records = [];
  List allRecords = [];
  bool loading = true;
  Map? patient;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Map) patient = arg;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final r = await OdooApi.getMedicalRecords(patientId: patient?['id']);
    if (!mounted) return;
    allRecords = List.from(r);
    _applyFilters();
  }

  void _applyFilters() {
    final filtered = allRecords.where((record) {
      final patientName = record['patient_id'] is List ? record['patient_id'][1].toString() : '';
      final fileNum = record['medical_file_number']?.toString() ?? '';
      final haystack = '$patientName $fileNum ${record['motif'] ?? ''} ${record['diagnostic'] ?? ''} ${record['prescription'] ?? ''}'.toLowerCase();
      final matchesQuery = _searchQuery.isEmpty || haystack.contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == 'all' || (record['state']?.toString() ?? 'draft') == _statusFilter;
      return matchesQuery && matchesStatus;
    }).toList();

    setState(() {
      records = filtered;
      loading = false;
    });
  }

  int _countByState(String state) =>
      allRecords.where((r) => (r['state']?.toString() ?? 'draft') == state).length;

  String _stateLabel(String? s, AppLocalizations l10n) {
    switch (s) {
      case 'confirmed': return l10n.t('statusConfirmed');
      case 'invoiced':  return l10n.t('statusInvoiced');
      default:          return l10n.t('statusDraft');
    }
  }

  Color _stateColor(String? s) {
    switch (s) {
      case 'confirmed': return AppColors.green;
      case 'invoiced':  return AppColors.primary;
      default:          return AppColors.yellow;
    }
  }

  Color _stateBg(String? s) {
    switch (s) {
      case 'confirmed': return AppColors.greenLight;
      case 'invoiced':  return AppColors.primaryLight;
      default:          return AppColors.yellowLight;
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white)),
      backgroundColor: isError ? AppColors.red : AppColors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showEditDialog(Map r, AppLocalizations l10n, bool isRtl) {
    final fileNumCtrl      = TextEditingController(text: (r['medical_file_number'] is String && r['medical_file_number'] != "false") ? r['medical_file_number'] : '');
    final motifCtrl        = TextEditingController(text: r['motif']?.toString() ?? '');
    final diagnosticCtrl   = TextEditingController(text: r['diagnostic']?.toString() ?? '');
    final prescriptionCtrl = TextEditingController(text: r['prescription']?.toString() ?? '');
    final observationsCtrl = TextEditingController(text: r['observations']?.toString() ?? '');

    final allowedStates = ['draft', 'confirmed', 'invoiced'];
    final rawState = r['state'];
    String selState = (rawState is String && allowedStates.contains(rawState)) ? rawState : 'draft';

    final statusOpts = [
      {'value': 'draft',     'label': l10n.t('statusDraft')},
      {'value': 'confirmed', 'label': l10n.t('statusConfirmed')},
      {'value': 'invoiced',  'label': l10n.t('statusInvoiced')},
    ];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 600, padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(l10n.t('editRecord'), style: _titleSm(isRtl)),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(r['name']?.toString() ?? '',
                      style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 18),

                  _dlgField(l10n.t('medicalFileNumber'), fileNumCtrl, Icons.folder_shared_rounded, isRtl),
                  const SizedBox(height: 12),

                  Text(l10n.t('status'), style: _labelStyle(isRtl)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selState,
                    dropdownColor: AppColors.surface,
                    style: isRtl
                        ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 14)
                        : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true, fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: statusOpts.map((s) => DropdownMenuItem(
                      value: s['value'],
                      child: Row(children: [
                        Container(width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: s['value'] == 'draft' ? AppColors.yellow
                                : s['value'] == 'confirmed' ? AppColors.green : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(s['label']!, style: isRtl
                            ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 14)
                            : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14)),
                      ]),
                    )).toList(),
                    onChanged: (v) => setD(() => selState = v ?? 'draft'),
                  ),
                  const SizedBox(height: 14),

                  _dlgField(l10n.t('reason'),       motifCtrl,        Icons.info_rounded,                isRtl, maxLines: 2),
                  const SizedBox(height: 12),
                  _dlgField(l10n.t('diagnostic'),   diagnosticCtrl,   Icons.medical_information_rounded, isRtl, maxLines: 3),
                  const SizedBox(height: 12),
                  _dlgField(l10n.t('prescription'), prescriptionCtrl, Icons.medication_rounded,          isRtl, maxLines: 3),
                  const SizedBox(height: 12),
                  _dlgField(l10n.t('observations'), observationsCtrl, Icons.notes_rounded,               isRtl, maxLines: 3),
                  const SizedBox(height: 24),

                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(l10n.t('cancel'), style: _btnTxt(isRtl)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await OdooApi.updateMedicalRecord(
                          recordId: r['id'],
                          motif: motifCtrl.text.trim(),
                          diagnostic: diagnosticCtrl.text.trim(),
                          prescription: prescriptionCtrl.text.trim(),
                          observations: observationsCtrl.text.trim(),
                          state: selState,
                          medicalFileNumber: fileNumCtrl.text.trim(),
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _snack(result['success'] == true
                              ? l10n.t('recordUpdated')
                              : (result['error'] ?? l10n.t('error')),
                              isError: result['success'] != true);
                          if (result['success'] == true) _load();
                        }
                      },
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: Text(l10n.t('save'), style: _btnTxt(isRtl, white: true)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                      ),
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

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final lang  = context.watch<LanguageProvider>();
    final isRtl = lang.isArabic;

    final title = patient != null
        ? '${l10n.t('navRecords')} — ${patient!['name']}'
        : l10n.t('recordsTitle');

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(children: [
          const Sidebar(currentRoute: '/records'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: _titleLg(isRtl)),
                    Text('${records.length} ${l10n.t('recordsCount')}',
                        style: _mutedStyle(isRtl)),
                  ]),
                  Row(children: [
                    IconButton.filled(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                          context, '/add_record', arguments: patient),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(l10n.t('newRecord'),
                          style: isRtl
                              ? GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 13)
                              : GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ]),
                ]),
                const SizedBox(height: 12),
                AppBreadcrumb(
                  items: [
                    BreadcrumbItem(label: l10n.t('home'), route: '/dashboard'),
                    BreadcrumbItem(label: patient != null ? '${l10n.t('recordsLabel')} · ${patient!['name']}' : l10n.t('recordsLabel')),
                  ],
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (value) {
                        _searchQuery = value;
                        _applyFilters();
                      },
                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                      style: isRtl
                          ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 14)
                          : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: l10n.t('searchRecord'),
                        hintStyle: isRtl
                            ? GoogleFonts.cairo(color: AppColors.textHint)
                            : GoogleFonts.dmSans(color: AppColors.textHint),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip('all', l10n.t('allStatuses'), allRecords.length, AppColors.textSecond, isRtl),
                        _filterChip('draft', l10n.t('statusDraft'), _countByState('draft'), AppColors.yellow, isRtl),
                        _filterChip('confirmed', l10n.t('statusConfirmed'), _countByState('confirmed'), AppColors.green, isRtl),
                        _filterChip('invoiced', l10n.t('statusInvoiced'), _countByState('invoiced'), AppColors.primary, isRtl),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${records.length} ${l10n.t('filteredResults')}', style: _mutedStyle(isRtl, size: 12)),
                  ]),
                ),
                const SizedBox(height: 18),

                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                      : records.isEmpty
                          ? Center(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.folder_off_rounded, size: 56, color: AppColors.textHint),
                            const SizedBox(height: 16),
                            Text(l10n.t('noRecordFound'), style: _mutedStyle(isRtl, size: 16)),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                  context, '/add_record', arguments: patient),
                              icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                              label: Text(l10n.t('createFirst'),
                                  style: isRtl
                                      ? GoogleFonts.cairo(color: AppColors.primary, fontWeight: FontWeight.w600)
                                      : GoogleFonts.dmSans(color: AppColors.primary, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ]))
                          : ListView.separated(
                              itemCount: records.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (_, i) => _recordCard(records[i], l10n, isRtl),
                            ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── CARD DOSSIER ─────────────────────────────────────────────────────────────
  Widget _recordCard(Map r, AppLocalizations l10n, bool isRtl) {
    final state  = r['state']?.toString();
    final sColor = _stateColor(state);
    final sBg    = _stateBg(state);
    final dossier = r['medical_file_number']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: AppColors.purpleLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.folder_special_rounded, color: AppColors.purple, size: 18),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['patient_id'] is List ? r['patient_id'][1].toString() : l10n.t('colPatient'),
                  style: isRtl
                      ? GoogleFonts.cairo(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)
                      : GoogleFonts.dmSans(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              Text(r['name']?.toString() ?? '',
                  style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11)),
            ]),
          ]),

          Row(children: [
            if (dossier.isNotEmpty && dossier != "false") ...[
               Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Text("${l10n.t('medicalFileNumber').toUpperCase()}: $dossier", style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 10),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sColor.withValues(alpha: 0.3))),
              child: Text(_stateLabel(state, l10n),
                  style: isRtl
                      ? GoogleFonts.cairo(color: sColor, fontSize: 11, fontWeight: FontWeight.w700)
                      : GoogleFonts.dmSans(color: sColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.2))),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.green),
                const SizedBox(width: 5),
                Text(r['date_consultation']?.toString().substring(0, 10) ?? '',
                    style: GoogleFonts.dmSans(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _showEditDialog(r, l10n, isRtl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.edit_rounded, size: 12, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text(l10n.t('edit'), style: isRtl
                      ? GoogleFonts.cairo(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)
                      : GoogleFonts.dmSans(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ]),

        const SizedBox(height: 16),
        Divider(color: AppColors.divider),
        const SizedBox(height: 12),

        if (r['motif'] != false && r['motif'] != null)
          _field(l10n.t('reason'),       r['motif'],       AppColors.yellow, AppColors.yellowLight, Icons.info_rounded, isRtl),
        const SizedBox(height: 10),
        _field(l10n.t('diagnostic'),     r['diagnostic'],  AppColors.primary, AppColors.primaryLight, Icons.medical_information_rounded, isRtl),
        const SizedBox(height: 10),
        _field(l10n.t('prescription'),   r['prescription'], AppColors.purple, AppColors.purpleLight, Icons.medication_rounded, isRtl),
        if (r['observations'] != false && r['observations'] != null &&
            r['observations'].toString().isNotEmpty) ...[
          const SizedBox(height: 10),
          _field(l10n.t('observations'), r['observations'], AppColors.red, AppColors.redLight, Icons.notes_rounded, isRtl),
        ],
      ]),
    );
  }

  // ── WIDGETS HELPERS ──────────────────────────────────────────────────────────
  Widget _filterChip(String value, String label, int count, Color color, bool isRtl) {
    final active = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        _statusFilter = value;
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color.withValues(alpha: 0.3) : AppColors.border),
        ),
        child: Text('$label ($count)', style: isRtl
            ? GoogleFonts.cairo(color: active ? color : AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w700)
            : GoogleFonts.dmSans(color: active ? color : AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _field(String label, dynamic value, Color color, Color bg, IconData icon, bool isRtl) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: isRtl
              ? GoogleFonts.cairo(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)
              : GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value?.toString() ?? '—', style: isRtl
              ? GoogleFonts.cairo(color: AppColors.textSecond, fontSize: 13)
              : GoogleFonts.dmSans(color: AppColors.textSecond, fontSize: 13)),
        ])),
      ]);

  Widget _dlgField(String label, TextEditingController ctrl, IconData icon,
      bool isRtl, {int maxLines = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: _labelStyle(isRtl)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl, maxLines: maxLines,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: isRtl
              ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 13)
              : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary, size: 16),
            filled: true, fillColor: AppColors.inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ]);

  TextStyle _titleLg(bool r) => r
      ? GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)
      : GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary);

  TextStyle _titleSm(bool r) => r
      ? GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
      : GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary);

  TextStyle _mutedStyle(bool r, {double size = 14}) => r
      ? GoogleFonts.cairo(fontSize: size, color: AppColors.textMuted)
      : GoogleFonts.dmSans(fontSize: size, color: AppColors.textMuted);

  TextStyle _labelStyle(bool r) => r
      ? GoogleFonts.cairo(color: AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w600)
      : GoogleFonts.dmSans(color: AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w600);

  TextStyle _btnTxt(bool r, {bool white = false}) => r
      ? GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600,
          color: white ? Colors.white : AppColors.textSecond)
      : GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
          color: white ? Colors.white : AppColors.textSecond);
}
