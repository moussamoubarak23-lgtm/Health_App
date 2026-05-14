import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';
import 'package:medical_app/utils/navigation_history.dart';
import 'package:medical_app/Widgets/app_breadcrumb.dart';
import 'package:medical_app/Widgets/sidebar.dart';

class DashboardSecretaireScreen extends StatefulWidget {
  const DashboardSecretaireScreen({super.key});
  @override
  State<DashboardSecretaireScreen> createState() => _DashboardSecretaireScreenState();
}

class _DashboardSecretaireScreenState extends State<DashboardSecretaireScreen> with TickerProviderStateMixin {
  Map<String, int> stats = {};
  Map<String, int> todayStats = {};
  List waitingList = [];
  List allPatients = [];
  List allRecords = [];
  bool loading = true;
  String secretaryName = '';
  int todayCount = 0;
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
    setState(() => secretaryName = prefs.getString('doctor_name') ?? 'Secrétaire');

    final results = await Future.wait([
      OdooApi.getDashboardStats(),
      OdooApi.getMedicalRecords(),
      OdooApi.getWaitingRoom(),
      OdooApi.getPatients(),
    ]);

    final recordsList = results[1] as List;
    final patientsList = results[3] as List;
    final todayKey = _dateKey(DateTime.now());

    // Calculer les statistiques du jour
    final todayPatients = patientsList.where((p) {
      if (p['create_date'] == null) return false;
      final createDate = p['create_date'].toString().split(' ')[0];
      return createDate == todayKey;
    }).length;

    final todayRecords = recordsList.where((r) {
      if (r['date_consultation'] == null) return false;
      final dateConsult = r['date_consultation'].toString().split(' ')[0];
      final state = r['state']?.toString().toLowerCase() ?? '';
      return dateConsult == todayKey && (state == 'invoiced' || state == 'confirmed' || state == 'validated');
    }).length;

    final todayConsultations = recordsList.where((r) {
      if (r['date_consultation'] == null) return false;
      final dateConsult = r['date_consultation'].toString().split(' ')[0];
      final state = r['state']?.toString().toLowerCase() ?? '';
      return dateConsult == todayKey && (state == 'invoiced' || state == 'confirmed' || state == 'validated');
    }).length;

    setState(() {
      stats = results[0] as Map<String, int>;
      allPatients = patientsList;
      allRecords = recordsList;
      todayStats = {
        'patients': todayPatients,
        'records': todayRecords,
        'consultations': todayConsultations,
      };
      waitingList = results[2] as List;
      todayCount = allRecords.where((r) {
        final dateConsult = r['date_consultation']?.toString() ?? '';
        if (!dateConsult.startsWith(todayKey)) return false;
        final state = r['state']?.toString().toLowerCase() ?? '';
        return state == 'invoiced' || state == 'confirmed' || state == 'validated';
      }).length;
      print('>>> todayCount: $todayCount (invoiced/confirmed/validated today only)');
      loading = false;
    });
    _animCtrl.forward();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
          const Sidebar(currentRoute: '/dashboard_secretaire'),
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
                      Text('${l10n.t('welcome')} $secretaryName', style: titleStyle(24)),
                      const SizedBox(height: 4),
                      Text(l10n.t('dashSubtitle'), style: bodyStyle()),
                    ]),
                    Row(children: [
                      IconButton.filled(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _dateBadge(l10n),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  AppBreadcrumb(
                    items: [
                      BreadcrumbItem(label: l10n.t('home')),
                      BreadcrumbItem(label: l10n.t('dashboardSecretary')),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // STAT CARDS (Total patient, Consultation, Vue du Jour, salle d'attente)
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showHistoryDialog('patients', l10n, isRtl),
                        child: _statCard(l10n.t('totalPatients'), todayStats['patients'] ?? 0,
                            Icons.people_alt_rounded, AppColors.primary, AppColors.primaryLight,
                            '+${todayStats['patients']} ${l10n.t('registered')}', isRtl),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showHistoryDialog('consultations', l10n, isRtl),
                        child: _statCard(l10n.t('consultations'), todayStats['consultations'] ?? 0,
                            Icons.medical_services_rounded, AppColors.yellow, AppColors.yellowLight,
                            l10n.t('allConsultations'), isRtl),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _statCard(l10n.t('todayView'), todayCount,
                          Icons.visibility_rounded, AppColors.purple, AppColors.purpleLight,
                          l10n.t('todayConsults'), isRtl),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _statCard(l10n.t('waitingRoom'), waitingList.length,
                          Icons.hourglass_empty_rounded, AppColors.red, AppColors.redLight,
                          l10n.t('patientsWaiting'), isRtl, 
                          onTap: () => _showWaitingRoomDialog(l10n, isRtl)),
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // ACTIONS RAPIDES (Voir le patient, Voir le Calendrier)
                  Text(l10n.t('quickActions'), style: titleStyle(17)),
                  const SizedBox(height: 14),
                  Row(children: [
                    _quickCard(l10n.t('viewPatientAction'), Icons.people_alt_rounded,
                        AppColors.primary, AppColors.primaryLight, '/patients',
                        '${stats['patients']} ${l10n.t('navPatients')}', isRtl),
                    const SizedBox(width: 16),
                    _quickCard(l10n.t('viewCalendar'), Icons.calendar_month_rounded,
                        AppColors.purple, AppColors.purpleLight, '/calendar',
                        l10n.t('calendarSubtitle'), isRtl),
                    const Spacer(flex: 2),
                  ]),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showWaitingRoomDialog(AppLocalizations l10n, bool isRtl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.t('waitingRoom'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: waitingList.isEmpty 
            ? Center(child: Text(l10n.t('noData'), style: GoogleFonts.dmSans(color: AppColors.textMuted)))
            : ListView.separated(
                shrinkWrap: true,
                itemCount: waitingList.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final consult = waitingList[i];
                  final patientName = consult['patient_id'] is List ? consult['patient_id'][1].toString() : '—';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.redLight,
                      child: Text(patientName[0].toUpperCase(), style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(patientName, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                    subtitle: Text(consult['motif']?.toString() ?? 'Consultation', style: GoogleFonts.dmSans(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      Navigator.pop(context);
                      // Navigation vers le patient ou le calendrier si besoin
                    },
                  );
                },
              ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.t('close'))),
        ],
      ),
    );
  }

  void _showHistoryDialog(String type, AppLocalizations l10n, bool isRtl) async {
    final Map<String, int> history = {};
    List dataList = [];
    
    if (type == 'patients') {
      dataList = allPatients.isEmpty ? await OdooApi.getPatients() : allPatients;
      print('>>> Patients data loaded: ${dataList.length} records');
    } else if (type == 'consultations') {
      dataList = allRecords.isEmpty ? await OdooApi.getMedicalRecords() : allRecords;
      print('>>> Records data loaded: ${dataList.length} records');
    }
    
    if (!mounted) return;
    
    if (type == 'consultations') {
      // Affichage par mois pour les consultations facturées uniquement (12 derniers mois)
      for (int i = 0; i < 12; i++) {
        final date = DateTime.now().subtract(Duration(days: i * 30));
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        
        int count = dataList.where((r) {
          if (r['date_consultation'] == null) return false;
          final dateConsult = r['date_consultation'].toString().split(' ')[0];
          final state = r['state']?.toString().toLowerCase() ?? '';
          return dateConsult.startsWith(monthKey) && (state == 'invoiced' || state == 'confirmed' || state == 'validated');
        }).length;
        
        history[monthKey] = count;
      }
      print('>>> Consultations history (invoiced only): $history');
    } else {
      // Affichage par jour pour patients (30 derniers jours)
      for (int i = 0; i < 30; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateKey = _dateKey(date);
        int count = 0;
        
        if (type == 'patients') {
          count = dataList.where((p) {
            if (p['create_date'] == null) return false;
            final createDate = p['create_date'].toString().split(' ')[0];
            return createDate == dateKey;
          }).length;
        }
        
        history[dateKey] = count;
      }
      print('>>> patients history: $history');
    }
    
    final title = type == 'patients' ? l10n.t('patientsHistory')
                 : l10n.t('consultationsHistory');

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: isRtl
            ? GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)
            : GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: 500,
          height: 400,
          child: history.isEmpty
              ? Center(child: Text(l10n.t('noData'), style: isRtl
                  ? GoogleFonts.cairo(color: AppColors.textHint)
                  : GoogleFonts.dmSans(color: AppColors.textHint)))
              : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final dateKey = history.keys.elementAt(index);
                    final count = history[dateKey] ?? 0;
                    final dateParts = dateKey.split('-');
                    
                    String formattedDate;
                    if (type == 'consultations' && dateParts.length == 2) {
                      // Format mois pour consultations
                      final month = int.parse(dateParts[1]);
                      final year = int.parse(dateParts[0]);
                      formattedDate = '${month.toString().padLeft(2, '0')}/$year';
                    } else {
                      // Format jour pour patients
                      final date = DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]));
                      formattedDate = '${date.day}/${date.month}/${date.year}';
                    }
                    
                    return ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: type == 'patients' ? AppColors.primaryLight
                              : AppColors.yellowLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text('$count', style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: type == 'patients' ? AppColors.primary
                                  : AppColors.yellow)),
                        ),
                      ),
                      title: Text(formattedDate, style: isRtl
                          ? GoogleFonts.cairo(fontWeight: FontWeight.w600)
                          : GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                      trailing: Text('$count ${type == 'patients' ? l10n.t('navPatients') : l10n.t('consultations')}',
                          style: isRtl
                              ? GoogleFonts.cairo(color: AppColors.textMuted)
                              : GoogleFonts.dmSans(color: AppColors.textMuted)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.t('close')),
          ),
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
      Color bgColor, String sub, bool isRtl, {VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: onTap != null ? color.withOpacity(0.3) : AppColors.border, width: onTap != null ? 2 : 1),
            boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              if (onTap != null) const Icon(Icons.touch_app_rounded, color: AppColors.textHint, size: 16),
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
      Expanded(
        child: GestureDetector(
          onTap: () {
        NavigationHistory().addRoute(route);
        Navigator.pushReplacementNamed(context, route);
      },
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
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: isRtl
                    ? GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)
                    : GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle, style: isRtl
                    ? GoogleFonts.cairo(color: color, fontSize: 11, fontWeight: FontWeight.w500)
                    : GoogleFonts.dmSans(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
              ]),
            ]),
          ),
        ),
      );
}
