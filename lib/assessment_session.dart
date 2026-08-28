import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Token/user/session storage for the Business Psychometric Assessment
/// feature — fully separate from [SessionManager] in main.dart (which is a
/// file-backed boolean flag, not real auth). Key convention
/// `assessment_<purpose>` mirrors podcast_service.dart's
/// `_anonUserIdKey` = `'podcast_anonymous_user_id'` pattern.
class AssessmentSession {
  AssessmentSession._();

  static const _tokenKey = 'assessment_jwt_token';
  static const _userKey = 'assessment_user_cache';
  static const _codeIdKey = 'assessment_code_id';
  static const _codeKey = 'assessment_code';
  static const _codeSelectedKey = 'assessment_code_selected';
  static const _sessionIdKey = 'assessment_session_id';
  static const _sessionExpiresKey = 'assessment_session_expires';
  static const _pendingEmailKey = 'assessment_pending_email';
  static const _autosavePrefix = 'assessment_answers_';

  static Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  static Future<void> setToken(String token) async =>
      (await SharedPreferences.getInstance()).setString(_tokenKey, token);

  static Future<Map<String, dynamic>?> getUser() async {
    final raw = (await SharedPreferences.getInstance()).getString(_userKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setUser(Map<String, dynamic> user) async =>
      (await SharedPreferences.getInstance()).setString(_userKey, jsonEncode(user));

  static Future<void> setCode(String codeId, String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeIdKey, codeId);
    await prefs.setString(_codeKey, code);
    await prefs.setBool(_codeSelectedKey, true);
  }

  static Future<bool> hasCode() async =>
      (await SharedPreferences.getInstance()).getBool(_codeSelectedKey) ?? false;

  static Future<void> clearCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_codeIdKey);
    await prefs.remove(_codeKey);
    await prefs.remove(_codeSelectedKey);
  }

  static Future<void> setSession(String sessionId, String expiresAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, sessionId);
    await prefs.setString(_sessionExpiresKey, expiresAt);
  }

  static Future<String?> getSessionId() async =>
      (await SharedPreferences.getInstance()).getString(_sessionIdKey);

  static Future<String?> getSessionExpires() async =>
      (await SharedPreferences.getInstance()).getString(_sessionExpiresKey);

  static Future<void> clearSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_sessionExpiresKey);
  }

  static Future<void> setPendingEmail(String email) async =>
      (await SharedPreferences.getInstance()).setString(_pendingEmailKey, email);

  static Future<String?> getPendingEmail() async =>
      (await SharedPreferences.getInstance()).getString(_pendingEmailKey);

  static Future<void> clearPendingEmail() async =>
      (await SharedPreferences.getInstance()).remove(_pendingEmailKey);

  static Future<void> saveAutosave(String sessionId, Map<String, dynamic> payload) async =>
      (await SharedPreferences.getInstance()).setString('$_autosavePrefix$sessionId', jsonEncode(payload));

  static Future<Map<String, dynamic>?> loadAutosave(String sessionId) async {
    final raw = (await SharedPreferences.getInstance()).getString('$_autosavePrefix$sessionId');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAutosave(String sessionId) async =>
      (await SharedPreferences.getInstance()).remove('$_autosavePrefix$sessionId');

  static Future<void> clearAllAutosaves() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_autosavePrefix)) await prefs.remove(key);
    }
  }

  /// Full teardown on logout / session expiry.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await clearCode();
    await clearSessionState();
  }
}
