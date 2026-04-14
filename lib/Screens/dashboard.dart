import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:medical_app/Widgets/app_breadcrumb.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  Map<String, int> stats = {};
  List recentRecords = [];
  List waitingList = [];
  bool loading = true;
  String doctorName = '';
  int draftCount = 0;
  int waitingCount = 0;
  int confirmedCount = 0;
  int todayCount = 0;
  List appNotifications = [];
  List<int> readNotifIds = []; // IDs des notifications déjà lues localement
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      doctorName = prefs.getString('doctor_name') ?? 'Médecin';
      // Charger la liste des IDs lus depuis les préférences
      readNotifIds = (prefs.getStringList('read_notifications') ?? []).map(int.parse).toList();
    });

    final results = await Future.wait([
      OdooApi.getDashboardStats(),
      OdooApi.getMedicalRecords(),
      OdooApi.getPatients(),
      OdooApi.getWaitingRoom(),
      OdooApi.getAppNotifications(),
    ]);

    final allRecords = results[1] as List;
    final todayKey = _dateKey(DateTime.now());

    setState(() {
      stats = results[0] as Map<String, int>;
      recentRecords = allRecords.take(6).toList();
      waitingList = results[3] as List;
      appNotifications = results[4] as List;
      draftCount = allRecords.where((r) => (r['state']?.toString() ?? 'draft') == 'draft').length;
      waitingCount = waitingList.length;
      confirmedCount = allRecords.where((r) => (r['state']?.toString() ?? '') == 'confirmed' || (r['state']?.toString() ?? '') == 'invoiced').length;
      todayCount = allRecords.where((r) => (r['date_consultation']?.toString() ?? '').startsWith(todayKey)).length;
      loading = false;
    });
    _animCtrl.forward();
  }

  // Filtrer les notifications pour ne compter que les non-lues
  List get unreadNotifications => appNotifications.where((n) => !readNotifIds.contains(n['id'])).toList();

  Future<void> _markAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var n in appNotifications) {
        if (!readNotifIds.contains(n['id'])) {
          readNotifIds.add(n['id']);
        }
      }
    });
    await prefs.setStringList('read_notifications', readNotifIds.map((id) => id.toString()).toList());
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final lang  = context.watch<LanguageProvider>();
    final isRtl = lang.isArabic;

    TextStyle titleStyle(double s) => isRtl
        ? GoogleFonts.cairo(fontSize: s, fontWeight: FontWeight.w800, color: AppColors.textPrimary)
        : GoogleFonts.plusJakartaSans(fontSize: s, fontWeight: FontWeight.w800, color: AppColors.textPrimary);
    TextStyle bodyStyle([Color? c]) => isRtl
        ? GoogleFonts.cairo(fontSize: 14, color: c ?? AppColors.textMuted)
        : GoogleFonts.dmSans(fontSize: 14, color: c ?? AppColors.textMuted);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(children: [
          const Sidebar(currentRoute: '/dashboard'),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // HEADER
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${l10n.greeting()}, $doctorName 👋', style: titleStyle(24)),
                      const SizedBox(height: 4),
                      Text(l10n.t('dashSubtitle'), style: bodyStyle()),
                    ]),
                    Row(children: [
                      _notificationButton(),
                      const SizedBox(width: 12),
                      _dateBadge(l10n),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  AppBreadcrumb(
                    items: [
                      BreadcrumbItem(label: l10n.t('home')),
                      BreadcrumbItem(label: l10n.t('dashboardLabel')),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // STAT CARDS
                  Row(children: [
                    _statCard(l10n.t('totalPatients'), stats['patients'] ?? 0,
                        Icons.people_alt_rounded, AppColors.primary, AppColors.primaryLight,
                        '+${stats['patients']} ${l10n.t('registered')}', isRtl),
                    const SizedBox(width: 16),
                    _statCard(l10n.t('medicalRecords'), stats['records'] ?? 0,
                        Icons.folder_special_rounded, AppColors.purple, AppColors.purpleLight,
                        l10n.t('allConsultations'), isRtl),
                    const SizedBox(width: 16),
                    _statCard(l10n.t('consultations'), stats['records'] ?? 0,
                        Icons.medical_services_rounded, AppColors.yellow, AppColors.yellowLight,
                        l10n.t('thisMonth'), isRtl),
                  ]),
                  const SizedBox(height: 22),

                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: _overviewPanel(l10n, isRtl)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _waitingRoomPanel(l10n, isRtl)),
                  ]),
                  const SizedBox(height: 32),

                  // ACTIONS RAPIDES
                  Text(l10n.t('quickActions'), style: titleStyle(17)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _quickCard(l10n.t('viewPatients'), Icons.people_alt_rounded,
                          AppColors.primary, AppColors.primaryLight, '/patients',
                          '${stats['patients']} ${l10n.t('navPatients')}', isRtl),
                      _quickCard(l10n.t('newRecord'), Icons.add_circle_rounded,
                          AppColors.green, AppColors.greenLight, '/add_record',
                          l10n.t('createNow'), isRtl),
                      _quickCard(l10n.t('allRecords'), Icons.folder_open_rounded,
                          AppColors.red, AppColors.redLight, '/records',
                          '${stats['records']} ${l10n.t('navRecords')}', isRtl),
                      _quickCard(l10n.t('viewCalendar'), Icons.calendar_month_rounded,
                          AppColors.purple, AppColors.purpleLight, '/calendar',
                          l10n.t('calendarSubtitle'), isRtl),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ACTIVITÉ RÉCENTE
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(l10n.t('recentActivity'), style: titleStyle(17)),
                    TextButton.icon(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/records'),
                      icon: Icon(
                        isRtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                        size: 14, color: AppColors.primary),
                      label: Text(l10n.t('seeAll'),
                          style: isRtl
                              ? GoogleFonts.cairo(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)
                              : GoogleFonts.dmSans(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _recentTable(l10n, isRtl),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _notificationButton() {
    int count = unreadNotifications.length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: IconButton(
        onPressed: () {
          _showUpdateDialog();
          _markAsRead(); // Marquer comme lu dès qu'on ouvre
        },
        icon: count > 0 
          ? Badge(
              backgroundColor: AppColors.red,
              label: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10)),
              child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 22),
            )
          : const Icon(Icons.notifications_none_rounded, color: AppColors.primary, size: 22),
        tooltip: 'Mises à jour & Infos',
      ),
    );
  }

  void _showUpdateDialog() {
    if (appNotifications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune notification.'))
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Centre de Notifications', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: appNotifications.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final notif = appNotifications[index];
              bool isUnread = !readNotifIds.contains(notif['id']);
              return ListTile(
                leading: Icon(
                  notif['is_critical'] == true ? Icons.warning_rounded : Icons.info_rounded,
                  color: notif['is_critical'] == true ? AppColors.red : AppColors.primary,
                ),
                title: Text(notif['title'] ?? '', style: GoogleFonts.dmSans(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notif['content'] ?? ''),
                    if (notif['url'] != null && notif['url'].toString().isNotEmpty)
                      TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse(notif['url'])),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Télécharger la mise à jour'),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _dateBadge(AppLocalizations l10n) {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 14),
        const SizedBox(width: 8),
        Text(
          '${l10n.days[now.weekday - 1]} ${now.day} ${l10n.months[now.month - 1]} ${now.year}',
          style: GoogleFonts.dmSans(color: AppColors.textSecond, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color color,
      Color bgColor, String sub, bool isRtl) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.5), shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 18),
            Text('$value',
                style: isRtl
                    ? GoogleFonts.cairo(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1)
                    : GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1)),
            const SizedBox(height: 5),
            Text(label, style: isRtl
                ? GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecond, fontWeight: FontWeight.w500)
                : GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecond, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(sub, style: isRtl
                ? GoogleFonts.cairo(fontSize: 11, color: color, fontWeight: FontWeight.w600)
                : GoogleFonts.dmSans(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _quickCard(String label, IconData icon, Color color, Color bgColor,
      String route, String subtitle, bool isRtl) =>
      SizedBox(
        width: 260,
        child: GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, route),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
              boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(width: 42, height: 42,
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isRtl
                        ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)
                        : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isRtl
                        ? GoogleFonts.cairo(color: color, fontSize: 11, fontWeight: FontWeight.w500)
                        : GoogleFonts.dmSans(color: color, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Widget _overviewPanel(AppLocalizations l10n, bool isRtl) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.t('todayOverview'), style: isRtl
          ? GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
          : GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _miniInsight(l10n.t('todayRecords'), '$todayCount', AppColors.primary, AppColors.primaryLight, isRtl)),
        const SizedBox(width: 10),
        Expanded(child: _miniInsight(l10n.t('waitingRoom'), '$waitingCount', AppColors.red, AppColors.redLight, isRtl)),
        const SizedBox(width: 10),
        Expanded(child: _miniInsight(l10n.t('validatedRecords'), '$confirmedCount', AppColors.green, AppColors.greenLight, isRtl)),
      ]),
    ]),
  );

  Widget _miniInsight(String label, String value, Color color, Color bg, bool isRtl) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: isRtl
          ? GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.w800, color: color)
          : GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 4),
      Text(label, style: isRtl
          ? GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecond, fontWeight: FontWeight.w600)
          : GoogleFonts.dmSans(fontSize: 11, color: AppColors.textSecond, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _waitingRoomPanel(AppLocalizations l10n, bool isRtl) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.t('waitingRoom'), style: isRtl
          ? GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
          : GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      if (waitingList.isEmpty)
        Text(l10n.t('noData'), style: isRtl
            ? GoogleFonts.cairo(color: AppColors.textHint, fontSize: 13)
            : GoogleFonts.dmSans(color: AppColors.textHint, fontSize: 13))
      else
        ...waitingList.map((consult) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  consult['patient_id'] is List ? consult['patient_id'][1].toString()[0].toUpperCase() : 'P',
                  style: GoogleFonts.plusJakartaSans(color: AppColors.red, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(consult['patient_id'] is List ? consult['patient_id'][1].toString() : '—', overflow: TextOverflow.ellipsis, style: isRtl
                    ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)
                    : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                Text(
                  consult['motif']?.toString() ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: isRtl
                      ? GoogleFonts.cairo(color: AppColors.textMuted, fontSize: 11)
                      : GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11),
                ),
              ]),
            ),
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/records', arguments: {'id': consult['patient_id'][0], 'name': consult['patient_id'][1]}),
              icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.green, size: 24),
              tooltip: l10n.t('openRecord'),
            ),
          ]),
        )),
    ]),
  );

  Widget _recentTable(AppLocalizations l10n, bool isRtl) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            l10n.t('colPatient'), l10n.t('colDate'),
            l10n.t('colDiagnostic'), l10n.t('colStatus')
          ].map((h) => Expanded(child: Text(h,
              style: isRtl
                  ? GoogleFonts.cairo(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)
                  : GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)))).toList(),
        ),
      ),
      if (recentRecords.isEmpty)
        Padding(
          padding: const EdgeInsets.all(40),
          child: Column(children: [
            Icon(Icons.inbox_rounded, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(l10n.t('noRecords'), style: isRtl
                ? GoogleFonts.cairo(color: AppColors.textHint, fontSize: 14)
                : GoogleFonts.dmSans(color: AppColors.textHint, fontSize: 14)),
          ]),
        )
      else
        ...recentRecords.asMap().entries.map(
            (e) => _tableRow(e.value, e.key == recentRecords.length - 1, l10n, isRtl)),
    ]),
  );

  Widget _tableRow(Map r, bool isLast, AppLocalizations l10n, bool isRtl) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    decoration: BoxDecoration(
      border: isLast ? null : Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Row(children: [
      Expanded(child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(
            (r['patient_id'] is List && r['patient_id'][1].toString().isNotEmpty)
                ? r['patient_id'][1].toString()[0].toUpperCase() : 'P',
            style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
          )),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(r['patient_id'] is List ? r['patient_id'][1].toString() : '—',
            overflow: TextOverflow.ellipsis,
            style: isRtl
                ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)
                : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
      ])),
      Expanded(child: Text(r['date_consultation']?.toString() ?? '—',
          style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12))),
      Expanded(child: Text(r['diagnostic']?.toString() ?? '—',
          overflow: TextOverflow.ellipsis,
          style: isRtl
              ? GoogleFonts.cairo(color: AppColors.textSecond, fontSize: 13)
              : GoogleFonts.dmSans(color: AppColors.textSecond, fontSize: 13))),
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.greenLight, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
        ),
        child: Text(l10n.t('consulted'), textAlign: TextAlign.center,
            style: isRtl
                ? GoogleFonts.cairo(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600)
                : GoogleFonts.dmSans(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600)),
      )),
    ]),
  );
}
