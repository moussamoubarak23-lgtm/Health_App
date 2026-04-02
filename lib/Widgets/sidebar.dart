import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/language_selector.dart';
import 'package:medical_app/theme.dart';

class Sidebar extends StatefulWidget {
  final String currentRoute;
  const Sidebar({super.key, required this.currentRoute});
  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String doctorName = '';

  @override
  void initState() { super.initState(); _loadInfo(); }

  void _loadInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => doctorName = prefs.getString('doctor_name') ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final lang  = context.watch<LanguageProvider>();
    final isRtl = lang.isArabic;

    TextStyle navStyle(bool active, Color color) => isRtl
        ? GoogleFonts.cairo(fontSize: 13,
            color: active ? color : AppColors.textSecond,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400)
        : GoogleFonts.dmSans(fontSize: 13,
            color: active ? color : AppColors.textSecond,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400);

    final navItems = [
      _NavItem(Icons.grid_view_rounded,      l10n.t('navDashboard'), '/dashboard', AppColors.primary,  AppColors.primaryLight),
      _NavItem(Icons.calendar_month_rounded, "Calendrier",           '/calendar',  AppColors.primaryMid, AppColors.primaryLight),
      _NavItem(Icons.people_alt_rounded,     l10n.t('navPatients'),  '/patients',  AppColors.purple,   AppColors.purpleLight),
      _NavItem(Icons.add_circle_rounded,     l10n.t('navAddRecord'), '/add_record',AppColors.green,    AppColors.greenLight),
      _NavItem(Icons.folder_special_rounded, l10n.t('navRecords'),   '/records',   AppColors.yellow,   AppColors.yellowLight),
      _NavItem(Icons.receipt_long_rounded,   l10n.t('navInvoices'),  '/invoices',  AppColors.primaryMid, AppColors.primaryLight),
      _NavItem(Icons.settings_rounded,       l10n.t('navSettings'),  '/settings',  AppColors.textMuted, AppColors.background),
    ];

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: AppColors.sidebarBg,
          border: Border(
            right: isRtl ? BorderSide.none : BorderSide(color: AppColors.border),
            left:  isRtl ? BorderSide(color: AppColors.border) : BorderSide.none,
          ),
          boxShadow: [BoxShadow(
            color: AppColors.shadow, blurRadius: 8,
            offset: Offset(isRtl ? -2 : 2, 0),
          )],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10, offset: const Offset(0, 4),
                  )],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/logo.png',
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.medical_services_rounded, size: 22, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.t('appName'),
                    style: isRtl
                        ? GoogleFonts.cairo(color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800, fontSize: 14)
                        : GoogleFonts.plusJakartaSans(color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('SDS',
                      style: GoogleFonts.dmSans(
                          color: AppColors.primary, fontSize: 10,
                          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                ),
              ]),
            ]),
          ),

          Divider(color: AppColors.divider, height: 1),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 6, offset: const Offset(0, 3))],
                  ),
                  child: Center(child: Text(
                    doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'M',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  )),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(doctorName.isNotEmpty ? doctorName : '—',
                      overflow: TextOverflow.ellipsis,
                      style: isRtl
                          ? GoogleFonts.cairo(color: AppColors.textPrimary,
                              fontSize: 13, fontWeight: FontWeight.w600)
                          : GoogleFonts.dmSans(color: AppColors.textPrimary,
                              fontSize: 13, fontWeight: FontWeight.w600)),
                  Row(children: [
                    Container(width: 6, height: 6,
                        decoration: const BoxDecoration(
                            color: AppColors.greenMid, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(l10n.t('online'),
                        style: isRtl
                            ? GoogleFonts.cairo(color: AppColors.green,
                                fontSize: 11, fontWeight: FontWeight.w500)
                            : GoogleFonts.dmSans(color: AppColors.green,
                                fontSize: 11, fontWeight: FontWeight.w500)),
                  ]),
                ])),
              ]),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.language_rounded, color: AppColors.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Text(l10n.t('language'),
                      style: isRtl
                          ? GoogleFonts.cairo(color: AppColors.textMuted,
                              fontSize: 11, fontWeight: FontWeight.w700)
                          : GoogleFonts.dmSans(color: AppColors.textMuted,
                              fontSize: 10, fontWeight: FontWeight.w700,
                              letterSpacing: 0.8)),
                ]),
                const SizedBox(height: 8),
                const LanguageSelector(compact: false),
              ]),
            ),
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Align(
              alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(l10n.t('navigation'),
                  style: GoogleFonts.dmSans(
                      color: AppColors.textHint, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: navItems.map((item) => _navTile(item, navStyle)).toList(),
            ),
          ),

          Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
            child: _logoutTile(l10n, isRtl),
          ),
        ]),
      ),
    );
  }

  Widget _navTile(_NavItem item, TextStyle Function(bool, Color) navStyle) {
    final isActive = widget.currentRoute == item.route;
    return GestureDetector(
      onTap: () {
        if (item.route != widget.currentRoute) {
          Navigator.pushReplacementNamed(context, item.route);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? item.color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: item.color.withValues(alpha: 0.3))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: isActive ? item.bg : AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 16,
                color: isActive ? item.color : AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Text(item.label, style: navStyle(isActive, item.color)),
          if (isActive) ...[
            const Spacer(),
            Container(width: 5, height: 5,
                decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
          ],
        ]),
      ),
    );
  }

  Widget _logoutTile(AppLocalizations l10n, bool isRtl) => GestureDetector(
    onTap: () async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.t('logoutConfirmTitle'),
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          content: Text(l10n.t('logoutConfirmBody'),
              style: isRtl
                  ? GoogleFonts.cairo(color: AppColors.textSecond)
                  : GoogleFonts.dmSans(color: AppColors.textSecond)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.t('cancel'),
                  style: GoogleFonts.dmSans(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(l10n.t('logoutBtn'),
                  style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await OdooApi.logout();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.logout_rounded, size: 16, color: AppColors.red),
        ),
        const SizedBox(width: 12),
        Text(l10n.t('logout'),
            style: isRtl
                ? GoogleFonts.cairo(color: AppColors.red,
                    fontSize: 13, fontWeight: FontWeight.w600)
                : GoogleFonts.dmSans(color: AppColors.red,
                    fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  final Color bg;
  const _NavItem(this.icon, this.label, this.route, this.color, this.bg);
}
