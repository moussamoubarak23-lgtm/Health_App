import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _loginCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _regNameCtrl  = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regLoginCtrl = TextEditingController();
  final _regPassCtrl  = TextEditingController();
  final _regPass2Ctrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _obscureReg = true;
  bool _showRegister = false;
  String? _error;
  String? _success;
  String _selectedRole = 'doctor'; // 'doctor' or 'secretary'

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _loginCtrl.dispose(); _passCtrl.dispose();
    _regNameCtrl.dispose(); _regLoginCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPassCtrl.dispose(); _regPass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final loc = AppLocalizations.of(context);
    final identifier = _loginCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _error = loc.t('allFieldsRequired'));
      return;
    }

    setState(() { _loading = true; _error = null; _success = null; });

    try {
      final result = await OdooApi.login(identifier, password, role: _selectedRole);
      if (!mounted) return;

      setState(() => _loading = false);
      if (result['success'] == true) {
        if (result['role'] == 'secretary') {
          Navigator.pushReplacementNamed(context, '/dashboard_secretaire');
        } else {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        setState(() => _error = result['error'] ?? loc.t('loginError'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Erreur critique : $e";
      });
    }
  }

  Future<void> _register() async {
    final loc = AppLocalizations.of(context);

    if (_regNameCtrl.text.trim().isEmpty || _regLoginCtrl.text.trim().isEmpty || _regPassCtrl.text.trim().isEmpty) {
      setState(() => _error = loc.t('allFieldsRequired'));
      return;
    }
    if (_regPassCtrl.text.trim() != _regPass2Ctrl.text.trim()) {
      setState(() => _error = loc.t('passwordMismatch'));
      return;
    }

    setState(() { _loading = true; _error = null; _success = null; });

    try {
      final result = await OdooApi.registerDoctor(
        name: _regNameCtrl.text.trim(),
        login: _regLoginCtrl.text.trim(),
        password: _regPassCtrl.text.trim(),
        phone: _regPhoneCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (result['success'] == true) {
        setState(() {
          _success = loc.t('accountCreated');
          _showRegister = false;
          _regNameCtrl.clear(); _regLoginCtrl.clear();
          _regPhoneCtrl.clear();
          _regPassCtrl.clear(); _regPass2Ctrl.clear();
        });
      } else {
        setState(() => _error = result['error'] ?? loc.t('error'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Impossible de créer le compte. Vérifiez votre connexion.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRtl = lang.isArabic;
    final loc = AppLocalizations.of(context);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Row(children: [
          // ── CÔTÉ GAUCHE (panel coloré) ───────────────────────────────────
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(children: [
                Positioned(top: -60, left: -60, child: _decorCircle(280, Colors.white, 0.06)),
                Positioned(bottom: -40, right: -40, child: _decorCircle(220, AppColors.yellow, 0.12)),
                Positioned(top: 160, right: 30, child: _decorCircle(90, AppColors.red, 0.1)),
                Positioned(bottom: 120, left: 40, child: _decorCircle(60, Colors.white, 0.08)),

                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset('assets/logo.png', width: 80, height: 80, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.medical_services_rounded, size: 40, color: AppColors.primary)),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(loc.t('appName').replaceAll('Record', '\nRecord'),
                            style: GoogleFonts.plusJakartaSans(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1, letterSpacing: -1)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(loc.t('appSubtitle'), style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 1)),
                        ),
                        const SizedBox(height: 48),
                        Text(loc.t('systemTitle'), style: GoogleFonts.dmSans(fontSize: 16, color: Colors.white.withOpacity(0.8), height: 1.6)),
                        const SizedBox(height: 40),
                        ...[
                          (loc.t('feature1'), Icons.folder_shared_rounded, AppColors.yellow),
                          (loc.t('feature2'), Icons.history_rounded, Colors.white),
                          (loc.t('feature3'), Icons.medical_information_rounded, AppColors.red.withOpacity(0.8)),
                          (loc.t('feature4'), Icons.verified_user_rounded, AppColors.yellow),
                        ].map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Icon(f.$2, size: 18, color: f.$3),
                            ),
                            const SizedBox(width: 14),
                            Text(f.$1, style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                          ]),
                        )),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── CÔTÉ DROIT (formulaire) ──────────────────────────────────────
          Expanded(
            flex: 4,
            child: Container(
              color: AppColors.surface,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _showRegister ? _buildRegisterForm(loc) : _buildLoginForm(loc),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
      ),
    );
  }

  Widget _buildLoginForm(AppLocalizations loc) => Column(
    key: const ValueKey('login'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(loc.t('welcomeBack'), style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      Text(loc.t('loginSubtitle'), style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted)),
      const SizedBox(height: 32),
      
      // Role Selection
      Row(children: [
        Expanded(child: _roleButton(loc.t('roleDoctor'), 'doctor', Icons.medical_services_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _roleButton(loc.t('roleSecretary'), 'secretary', Icons.badge_rounded)),
      ]),
      const SizedBox(height: 32),

      _inputField(
        controller: _loginCtrl, 
        label: _selectedRole == 'doctor' ? loc.t('identifier') : loc.t('secIdentifierLabel'), 
        hint: _selectedRole == 'doctor' ? loc.t('identifierHint') : "Ex: secretaire@clinique.com", 
        icon: _selectedRole == 'doctor' ? Icons.person_outline_rounded : Icons.alternate_email_rounded
      ),
      const SizedBox(height: 20),
      _passwordField(
        controller: _passCtrl, 
        obscure: _obscure, 
        label: _selectedRole == 'doctor' ? loc.t('password') : loc.t('secCodeLabel'),
        toggle: () => setState(() => _obscure = !_obscure), 
        onSubmit: _login
      ),
      if (_error != null) ...[const SizedBox(height: 16), _alertBox(_error!, isError: true)],
      if (_success != null) ...[const SizedBox(height: 16), _alertBox(_success!, isError: false)],
      const SizedBox(height: 28),
      _primaryButton(loc.t('loginBtn'), _login, loading: _loading),
      
      if (_selectedRole == 'doctor') ...[
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: Divider(color: AppColors.border)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(loc.t('orSeparator'), style: GoogleFonts.dmSans(color: AppColors.textHint, fontSize: 12))),
          Expanded(child: Divider(color: AppColors.border)),
        ]),
        if (OdooApi.canRegisterDoctorsFromClient) ...[
          const SizedBox(height: 24),
          _outlineButton(loc.t('createAccount'), () => setState(() { _showRegister = true; _error = null; })),
        ],
      ],
    ],
  );

  Widget _roleButton(String label, String role, IconData icon) {
    bool isSel = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() { _selectedRole = role; _error = null; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSel ? AppColors.primary : AppColors.inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSel ? AppColors.primary : AppColors.border, width: 2),
          boxShadow: isSel ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Column(children: [
          Icon(icon, color: isSel ? Colors.white : AppColors.textMuted, size: 24),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.dmSans(color: isSel ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildRegisterForm(AppLocalizations loc) => Column(
    key: const ValueKey('register'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: () => setState(() { _showRegister = false; _error = null; }),
        child: Row(children: [
          const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(loc.t('back'), style: GoogleFonts.dmSans(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 24),
      Text(loc.t('newDoctor'), style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      Text(loc.t('newDoctorSubtitle'), style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted)),
      const SizedBox(height: 32),
      _inputField(controller: _regNameCtrl, label: loc.t('fullName'), hint: loc.t('fullNameHint'), icon: Icons.badge_outlined),
      const SizedBox(height: 16),
      _inputField(controller: _regPhoneCtrl, label: loc.t('phone'), hint: '+212 600-000000', icon: Icons.phone_rounded),
      const SizedBox(height: 16),
      _inputField(controller: _regLoginCtrl, label: loc.t('identifier'), hint: loc.t('emailHint'), icon: Icons.alternate_email_rounded),
      const SizedBox(height: 16),
      _passwordField(controller: _regPassCtrl, obscure: _obscureReg, toggle: () => setState(() => _obscureReg = !_obscureReg), label: loc.t('password')),
      const SizedBox(height: 16),
      _passwordField(controller: _regPass2Ctrl, obscure: _obscureReg, toggle: () => setState(() => _obscureReg = !_obscureReg), label: loc.t('confirmPassword')),
      if (_error != null) ...[const SizedBox(height: 16), _alertBox(_error!, isError: true)],
      const SizedBox(height: 28),
      _primaryButton(loc.t('createAccount'), _register, loading: _loading, color: AppColors.primaryDark),
    ],
  );

  Widget _inputField({required TextEditingController controller, required String label, required String hint, required IconData icon}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecond, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(controller: controller, style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.dmSans(color: AppColors.textHint, fontSize: 14), prefixIcon: Icon(icon, color: AppColors.primary, size: 18), filled: true, fillColor: AppColors.inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
        ),
      ]);

  Widget _passwordField({required TextEditingController controller, required bool obscure, required VoidCallback toggle, String label = 'Mot de passe', VoidCallback? onSubmit}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecond, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(controller: controller, obscureText: obscure, onSubmitted: onSubmit != null ? (_) => onSubmit() : null, style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(hintText: '••••••••', hintStyle: GoogleFonts.dmSans(color: AppColors.textHint), prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 18),
            suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 18), onPressed: toggle),
            filled: true, fillColor: AppColors.inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
        ),
      ]);

  Widget _primaryButton(String label, VoidCallback action, {bool loading = false, Color color = AppColors.primary}) =>
      SizedBox(width: double.infinity, height: 52,
        child: ElevatedButton(onPressed: loading ? null : action,
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 2, shadowColor: color.withOpacity(0.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      );

  Widget _outlineButton(String label, VoidCallback action) =>
      SizedBox(width: double.infinity, height: 52,
        child: OutlinedButton(onPressed: action,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      );

  Widget _alertBox(String msg, {required bool isError}) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: isError ? AppColors.redLight : AppColors.greenLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: (isError ? AppColors.red : AppColors.green).withOpacity(0.3))),
    child: Row(children: [
      Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: isError ? AppColors.red : AppColors.green, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: GoogleFonts.dmSans(color: isError ? AppColors.red : AppColors.green, fontSize: 13))),
    ]),
  );

  Widget _decorCircle(double size, Color color, double opacity) => Container(width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withOpacity(opacity), width: 1.5)),
  );
}
