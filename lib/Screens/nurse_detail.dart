import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/theme.dart';

class NurseDetailScreen extends StatefulWidget {
  final Map nurse;
  const NurseDetailScreen({super.key, required this.nurse});

  @override
  State<NurseDetailScreen> createState() => _NurseDetailScreenState();
}

class _NurseDetailScreenState extends State<NurseDetailScreen> {
  List logs = [];
  List bpMeasures = [];
  List bodyMeasures = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _s(dynamic val) => (val is String) ? val : (val == null || val == false ? '' : val.toString());

  Future<void> _loadData() async {
    setState(() => loading = true);
    final results = await Future.wait([
      OdooApi.getNurseLogs(widget.nurse['id']),
      OdooApi.getBpMeasurements(),
      OdooApi.getBodyMeasurements(),
    ]);
    if (!mounted) return;
    setState(() {
      logs = results[0];
      bpMeasures = results[1];
      bodyMeasures = results[2];
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final n = widget.nurse;
    final name = _s(n['name']).isEmpty ? loc.t('roleNurse') : _s(n['name']);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _profileCard(n, name),
                      const SizedBox(height: 20),
                      _section(loc.t('essentialInfo'), [
                        _tile(Icons.badge_rounded, loc.t('license'), _s(n['license_number'])),
                        _tile(Icons.medical_information_rounded, loc.t('specialization'), _s(n['specialization'])),
                        _tile(Icons.local_hospital_rounded, loc.t('department'), _s(n['department_id'])),
                        _tile(Icons.call_rounded, loc.t('phone'), _s(n['phone'])),
                        _tile(Icons.email_rounded, loc.t('email'), _s(n['email'])),
                        _tile(Icons.flag_rounded, loc.t('colStatus'), _s(n['state'])),
                      ]),
                    ]),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)]),
                    child: DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: AppColors.primary,
                            tabs: [
                              Tab(text: loc.t('tension')),
                              Tab(text: loc.t('weight')),
                              Tab(text: loc.t('activity')),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _bpList(loc),
                                _bodyList(loc),
                                _logsList(loc),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _profileCard(Map n, String name) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(_s(n['license_number']), style: const TextStyle(color: Colors.white70)),
            ]),
          )
        ]),
      );

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(children: children),
          ),
        ],
      );

  Widget _tile(IconData icon, String label, String value) => ListTile(
        leading: Icon(icon, size: 20, color: AppColors.primary),
        title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        subtitle: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  Widget _bpList(AppLocalizations loc) => bpMeasures.isEmpty
      ? Center(child: Text(loc.t('noMeasure')))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bpMeasures.length,
          itemBuilder: (_, i) {
            final m = bpMeasures[i] as Map;
            return _measureCard(
              icon: Icons.favorite_rounded,
              color: Colors.red,
              title: "SYS/DIA ${_s(m['systolique'])}/${_s(m['diastolique'])} - Pouls ${_s(m['pouls'])}",
              subtitle: _s(m['date_mesure']),
              l10n: loc,
            );
          },
        );

  Widget _bodyList(AppLocalizations loc) => bodyMeasures.isEmpty
      ? Center(child: Text(loc.t('noMeasure')))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bodyMeasures.length,
          itemBuilder: (_, i) {
            final m = bodyMeasures[i] as Map;
            return _measureCard(
              icon: Icons.monitor_weight_rounded,
              color: AppColors.primary,
              title: "${loc.t('weight')} ${_s(m['weight'])} kg | ${loc.t('bmi')} ${_s(m['bmi'])}",
              subtitle: _s(m['date']),
              l10n: loc,
            );
          },
        );

  Widget _logsList(AppLocalizations loc) => logs.isEmpty
      ? Center(child: Text(loc.t('noRecentActivity')))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (_, i) {
            final log = logs[i] as Map;
            final body = _s(log['body']);
            final dateStr = _s(log['date']);
            final date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;
            final formatted = date == null ? "—" : intl.DateFormat('dd/MM HH:mm').format(date);
            return _measureCard(
              icon: _getLogIcon(body),
              color: _getLogColor(body),
              title: _parseHtml(body),
              subtitle: formatted,
              actionLabel: _getTranslatedAction(body, loc),
              l10n: loc,
            );
          },
        );

  Widget _measureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required AppLocalizations l10n,
    String? actionLabel,
  }) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (actionLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(actionLabel, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ),
              Text(title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle.isEmpty ? '—' : subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ]),
          )
        ]),
      );

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
}
