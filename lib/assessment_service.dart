import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;

/// The psychometric assessment platform's backend (Express/MongoDB) is a
/// SEPARATE deployment from this app's own `admin-app` — a public HTTPS URL,
/// not a LAN-only dev server — so, unlike [AIContentService], no LAN-IP
/// discovery/probing is needed here: just one configurable base URL.
///
/// Production: pass the deployed origin at build time, e.g.
///   flutter build apk --dart-define=ASSESSMENT_API_BASE=https://api.example.com
/// Local dev: defaults to the platform's usual "host machine" loopback
/// (10.0.2.2 for the Android emulator, localhost elsewhere) on port 5000,
/// matching `cd app && npm run dev`.
String _defaultAssessmentApiBase() {
  if (kIsWeb) return 'http://localhost:5000';
  if (Platform.isAndroid) return 'http://10.0.2.2:5000';
  return 'http://localhost:5000';
}

class AssessmentApiConfig {
  AssessmentApiConfig._();
  static const String _override = String.fromEnvironment('ASSESSMENT_API_BASE');
  static String get baseUrl => _override.isNotEmpty ? _override : _defaultAssessmentApiBase();
}

/// Uniform result shape for every call — mirrors the web port's `api.ts`
/// (`{ok, status, data}`) rather than AIContentService's throw-on-failure
/// pattern, since several flows here need to branch on a FAILED response's
/// `data['code']`/`data['message']` (e.g. CODE_REQUIRED, "already in
/// progress" 409s that still carry a resumable session).
class ApiResult {
  final bool ok;
  final int status;
  final Map<String, dynamic> data;
  ApiResult({required this.ok, required this.status, required this.data});
}

class AssessmentService {
  AssessmentService._();
  static final AssessmentService instance = AssessmentService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  Future<ApiResult> _request(String method, String path, {Map<String, dynamic>? body, String? token}) async {
    final uri = Uri.parse('${AssessmentApiConfig.baseUrl}/api/v1$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    try {
      late http.Response response;
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(_requestTimeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(_requestTimeout);
          break;
        default:
          throw ArgumentError('Unsupported method: $method');
      }
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        data = {'success': false, 'message': 'Server error'};
      }
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      debugPrint('[AssessmentService] $method $path -> ${response.statusCode}');
      return ApiResult(ok: ok, status: response.statusCode, data: data);
    } on TimeoutException {
      return ApiResult(ok: false, status: 0, data: {'success': false, 'message': 'Request timed out. Please try again.'});
    } catch (e) {
      debugPrint('[AssessmentService] request failed: $e');
      return ApiResult(
        ok: false,
        status: 0,
        data: {'success': false, 'message': 'Connection failed. Please check your network and try again.'},
      );
    }
  }

  // ── Auth ─────────────────────────────────────────────────────────────
  Future<ApiResult> login(String email, String password) =>
      _request('POST', '/user/login', body: {'email': email, 'password': password});

  Future<ApiResult> validateCode(String code) => _request('POST', '/user/validate-code', body: {'code': code});

  Future<ApiResult> register({
    required String codeId,
    required String name,
    required String email,
    required String password,
  }) =>
      _request('POST', '/user/register', body: {'codeId': codeId, 'name': name, 'email': email, 'password': password});

  Future<ApiResult> verifyOtp(String email, String otp) =>
      _request('POST', '/user/verify-otp', body: {'email': email, 'otp': otp});

  Future<ApiResult> resendOtp(String email) => _request('POST', '/user/resend-otp', body: {'email': email});

  Future<ApiResult> logout(String token) => _request('POST', '/user/logout', body: const {}, token: token);

  // ── Access code / settings ──────────────────────────────────────────
  Future<ApiResult> selectCode(String code, String token) =>
      _request('POST', '/user/select-code', body: {'code': code}, token: token);

  Future<ApiResult> getSettings(String token) => _request('GET', '/assessment/settings', token: token);

  // ── Assessment flow ──────────────────────────────────────────────────
  Future<ApiResult> getQuestions(String token) => _request('GET', '/assessment/questions', token: token);

  Future<ApiResult> startSession(String token) => _request('POST', '/assessment/start', body: const {}, token: token);

  Future<ApiResult> submitAssessment({
    required String sessionId,
    required List<Map<String, dynamic>> answers,
    required bool autoSubmitted,
    required String token,
  }) =>
      _request(
        'POST',
        '/assessment/submit',
        body: {'sessionId': sessionId, 'answers': answers, 'autoSubmitted': autoSubmitted},
        token: token,
      );

  Future<ApiResult> getResult(String token) => _request('GET', '/assessment/result', token: token);

  Future<ApiResult> requestRetest(String token) => _request('POST', '/assessment/retest/request', body: const {}, token: token);

  Future<ApiResult> getMyRetest(String token) => _request('GET', '/assessment/retest/my-request', token: token);

  // ── Question audio (uploaded clip is a data: URI embedded in the
  // question payload already; this fetches CACHED NEURAL TTS bytes) ────
  Future<Uint8List?> fetchQuestionAudio(String questionId, String token) =>
      _fetchAudioBytes('/assessment/questions/$questionId/audio', token);

  Future<Uint8List?> fetchExplanationAudio(String questionId, String token) =>
      _fetchAudioBytes('/assessment/questions/$questionId/explanation-audio', token);

  Future<Uint8List?> _fetchAudioBytes(String path, String token) async {
    try {
      final uri = Uri.parse('${AssessmentApiConfig.baseUrl}/api/v1$path');
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(_requestTimeout);
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (e) {
      debugPrint('[AssessmentService] audio fetch failed: $e');
      return null;
    }
  }
}
