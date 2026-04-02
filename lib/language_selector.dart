import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';

// ─── WIDGET SÉLECTEUR DE LANGUE (réutilisable partout) ───────────────────────
class LanguageSelector extends StatelessWidget {
  final bool compact; // true = icône seule, false = complet
  const LanguageSelector({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isAr = lang.isArabic;

    if (compact) {
      // Version compacte : bouton toggle simple
      return GestureDetector(
        onTap: () => lang.toggleLanguage(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(isAr ? '🇲🇦' : '🇫🇷', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              isAr ? 'AR' : 'FR',
              style: GoogleFonts.dmSans(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.primary),
          ]),
        ),
      );
    }

    // Version complète : deux boutons côte à côte
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _langBtn(context, lang, 'fr', '🇫🇷', 'Français', !isAr),
        const SizedBox(width: 4),
        _langBtn(context, lang, 'ar', '🇲🇦', 'العربية', isAr),
      ]),
    );
  }

  Widget _langBtn(BuildContext context, LanguageProvider lang,
      String code, String flag, String label, bool active) {
    return GestureDetector(
      onTap: () => lang.setLanguage(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: active ? Colors.white : AppColors.textSecond,
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── DIALOG SÉLECTEUR (pour Sidebar) ─────────────────────────────────────────
void showLanguageDialog(BuildContext context) {
  final lang = context.read<LanguageProvider>();
  showDialog(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: lang,
      child: Builder(builder: (ctx) {
        final l = ctx.watch<LanguageProvider>();
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.language_rounded, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              l.isArabic ? 'اختيار اللغة' : 'Choisir la langue',
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogLangTile(ctx, l, 'fr', '🇫🇷', 'Français', 'Langue française'),
            const SizedBox(height: 10),
            _dialogLangTile(ctx, l, 'ar', '🇲🇦', 'العربية', 'اللغة العربية'),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l.isArabic ? 'إغلاق' : 'Fermer',
                style: GoogleFonts.dmSans(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      }),
    ),
  );
}

Widget _dialogLangTile(BuildContext context, LanguageProvider lang,
    String code, String flag, String name, String subtitle) {
  final active = lang.locale.languageCode == code;
  return GestureDetector(
    onTap: () {
      lang.setLanguage(code);
      Navigator.pop(context);
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryLight : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Text(flag, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: GoogleFonts.dmSans(
                  color: active ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w600)),
          Text(subtitle,
              style: GoogleFonts.dmSans(
                  color: AppColors.textMuted, fontSize: 11)),
        ])),
        if (active)
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
          ),
      ]),
    ),
  );
}
