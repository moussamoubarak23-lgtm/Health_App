import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── PROVIDER DE LANGUE ───────────────────────────────────────────────────────
class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('fr');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isFrench => _locale.languageCode == 'fr';

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language') ?? 'fr';
    _locale = Locale(saved);
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    if (_locale.languageCode == langCode) return;
    _locale = Locale(langCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', langCode);
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    await setLanguage(_locale.languageCode == 'fr' ? 'ar' : 'fr');
  }
}