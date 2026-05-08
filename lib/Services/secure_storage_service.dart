import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart';

class SecureStorageService {
  // Keys
  static const String keyEmail = 'user_email';
  static const String keyPassword = 'user_password';
  static const String keySessionId = 'session_id';
  static const String keyCsrfToken = 'csrf_token';
  static const String keyGdprConsent = 'gdpr_consent';
  static const String keyGdprConsentDate = 'gdpr_consent_date';
  
  // Encryption key (32 bytes for AES-256)
  static const String _encryptionKey = 'medical_app_secure_key_32bytes!';

  // Get encryption key
  static Key get _key => Key.fromUtf8(_encryptionKey.substring(0, 32));
  static final IV _iv = IV.fromLength(16);
  static final Encrypter _encrypter = Encrypter(AES(_key));

  // Encrypt value
  static String _encrypt(String plainText) {
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  // Decrypt value
  static String _decrypt(String encryptedText) {
    final decrypted = _encrypter.decrypt64(encryptedText, iv: _iv);
    return decrypted;
  }

  // Save credentials securely
  static Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyEmail, _encrypt(email));
    await prefs.setString(keyPassword, _encrypt(password));
  }

  // Get email
  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString(keyEmail);
    if (encrypted != null) return _decrypt(encrypted);
    return null;
  }

  // Get password
  static Future<String?> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString(keyPassword);
    if (encrypted != null) return _decrypt(encrypted);
    return null;
  }

  // Save session ID
  static Future<void> saveSessionId(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keySessionId, _encrypt(sessionId));
  }

  // Get session ID
  static Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString(keySessionId);
    if (encrypted != null) return _decrypt(encrypted);
    return null;
  }

  // Save CSRF token
  static Future<void> saveCsrfToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCsrfToken, _encrypt(token));
  }

  // Get CSRF token
  static Future<String?> getCsrfToken() async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString(keyCsrfToken);
    if (encrypted != null) return _decrypt(encrypted);
    return null;
  }

  // Save GDPR consent
  static Future<void> saveGdprConsent(bool consented) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyGdprConsent, consented);
    await prefs.setString(keyGdprConsentDate, DateTime.now().toIso8601String());
  }

  // Get GDPR consent
  static Future<bool?> getGdprConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyGdprConsent);
  }

  // Get GDPR consent date
  static Future<String?> getGdprConsentDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyGdprConsentDate);
  }

  // Clear all sensitive data
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyEmail);
    await prefs.remove(keyPassword);
    await prefs.remove(keySessionId);
    await prefs.remove(keyCsrfToken);
  }

  // Clear credentials only
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyEmail);
    await prefs.remove(keyPassword);
  }
}
