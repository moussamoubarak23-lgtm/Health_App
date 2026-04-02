import 'package:flutter/material.dart';

// ─── PALETTE MÉDICALE PROFESSIONNELLE ────────────────────────────────────────
// Inspirée WhatsApp : fond gris clair, blanc, bleu médical, rouge & jaune accent

class AppColors {
  // Fonds
  static const Color background   = Color(0xFFF0F2F5); // Fond principal gris clair
  static const Color surface      = Color(0xFFFFFFFF); // Cartes blanches
  static const Color surfaceAlt   = Color(0xFFF7F9FC); // Surface alternative légère
  static const Color sidebarBg    = Color(0xFFFFFFFF); // Sidebar blanche
  static const Color inputFill    = Color(0xFFF0F2F5); // Fond des champs

  // Bleu principal
  static const Color primary      = Color(0xFF0078D4); // Bleu médical principal
  static const Color primaryLight = Color(0xFFE8F4FF); // Bleu très clair (backgrounds)
  static const Color primaryDark  = Color(0xFF005A9E); // Bleu foncé (hover)
  static const Color primaryMid   = Color(0xFF1A8FE3); // Bleu intermédiaire

  // Rouge accent
  static const Color red          = Color(0xFFE53935); // Rouge accent
  static const Color redLight     = Color(0xFFFFEBEE); // Rouge très clair
  static const Color redMid       = Color(0xFFEF5350); // Rouge intermédiaire

  // Jaune accent
  static const Color yellow       = Color(0xFFFFB300); // Jaune accent
  static const Color yellowLight  = Color(0xFFFFF8E1); // Jaune très clair
  static const Color yellowDark   = Color(0xFFF57F17); // Jaune foncé

  // Vert succès
  static const Color green        = Color(0xFF2E7D32); // Vert succès
  static const Color greenLight   = Color(0xFFE8F5E9); // Vert très clair
  static const Color greenMid     = Color(0xFF43A047); // Vert intermédiaire

  // Violet accent
  static const Color purple       = Color(0xFF6A1B9A); // Violet accent
  static const Color purpleLight  = Color(0xFFF3E5F5); // Violet très clair
  static const Color purpleMid    = Color(0xFF8E24AA); // Violet intermédiaire

  // Textes
  static const Color textPrimary  = Color(0xFF1A1A2E); // Texte principal sombre
  static const Color textSecond   = Color(0xFF4A5568);  // Texte secondaire
  static const Color textMuted    = Color(0xFF9AA5B4);  // Texte désactivé
  static const Color textHint     = Color(0xFFBDC6D0);  // Placeholder

  // Bordures
  static const Color border       = Color(0xFFE2E8F0);  // Bordure standard
  static const Color borderFocus  = Color(0xFF0078D4);  // Bordure focus
  static const Color divider      = Color(0xFFEDF2F7);  // Divider

  // Ombres & overlay
  static const Color shadow       = Color(0x14000000);  // Ombre légère
  static const Color shadowMd     = Color(0x1F000000);  // Ombre moyenne
}