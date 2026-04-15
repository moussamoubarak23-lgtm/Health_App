import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medical_app/Screens/login.dart';
import 'package:medical_app/Screens/dashboard.dart';
import 'package:medical_app/Screens/dashboard_secretaire.dart';
import 'package:medical_app/Screens/patients.dart';
import 'package:medical_app/Screens/secretaries.dart';
import 'package:medical_app/Screens/nurse.dart';
import 'package:medical_app/Screens/records.dart';
import 'package:medical_app/Screens/add_record.dart';
import 'package:medical_app/Screens/invoices.dart';
import 'package:medical_app/Screens/settings.dart';
import 'package:medical_app/Screens/appointments_calendar.dart';
import 'package:medical_app/Screens/account.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const MedicalApp());
}

class MedicalApp extends StatelessWidget {
  const MedicalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, _) {
          return MaterialApp(
            title: 'MedicalRecord SDS',
            debugShowCheckedModeBanner: false,

            // ── LOCALISATION ────────────────────────────────────────────────
            locale: langProvider.locale,
            supportedLocales: const [Locale('fr'), Locale('ar')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // ── THEME ───────────────────────────────────────────────────────
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: AppColors.background,
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                secondary: AppColors.primaryDark,
                surface: AppColors.surface,
              ),
              fontFamily: langProvider.isArabic
                  ? GoogleFonts.cairo().fontFamily
                  : GoogleFonts.dmSans().fontFamily,
            ),

            home: const SplashScreen(),
            routes: {
              '/login':                (_) => const LoginScreen(),
              '/dashboard':            (_) => const DashboardScreen(),
              '/dashboard_secretaire': (_) => const DashboardSecretaireScreen(),
              '/patients':             (_) => const PatientsScreen(),
              '/secretaries':          (_) => const SecretariesScreen(),
              '/nurses':               (_) => const NursesScreen(),
              '/records':              (_) => const RecordsScreen(),
              '/add_record':           (_) => const AddRecordScreen(),
              '/invoices':             (_) => const InvoicesScreen(),
              '/settings':             (_) => const SettingsScreen(),
              '/calendar':             (_) => const AppointmentsCalendarScreen(),
              '/account':              (_) => const AccountScreen(),
            },
          );
        },
      ),
    );
  }
}

// ─── SPLASH SCREEN ───────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  String _status   = '';
  bool   _hasError = false;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _logoScale   = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.5)));
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(_textCtrl);
    _textSlide   = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _logoCtrl.forward().then((_) => _textCtrl.forward().then((_) => _checkServer()));
  }

  Future<void> _checkServer() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() => _status = l10n.t('splashConnecting'));
    final result = await OdooApi.testConnection();
    if (result['success']) {
      setState(() => _status = '${l10n.t('splashConnected')} · ${result['version']}');
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() {
        _status   = result['error'] ?? l10n.t('splashError');
        _hasError = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_status.isEmpty) {
      _status = AppLocalizations.of(context).t('splashInit');
    }
  }

  @override
  void dispose() { _logoCtrl.dispose(); _textCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3), radius: 1.2,
            colors: [Color(0xFFE8F4FF), AppColors.background],
          ),
        ),
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ScaleTransition(
              scale: _logoScale,
              child: FadeTransition(
                opacity: _logoOpacity,
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 30, spreadRadius: 4, offset: const Offset(0, 10),
                    )],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset('assets/logo.png',
                      width: 110, height: 110, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.medical_services_rounded, size: 54, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textOpacity,
                child: Column(children: [
                  Text(l10n.t('appName'),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 32, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('SDS',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: 2)),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 56),
            FadeTransition(
              opacity: _textOpacity,
              child: Column(children: [
                if (!_hasError) ...[
                  SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primary.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 16),
                ],
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: _hasError ? AppColors.redLight : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: (_hasError ? AppColors.red : AppColors.primary).withValues(alpha: 0.25)),
                  ),
                  child: Text(_status,
                      style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: _hasError ? AppColors.red : AppColors.primaryDark,
                          fontWeight: FontWeight.w500)),
                ),
                if (_hasError) ...[
                  const SizedBox(height: 10),
                  Text('URL: ${OdooApi.baseUrl}',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() { _hasError = false; _status = l10n.t('splashConnecting'); });
                      _checkServer();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(l10n.t('retry'),
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
