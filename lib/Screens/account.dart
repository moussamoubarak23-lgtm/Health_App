import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  bool _showNewPassword = false;
  String _userRole = 'doctor';

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _newPassCtrl = TextEditingController();
  String _login = '';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? 'doctor';
    
    final res = await OdooApi.getUserProfile();
    if (res['success']) {
      final data = res['data'];
      setState(() {
        _nameCtrl.text = (data['name'] is String) ? data['name'] : '';
        _emailCtrl.text = (data['email'] is String) ? data['email'] : '';
        _phoneCtrl.text = (data['phone'] is String) ? data['phone'] : '';
        _mobileCtrl.text = (data['mobile'] is String) ? data['mobile'] : '';
        _login = (data['login'] is String) ? data['login'] : '';
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final Map<String, dynamic> vals = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'mobile': _mobileCtrl.text.trim(),
    };

    if (_userRole == 'doctor' && _newPassCtrl.text.isNotEmpty) {
      vals['password'] = _newPassCtrl.text;
    }

    final res = await OdooApi.updateUserProfile(vals);

    if (mounted) {
      setState(() => _saving = false);
      if (res['success']) {
        _newPassCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil mis à jour avec succès"), backgroundColor: AppColors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de la mise à jour"), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const Sidebar(currentRoute: '/account'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 40),
                        Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- Left Column: Info ---
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      _buildMainCard(),
                                      const SizedBox(height: 24),
                                      if (_userRole == 'doctor') _buildSecurityCard(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // --- Right Column: Summary & Actions ---
                                Expanded(
                                  flex: 1,
                                  child: _buildSidePanel(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_userRole == 'secretary' ? "Mon Espace Secrétaire" : "Mon Compte Médecin",
              style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(_userRole == 'secretary' ? "Gérez vos informations personnelles" : "Gérez vos informations et la sécurité de votre accès",
              style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textMuted)),
        ],
      );

  Widget _buildMainCard() => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("INFORMATIONS PERSONNELLES", Icons.person_outline_rounded),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildField("Nom complet", _nameCtrl, Icons.person_rounded)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildReadOnlyField("Identifiant / Login", _login, Icons.badge_rounded)),
                ],
              ),
              const SizedBox(height: 24),
              _buildField("Adresse Email", _emailCtrl, Icons.email_rounded),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildField("Téléphone fixe", _phoneCtrl, Icons.phone_rounded)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildField("Mobile", _mobileCtrl, Icons.smartphone_rounded)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildSecurityCard() => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("SÉCURITÉ DU COMPTE", Icons.lock_outline_rounded),
            const SizedBox(height: 24),
            Text("Changer le mot de passe", style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Text("Laissez vide si vous ne souhaitez pas modifier votre mot de passe actuel.",
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            TextField(
              controller: _newPassCtrl,
              obscureText: !_showNewPassword,
              decoration: InputDecoration(
                hintText: "Nouveau mot de passe",
                prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(_showNewPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted),
                  onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                ),
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ],
        ),
      );

  Widget _buildSidePanel() => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                Text(_nameCtrl.text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_login, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                _actionTile(Icons.verified_user_rounded, "Compte vérifié"),
                _actionTile(_userRole == 'secretary' ? Icons.badge_rounded : Icons.medical_services_rounded, _userRole == 'secretary' ? "Accès Secrétaire" : "Accès Médecin"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Enregistrer les modifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      );

  Widget _actionTile(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Widget _buildSectionTitle(String title, IconData icon) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1.2)),
        ],
      );

  Widget _buildField(String label, TextEditingController ctrl, IconData icon) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          TextFormField(
            controller: ctrl,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
              filled: true,
              fillColor: AppColors.inputFill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (v) => v!.isEmpty ? "Ce champ est obligatoire" : null,
          ),
        ],
      );

  Widget _buildReadOnlyField(String label, String value, IconData icon) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Text(value, style: GoogleFonts.dmSans(color: AppColors.textMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      );
}
