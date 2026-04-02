import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';

enum PatientTab { consultations, vaccination, actes, ordonnances, bilanBio, bilanRx, certificats, compteRendu, comptabilite, factures }

class PatientDetailScreen extends StatefulWidget {
  final Map patient;
  const PatientDetailScreen({super.key, required this.patient});
  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  PatientTab _activeTab = PatientTab.consultations;
  List records = [];
  List bpMeasurements = [];
  List availableActs = [];
  List selectedActs = [];
  bool loading = true;
  late Map currentPatient;

  @override
  void initState() {
    super.initState();
    currentPatient = Map.from(widget.patient);
    _loadData();
  }

  String _s(dynamic val) => (val is String && val != "false") ? val : '';

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => loading = true);
    final res = await Future.wait([
      OdooApi.getMedicalRecords(patientId: currentPatient['id']),
      OdooApi.getBpMeasurements(patientId: currentPatient['id']),
      OdooApi.getMedicalActs(),
    ]);
    if (mounted) {
      setState(() {
        records = res[0];
        bpMeasurements = res[1];
        availableActs = res[2];
        loading = false;
      });
    }
  }

  // --- MODIFICATION FICHE PATIENT (CIN + N° DOSSIER) ---
  void _showPatientEditDialog(AppLocalizations loc) {
    final nameCtrl = TextEditingController(text: _s(currentPatient['name']));
    final phoneCtrl = TextEditingController(text: _s(currentPatient['phone']));
    final ageCtrl = TextEditingController(text: currentPatient['age']?.toString() ?? '');
    final cinCtrl = TextEditingController(text: _s(currentPatient['patient_code']));
    final dossierCtrl = TextEditingController(text: _s(currentPatient['medical_file_number']));
    String couverture = _s(currentPatient['insurance_id']).isEmpty ? "Sans" : _s(currentPatient['insurance_id']);
    if (!["Sans", "AMO", "RAMED", "CNOPS", "Privé"].contains(couverture)) couverture = "Sans";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Modifier la Fiche Patient", style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const Divider(height: 32),
                _editField("Nom Complet (*)", nameCtrl, Icons.person_rounded),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _editField("Numéro de Dossier", dossierCtrl, Icons.folder_shared_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _editField("CIN (Carte Nationale)", cinCtrl, Icons.badge_rounded)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _editField("Téléphone", phoneCtrl, Icons.phone_rounded, inputType: TextInputType.phone)),
                  const SizedBox(width: 16),
                  Expanded(child: _editField("Âge", ageCtrl, Icons.cake_rounded, inputType: TextInputType.number)),
                ]),
                const SizedBox(height: 16),
                _editDropdown("Couverture sociale", couverture, ["Sans", "AMO", "RAMED", "CNOPS", "Privé"], (v) => setDialogState(() => couverture = v!)),
                const SizedBox(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty) return;
                      final res = await OdooApi.updatePatient(
                        patientId: currentPatient['id'],
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        email: '',
                        insuranceId: couverture,
                        height: currentPatient['height'] is num ? (currentPatient['height'] as num).toDouble() : 0.0,
                        age: int.tryParse(ageCtrl.text.trim()) ?? 0,
                        patientCode: cinCtrl.text.trim(),
                        medicalFileNumber: dossierCtrl.text.trim(),
                      );
                      if (res['success']) {
                        setState(() {
                          currentPatient['name'] = nameCtrl.text.trim();
                          currentPatient['phone'] = phoneCtrl.text.trim();
                          currentPatient['age'] = int.tryParse(ageCtrl.text.trim()) ?? 0;
                          currentPatient['insurance_id'] = couverture;
                          currentPatient['patient_code'] = cinCtrl.text.trim();
                          currentPatient['medical_file_number'] = dossierCtrl.text.trim();
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Modifications enregistrées")));
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

  Widget _editField(String label, TextEditingController ctrl, IconData icon, {TextInputType inputType = TextInputType.text}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
    const SizedBox(height: 6),
    TextField(
      controller: ctrl, keyboardType: inputType,
      decoration: InputDecoration(prefixIcon: Icon(icon, size: 18), filled: true, fillColor: AppColors.inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    ),
  ]);

  Widget _editDropdown(String label, String value, List<String> items, Function(String?) onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
    const SizedBox(height: 6),
    Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: AppColors.inputFill, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged))),
  ]);

  void _viewRecordDetails(Map record, AppLocalizations loc) {
    String dossier = _s(record['medical_file_number']);
    if (dossier.isEmpty) dossier = _s(currentPatient['medical_file_number']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [const Icon(Icons.description_outlined, color: AppColors.primary), const SizedBox(width: 10), Text("Détails Consultation", style: GoogleFonts.dmSans(fontWeight: FontWeight.bold))]),
        content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_detailItem("N° Dossier", dossier), _detailItem("Date", _s(record['date_consultation'])), _detailItem("Motif", _s(record['motif'])), const Divider(), _detailItem("Diagnostic", _s(record['diagnostic'])), _detailItem("Prescription", _s(record['prescription'])), _detailItem("Observations", _s(record['observations']))]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer"))],
      ),
    );
  }

  Widget _detailItem(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMuted)), const SizedBox(height: 4), Text(value.isEmpty ? "—" : value, style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textPrimary))]));

  Future<void> _createInvoiceFromActs(Map record) async {
    if (selectedActs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner au moins un acte'))); return; }
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    final lines = selectedActs.map((act) => {'product_id': act['id'], 'name': act['name'], 'price': act['list_price']}).toList();
    final result = await OdooApi.createInvoice(patientId: currentPatient['id'], lines: lines);
    
    if (result['success']) {
      final selectedActNames = selectedActs.map((act) => act['name']).join(', ');
      await OdooApi.updateMedicalRecord(
        recordId: record['id'],
        motif: selectedActNames,
        diagnostic: _s(record['diagnostic']),
        prescription: _s(record['prescription']),
        observations: _s(record['observations']),
        state: 'invoiced',
        medicalFileNumber: _s(record['medical_file_number']),
      );
      setState(() => selectedActs = []);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('invoiceCreated'))));
      _loadData();
    }
    if (mounted) Navigator.pop(context);
  }

  void _showActSelectionDialog(Map record, AppLocalizations loc) {
    setState(() => selectedActs = []);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Facturer la consultation", style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Sélectionnez les actes effectués :", style: GoogleFonts.dmSans(fontSize: 14)),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableActs.length,
                    itemBuilder: (context, index) {
                      final act = availableActs[index];
                      final isSelected = selectedActs.contains(act);
                      return CheckboxListTile(
                        title: Text(act['name']),
                        subtitle: Text("${act['list_price']} DH"),
                        value: isSelected,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) selectedActs.add(act);
                            else selectedActs.remove(act);
                          });
                        },
                        activeColor: AppColors.primary,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _createInvoiceFromActs(record);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text(loc.t('createInvoice')),
            )
          ],
        ),
      ),
    );
  }

  void _showQuickEditRecord(Map record, AppLocalizations loc) {
    String initialDossier = _s(record['medical_file_number']);
    if (initialDossier.isEmpty) initialDossier = _s(currentPatient['medical_file_number']);

    final fileNumCtrl = TextEditingController(text: initialDossier);
    final diagCtrl = TextEditingController(text: _s(record['diagnostic']));
    final presCtrl = TextEditingController(text: _s(record['prescription']));
    final obsCtrl = TextEditingController(text: _s(record['observations']));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Valider la Consultation", style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: fileNumCtrl, decoration: const InputDecoration(labelText: "N° Dossier Consultation")), TextField(controller: diagCtrl, decoration: InputDecoration(labelText: loc.t('diagnosticLabel'))), TextField(controller: presCtrl, decoration: InputDecoration(labelText: loc.t('prescription')), maxLines: 2), TextField(controller: obsCtrl, decoration: InputDecoration(labelText: loc.t('observations')), maxLines: 2)])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))), ElevatedButton(onPressed: () async {
          final newDossier = fileNumCtrl.text.trim();
          final res = await OdooApi.updateMedicalRecord(recordId: record['id'], motif: _s(record['motif']), diagnostic: diagCtrl.text, prescription: presCtrl.text, observations: obsCtrl.text, state: 'confirmed', medicalFileNumber: newDossier);
          
          if (newDossier.isNotEmpty && newDossier != _s(currentPatient['medical_file_number'])) {
            await OdooApi.updatePatient(
              patientId: currentPatient['id'],
              name: _s(currentPatient['name']),
              phone: _s(currentPatient['phone']),
              email: '',
              insuranceId: _s(currentPatient['insurance_id']),
              height: currentPatient['height'] is num ? (currentPatient['height'] as num).toDouble() : 0.0,
              age: currentPatient['age'] is int ? currentPatient['age'] : 0,
              patientCode: _s(currentPatient['patient_code']),
              medicalFileNumber: newDossier,
            );
            setState(() {
              currentPatient['medical_file_number'] = newDossier;
            });
          }

          if (mounted) Navigator.pop(context);
          if (res['success']) _loadData();
        }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: const Text("Valider et Confirmer"))],
      ),
    );
  }

  void _showQuickActions(AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: Text(loc.t('quickActions'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18))),
          ListTile(leading: const Icon(Icons.receipt_long, color: AppColors.primary), title: Text(loc.t('newInvoice')), onTap: () { Navigator.pop(context); setState(() => _activeTab = PatientTab.actes); }),
          ListTile(leading: const Icon(Icons.calendar_today, color: AppColors.green), title: const Text('Planifier un rendez-vous'), onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bientôt disponible'))); }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRtl = lang.isArabic;
    final loc = AppLocalizations.of(context);
    final p = currentPatient;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(children: [
          const Sidebar(currentRoute: '/patients'),
          Expanded(
            child: Column(children: [
              _topBar(p, loc),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: _mainContent(loc)),
                    const SizedBox(width: 16),
                    GestureDetector(onTap: () => _showPatientEditDialog(loc), child: _rightSidebar(p, loc)),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _topBar(Map p, AppLocalizations loc) => Container(
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
    child: Row(children: [IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)), Text('${loc.t('navPatients')} / ${_s(p['name'])}', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)), const Spacer(), IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)]),
  );

  Widget _mainContent(AppLocalizations loc) => Column(children: [
    Row(children: [_actionBtn('+ ${loc.t('newConsultation')}', AppColors.primary, () => Navigator.pushNamed(context, '/add_record', arguments: currentPatient)), const SizedBox(width: 10), _actionBtn('⚡ ${loc.t('quickActions')}', AppColors.primaryLight, () => _showQuickActions(loc), isSecondary: true)]),
    const SizedBox(height: 16),
    _tabBar(loc),
    const SizedBox(height: 16),
    Expanded(child: _tabView(loc)),
  ]);

  Widget _actionBtn(String label, Color color, VoidCallback onTap, {bool isSecondary = false}) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: isSecondary ? AppColors.primary : Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: isSecondary ? const BorderSide(color: AppColors.border) : BorderSide.none), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    child: Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13)),
  );

  Widget _tabBar(AppLocalizations loc) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: PatientTab.values.map((t) {
      final active = _activeTab == t;
      return GestureDetector(onTap: () => setState(() => _activeTab = t), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: active ? AppColors.green : AppColors.surface, borderRadius: BorderRadius.circular(8)), child: Text(_getTranslatedTab(t, loc), style: GoogleFonts.dmSans(color: active ? Colors.white : AppColors.textSecond, fontSize: 12, fontWeight: FontWeight.bold))));
    }).toList()),
  );

  Widget _tabView(AppLocalizations loc) {
    if (_activeTab == PatientTab.consultations) { return Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Column(children: [_tableHeader(loc), Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : _consultationList(loc))])); }
    else if (_activeTab == PatientTab.actes) { return _actesTabView(loc); }
    return Center(child: Text(loc.t('loading')));
  }

  Widget _actesTabView(AppLocalizations loc) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Sélection des actes médicaux", style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16)), if (selectedActs.isNotEmpty) _actionBtn(loc.t('createInvoice'), AppColors.primary, () => _createInvoiceFromActs({}))]), const Divider(), Expanded(child: ListView.builder(itemCount: availableActs.length, itemBuilder: (context, index) { final act = availableActs[index]; final isSelected = selectedActs.contains(act); return CheckboxListTile(title: Text(act['name']), subtitle: Text("${act['list_price']} DH"), value: isSelected, onChanged: (val) { setState(() { if (val == true) selectedActs.add(act); else selectedActs.remove(act); }); }, activeColor: AppColors.primary); }))]));
  }

  Widget _tableHeader(AppLocalizations loc) => Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.textPrimary, width: 2))), child: Row(children: [Expanded(flex: 2, child: _th("N° DOSSIER CONS.")), Expanded(flex: 2, child: _th(loc.t('colDate').toUpperCase())), Expanded(flex: 4, child: _th(loc.t('reason').toUpperCase())), Expanded(flex: 3, child: _th(loc.t('colStatus').toUpperCase()))]));

  Widget _consultationList(AppLocalizations loc) => ListView.builder(
    itemCount: records.length,
    itemBuilder: (_, i) {
      final r = records[i];
      String dossier = _s(r['medical_file_number']);
      if (dossier.isEmpty) dossier = _s(currentPatient['medical_file_number']);

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Row(children: [
          Expanded(flex: 2, child: Text(dossier.isEmpty ? "—" : dossier, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text(_s(r['date_consultation']).substring(0, _s(r['date_consultation']).length >= 10 ? 10 : 0))),
          Expanded(flex: 4, child: Text(_s(r['motif']), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 3, child: Row(children: [
            _statusBadge(r['state'], loc),
            const SizedBox(width: 8),
            Tooltip(message: "Détails", child: InkWell(onTap: () => _viewRecordDetails(r, loc), child: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 22))),
            if (r['state'] == 'confirmed') ...[
              const SizedBox(width: 8),
              Tooltip(message: "Facturer", child: InkWell(onTap: () => _showActSelectionDialog(r, loc), child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 22))),
            ],
            if (r['state'] == 'waiting') ...[
              const SizedBox(width: 8),
              Tooltip(message: "Valider", child: InkWell(onTap: () => _showQuickEditRecord(r, loc), child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24))),
            ]
          ])),
        ]),
      );
    },
  );

  String _getTranslatedState(String? state, AppLocalizations loc) {
    switch (state) {
      case 'draft': return loc.t('statusDraft');
      case 'confirmed': return loc.t('statusConfirmed');
      case 'waiting': return loc.t('statusWaiting');
      case 'invoiced': return loc.t('statusInvoiced');
      default: return state ?? loc.t('statusDraft');
    }
  }

  Widget _rightSidebar(Map p, AppLocalizations loc) => Container(
    width: 280,
    decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [_patientInfoCard(p, loc), const SizedBox(height: 16), _measuresCard(loc)]),
  );

  Widget _patientInfoCard(Map p, AppLocalizations loc) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(_s(p['name']), style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16))), const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 18)]),
      const SizedBox(height: 12),
      _infoChip(Icons.folder_shared_rounded, "Dossier: ${_s(p['medical_file_number'])}"),
      _infoChip(Icons.badge_rounded, "CIN: ${_s(p['patient_code'])}"),
      _infoChip(Icons.cake_rounded, '${p['age'] ?? 0} ans'),
      _infoChip(Icons.phone_rounded, _s(p['phone'])),
    ]),
  );

  Widget _th(String text) => Text(text, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecond));
  String _getTranslatedTab(PatientTab tab, AppLocalizations loc) {
    switch (tab) {
      case PatientTab.consultations: return loc.t('navRecords').toUpperCase();
      case PatientTab.factures: return loc.t('statusInvoiced').toUpperCase();
      default: return tab.name.toUpperCase();
    }
  }
  Widget _infoChip(IconData icon, String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Icon(icon, color: AppColors.primary, size: 14), const SizedBox(width: 8), Expanded(child: Text(text.contains(": ") && text.split(": ")[1].isEmpty ? "${text.split(": ")[0]}: —" : text, style: GoogleFonts.dmSans(color: AppColors.textSecond, fontSize: 12, fontWeight: FontWeight.w500)))]));
  Widget _measuresCard(AppLocalizations loc) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.monitor_heart_rounded, size: 18, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text(loc.t('recentMeasures'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)))]), const Divider(), if (bpMeasurements.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(loc.t('noMeasure'), style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted))) else ...bpMeasurements.take(2).map((m) => _bpMeasureItem(m, loc))]));
  Widget _statusBadge(String? state, AppLocalizations loc) { Color color; Color bgColor; switch (state) { case 'draft': color = AppColors.textMuted; bgColor = AppColors.textMuted.withOpacity(0.1); break; case 'waiting': color = AppColors.yellow; bgColor = AppColors.yellowLight; break; case 'confirmed': color = AppColors.green; bgColor = AppColors.greenLight; break; case 'invoiced': color = AppColors.primary; bgColor = AppColors.primaryLight; break; default: color = AppColors.textMuted; bgColor = AppColors.textMuted.withOpacity(0.1); } return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.25))), child: Text(_getTranslatedState(state, loc), style: GoogleFonts.dmSans(color: color, fontSize: 10, fontWeight: FontWeight.w700))); }
  Widget _bpMeasureItem(Map m, AppLocalizations loc) { final sys = (m['systolique'] as num).toDouble(); final dia = (m['diastolique'] as num).toDouble(); final date = _s(m['date_mesure']).substring(0, 10); return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(date, style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11)), const SizedBox(height: 4), Wrap(spacing: 10, children: [_bpValue('SYS', sys.toStringAsFixed(0), 'mmHg', sys <= 120 ? AppColors.green : AppColors.red), _bpValue('DIA', dia.toStringAsFixed(0), 'mmHg', dia <= 80 ? AppColors.green : AppColors.red)])])); }
  Widget _bpValue(String label, String val, String unit, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [Text('$label: ', style: GoogleFonts.dmSans(color: AppColors.textSecond, fontSize: 11)), Text(val, style: GoogleFonts.dmSans(color: color, fontSize: 11, fontWeight: FontWeight.w700))]);
}
