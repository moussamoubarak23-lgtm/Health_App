import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/theme.dart';
import 'package:intl/intl.dart' as intl;

class SecretaryDetailScreen extends StatefulWidget {
  final Map secretary;
  const SecretaryDetailScreen({super.key, required this.secretary});

  @override
  State<SecretaryDetailScreen> createState() => _SecretaryDetailScreenState();
}

class _SecretaryDetailScreenState extends State<SecretaryDetailScreen> {
  late Map s;
  List logs = [];
  bool loadingLogs = true;

  @override
  void initState() {
    super.initState();
    s = Map.from(widget.secretary);
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => loadingLogs = true);
    final data = await OdooApi.getSecretaryLogs(s['id']);
    if (mounted) {
      setState(() {
        logs = data;
        loadingLogs = false;
      });
    }
  }

  String _s(dynamic val) => (val is String) ? val : (val == null || val == false ? '' : val.toString());

  void _showEditDialog() {
    final l10n = AppLocalizations.of(context);
    
    final firstNameCtrl = TextEditingController(text: _s(s['first_name']));
    final lastNameCtrl = TextEditingController(text: _s(s['last_name']));
    final phoneCtrl = TextEditingController(text: _s(s['phone']));
    final emailCtrl = TextEditingController(text: _s(s['email']));
    final codeCtrl = TextEditingController(text: _s(s['secretary_code']));
    final cinCtrl = TextEditingController(text: _s(s['national_id']));
    final addressCtrl = TextEditingController(text: _s(s['address']));
    final employeeIdCtrl = TextEditingController(text: _s(s['employee_id']));
    final hoursCtrl = TextEditingController(text: _s(s['working_hours']));
    
    String gender = s['gender'] is String ? s['gender'] : 'male';
    String? birthDate = s['birth_date'] is String ? s['birth_date'] : null;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.t('editSecretary'), style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const Divider(height: 32),
                
                Row(children: [
                  Expanded(child: _editField("${l10n.t('firstName')} (*)", firstNameCtrl, Icons.person_outline)),
                  const SizedBox(width: 16),
                  Expanded(child: _editField("${l10n.t('lastName')} (*)", lastNameCtrl, Icons.person_rounded)),
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
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _editField("${l10n.t('email')} (*)", emailCtrl, Icons.email_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _editField(l10n.t('phone'), phoneCtrl, Icons.phone_rounded)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _editField("${l10n.t('secretaryCode')} (*)", codeCtrl, Icons.qr_code_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _editField("${l10n.t('employeeId')} (*)", employeeIdCtrl, Icons.assignment_ind_rounded)),
                ]),
                const SizedBox(height: 16),
                _editField(l10n.t('address'), addressCtrl, Icons.location_on_rounded),
                
                const SizedBox(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(l10n.t('cancel'))),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (firstNameCtrl.text.isEmpty || lastNameCtrl.text.isEmpty || emailCtrl.text.isEmpty || 
                          employeeIdCtrl.text.isEmpty || codeCtrl.text.isEmpty || birthDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('allFieldsRequired'))));
                        return;
                      }
                      
                      final vals = {
                        'first_name': firstNameCtrl.text.trim(),
                        'last_name': lastNameCtrl.text.trim(),
                        'gender': gender,
                        'birth_date': birthDate,
                        'phone': phoneCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'secretary_code': codeCtrl.text.trim(),
                        'national_id': cinCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                        'employee_id': employeeIdCtrl.text.trim(),
                        'working_hours': hoursCtrl.text.trim(),
                      };
                      
                      final res = await OdooApi.updateSecretary(s['id'], vals);
                      if (res['success']) {
                        setState(() {
                          s.addAll(vals);
                          s['full_name'] = "${vals['first_name']} ${vals['last_name']}";
                        });
                        if (!mounted) return;
                        Navigator.pop(dialogCtx);
                        _loadLogs();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: Text(l10n.t('save')),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, IconData icon) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
    const SizedBox(height: 6),
    TextField(
      controller: ctrl,
      decoration: InputDecoration(prefixIcon: Icon(icon, size: 18), filled: true, fillColor: AppColors.inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    ),
  ]);

  Widget _datePickerField(String label, String? value, Function(String) onSelected) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
    const SizedBox(height: 6),
    InkWell(
      onTap: () async {
        final date = await showDatePicker(context: context, initialDate: value != null ? DateTime.parse(value) : DateTime.now(), firstDate: DateTime(1950), lastDate: DateTime.now());
        if (date != null) onSelected(date.toString().substring(0, 10));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.inputFill, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [const Icon(Icons.calendar_today, size: 18, color: AppColors.primary), const SizedBox(width: 12), Text(value ?? 'Sélectionner')]),
      ),
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    String fullName = _s(s['full_name']);
    if (fullName.isEmpty) {
      fullName = "${_s(s['first_name'])} ${_s(s['last_name'])}".trim();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(fullName.isEmpty ? l10n.t('roleSecretary') : fullName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _showEditDialog),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildProfileCard(s, fullName, l10n),
                const SizedBox(height: 24),
                _buildInfoSection(l10n.t('contact'), [
                  _infoTile(Icons.phone, l10n.t('phone'), _s(s['phone'])),
                  _infoTile(Icons.email, l10n.t('email'), _s(s['email'])),
                  _infoTile(Icons.location_on, l10n.t('address'), _s(s['address'])),
                ]),
                const SizedBox(height: 24),
                _buildInfoSection(l10n.t('professional'), [
                  _infoTile(Icons.qr_code, l10n.t('secretaryCode'), _s(s['secretary_code'])),
                  _infoTile(Icons.badge, l10n.t('nationalId'), _s(s['national_id'])),
                  _infoTile(Icons.work, l10n.t('workingHours'), _s(s['working_hours'])),
                ]),
              ]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(l10n.t('activityFeed'), style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: loadingLogs 
                    ? const Center(child: CircularProgressIndicator())
                    : logs.isEmpty 
                      ? _buildEmptyLogs(l10n)
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: logs.length,
                          itemBuilder: (context, index) => _buildLogItem(logs[index], l10n),
                        ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Map s, String fullName, AppLocalizations l10n) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(children: [
      CircleAvatar(
        radius: 40, backgroundColor: Colors.white.withOpacity(0.2),
        child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S', style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 20),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(fullName.isEmpty ? '—' : fullName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
          child: Text(_s(s['employee_id']), style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ])),
    ]),
  );

  Widget _buildInfoSection(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(children: children),
      ),
    ],
  );

  Widget _infoTile(IconData icon, String label, String value) => ListTile(
    leading: Icon(icon, size: 20, color: AppColors.primary),
    title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
    subtitle: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
  );

  Widget _buildLogItem(Map log, AppLocalizations l10n) {
    final dateStr = _s(log['date']);
    final date = dateStr.isNotEmpty ? DateTime.parse(dateStr) : DateTime.now();
    final formattedDate = intl.DateFormat('dd/MM HH:mm').format(date);
    final body = _s(log['body']);
    final cleanBody = _parseHtml(body);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _getLogColor(body).withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(_getLogIcon(body), size: 18, color: _getLogColor(body)),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_getTranslatedAction(body, l10n), style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: _getLogColor(body))),
              Text(formattedDate, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(cleanBody, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ])),
      ]),
    );
  }

  String _parseHtml(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  IconData _getLogIcon(String body) {
    String b = body.toLowerCase();
    if (b.contains('créat') || b.contains('creat')) return Icons.add_circle_outline;
    if (b.contains('modif') || b.contains('updat')) return Icons.edit_note;
    if (b.contains('suppr') || b.contains('delet')) return Icons.delete_forever;
    if (b.contains('facture') || b.contains('invoice')) return Icons.receipt_long;
    return Icons.info_outline;
  }

  Color _getLogColor(String body) {
    String b = body.toLowerCase();
    if (b.contains('créat') || b.contains('creat')) return AppColors.green;
    if (b.contains('suppr') || b.contains('delet')) return AppColors.red;
    if (b.contains('facture') || b.contains('invoice')) return AppColors.primary;
    if (b.contains('modif') || b.contains('updat')) return AppColors.yellow;
    return AppColors.textMuted;
  }

  String _getTranslatedAction(String body, AppLocalizations l10n) {
    String b = body.toLowerCase();
    if (b.contains('créat') || b.contains('creat')) return l10n.t('logCreation');
    if (b.contains('modif') || b.contains('updat')) return l10n.t('logModification');
    if (b.contains('suppr') || b.contains('delet')) return l10n.t('logDeletion');
    if (b.contains('facture') || b.contains('invoice')) return l10n.t('logInvoice');
    return l10n.t('logUnknown');
  }

  Widget _buildEmptyLogs(AppLocalizations l10n) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.3)),
      const SizedBox(height: 16),
      Text(l10n.t('noRecentActivity'), style: const TextStyle(color: AppColors.textMuted)),
    ]),
  );
}
