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
  List logs = [];
  bool loadingLogs = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => loadingLogs = true);
    final data = await OdooApi.getSecretaryLogs(widget.secretary['id']);
    if (mounted) {
      setState(() {
        logs = data;
        loadingLogs = false;
      });
    }
  }

  String _s(dynamic val) => (val is String) ? val : (val == null || val == false ? '' : val.toString());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = widget.secretary;
    
    // Protection contre les valeurs booléennes renvoyées par Odoo
    String fullName = _s(s['full_name']);
    if (fullName.isEmpty) {
      fullName = "${_s(s['first_name'])} ${_s(s['last_name'])}".trim();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(fullName.isEmpty ? 'Détail Secrétaire' : fullName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: Row(
        children: [
          // ─── COLONNE GAUCHE : INFOS ────────────────────────────────────────
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildProfileCard(s, fullName, l10n),
                const SizedBox(height: 24),
                _buildInfoSection("Contact", [
                  _infoTile(Icons.phone, l10n.t('phone'), _s(s['phone'])),
                  _infoTile(Icons.email, l10n.t('email'), _s(s['email'])),
                  _infoTile(Icons.location_on, l10n.t('address'), _s(s['address'])),
                ]),
                const SizedBox(height: 24),
                _buildInfoSection("Professionnel", [
                  _infoTile(Icons.qr_code, l10n.t('secretaryCode'), _s(s['secretary_code'])),
                  _infoTile(Icons.badge, l10n.t('nationalId'), _s(s['national_id'])),
                  _infoTile(Icons.work, l10n.t('workingHours'), _s(s['working_hours'])),
                ]),
              ]),
            ),
          ),

          // ─── COLONNE DROITE : NOTIFICATIONS / LOGS ──────────────────────────
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
                    Text("Fil d'actualité des actions", style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: loadingLogs 
                    ? const Center(child: CircularProgressIndicator())
                    : logs.isEmpty 
                      ? _buildEmptyLogs()
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: logs.length,
                          itemBuilder: (context, index) => _buildLogItem(logs[index]),
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

  Widget _buildLogItem(Map log) {
    final dateStr = _s(log['date']);
    final date = dateStr.isNotEmpty ? DateTime.parse(dateStr) : DateTime.now();
    final formattedDate = intl.DateFormat('dd/MM HH:mm').format(date);
    final body = _s(log['body']);
    
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
          Text(_parseHtml(body), style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(formattedDate, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ])),
      ]),
    );
  }

  String _parseHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  IconData _getLogIcon(String body) {
    String b = body.toLowerCase();
    if (b.contains('création') || b.contains('created')) return Icons.add_circle_outline;
    if (b.contains('modification') || b.contains('updated')) return Icons.edit_note;
    if (b.contains('suppression') || b.contains('deleted')) return Icons.delete_forever;
    if (b.contains('facture') || b.contains('invoice')) return Icons.receipt_long;
    return Icons.info_outline;
  }

  Color _getLogColor(String body) {
    String b = body.toLowerCase();
    if (b.contains('création') || b.contains('created')) return AppColors.green;
    if (b.contains('suppression') || b.contains('deleted')) return AppColors.red;
    if (b.contains('facture') || b.contains('invoice')) return AppColors.primary;
    return AppColors.textMuted;
  }

  Widget _buildEmptyLogs() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.3)),
      const SizedBox(height: 16),
      const Text("Aucune activité récente enregistrée", style: TextStyle(color: AppColors.textMuted)),
    ]),
  );
}
