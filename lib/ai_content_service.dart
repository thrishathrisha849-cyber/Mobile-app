import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import 'podcast_service.dart';

/// `MultipartFile.fromPath` does NOT reliably infer the content-type from
/// the file extension on every platform — confirmed via a live device test
/// where it defaulted to `application/octet-stream` for a `.jpg` file,
/// which the backend's `imageUploadService.js` MIME allowlist then silently
/// rejected. Content-type is set explicitly instead, matching FR-010's
/// allowed types.
MediaType? _mediaTypeForPath(String path) {
  final ext = path.toLowerCase().substring(path.lastIndexOf('.') + 1);
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    case 'webp':
      return MediaType('image', 'webp');
    default:
      return null;
  }
}

/// Data access layer for the AI Content Creation Assistant ("Content Buddy AI").
///
/// Unlike `PodcastService`/`EBookService`, this does NOT talk to Supabase
/// directly — every call goes through the `admin-app` backend instead, since
/// the Claude API key must never reach the mobile app. See
/// specs/001-ai-content-assistant/plan.md §1 "Deliberate deviation" for why.
///
/// Reachability follows the same LAN-fallback pattern already used by
/// `_fetchDynamicHabits` in main.dart, since admin-app is currently only
/// reachable on the same network as the device (not yet deployed to a public
/// host) — every request that can't reach any candidate host surfaces as
/// `AIContentServiceException('backend_unavailable', ...)`.
class AIContentService {
  AIContentService._();
  static final AIContentService instance = AIContentService._();

  static const int _port = 5000;
  static const Duration _requestTimeout = Duration(seconds: 35);
  static const Duration _probeTimeout = Duration(seconds: 2);

  String? _cachedBaseUrl;

  /// Same anonymous per-device identity used by Podcast/E-books — this app
  /// has no real login system, so all modules share one device-scoped id.
  /// (Matches `EBookService.getOrCreateAnonymousUserId()`, which itself
  /// delegates to `PodcastService` for the same reason.)
  Future<String> getOrCreateAnonymousUserId() {
    return PodcastService.instance.getOrCreateAnonymousUserId();
  }

  List<String> _candidateHosts() {
    final hosts = <String>['192.168.0.115']; // LAN IP first, physical device testing
    if (kIsWeb) {
      hosts.addAll(['localhost', '127.0.0.1']);
    } else if (Platform.isAndroid) {
      hosts.add('10.0.2.2');
    } else if (Platform.isIOS) {
      hosts.addAll(['localhost', '127.0.0.1']);
    }
    hosts.add('192.168.0.123');
    return hosts;
  }

  Future<String> _resolveBaseUrl() async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;

    for (final host in _candidateHosts()) {
      try {
        final uri = Uri.parse('http://$host:$_port/api/ai/conversations?user_id=probe');
        final response = await http.get(uri).timeout(_probeTimeout);
        // Any response at all (even a 4xx) means this host is reachable.
        if (response.statusCode > 0) {
          _cachedBaseUrl = 'http://$host:$_port';
          return _cachedBaseUrl!;
        }
      } catch (_) {
        continue;
      }
    }
    throw AIContentServiceException('backend_unavailable',
        "Sorry, unga request process panna mudiyala. Internet connection check panni marubadiyum try pannunga.");
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AIContentServiceException('server_error', 'Something went wrong. Please try again.');
    }
    if (body['success'] != true) {
      throw AIContentServiceException(
        (body['code'] as String?) ?? 'server_error',
        (body['message'] as String?) ?? 'Something went wrong. Please try again.',
        // content/create may still return the conversationId it already
        // created even on failure (e.g. the Claude call itself failed) —
        // callers should retry against this id instead of leaving it null,
        // or a retry silently spawns a new orphan conversation server-side.
        conversationId: body['conversationId'] as String?,
      );
    }
    return body;
  }

  Future<T> _guarded<T>(Future<T> Function(String baseUrl) action) async {
    final baseUrl = await _resolveBaseUrl();
    try {
      return await action(baseUrl).timeout(_requestTimeout);
    } on AIContentServiceException {
      rethrow;
    } on TimeoutException {
      throw AIContentServiceException('claude_timeout', 'The AI took too long to respond. Please try again.');
    } on SocketException {
      _cachedBaseUrl = null; // host may have changed networks; re-probe next call
      throw AIContentServiceException('backend_unavailable',
          "Sorry, unga request process panna mudiyala. Internet connection check panni marubadiyum try pannunga.");
    }
  }

  // ── Generation ──────────────────────────────────────────────────────────

  /// Sends a text/voice-transcribed/image request and returns the parsed
  /// `{ conversationId, content, suggestions }` response.
  ///
  /// Pass [cancelToken] and call [AICancelToken.cancel] to implement the
  /// Stop-generation button (FR-015) — this closes the underlying HTTP
  /// client, genuinely aborting the in-flight request rather than just
  /// ignoring its eventual result (spec.md §6.6).
  Future<Map<String, dynamic>> createContent({
    required String message,
    String inputType = 'text',
    String? contentType,
    String? tone,
    String? language,
    String? length,
    String? conversationId,
    File? image,
    AICancelToken? cancelToken,
  }) {
    return _guarded((baseUrl) async {
      final userId = await getOrCreateAnonymousUserId();
      final uri = Uri.parse('$baseUrl/api/ai/content/create');
      final request = http.MultipartRequest('POST', uri);

      final payload = <String, dynamic>{
        'message': message,
        'inputType': inputType,
        'userId': userId,
        if (contentType != null) 'contentType': contentType,
        if (tone != null) 'tone': tone,
        if (language != null) 'language': language,
        if (length != null) 'length': length,
        if (conversationId != null) 'conversationId': conversationId,
      };
      request.fields['payload'] = jsonEncode(payload);

      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          image.path,
          contentType: _mediaTypeForPath(image.path),
        ));
      }

      final client = http.Client();
      cancelToken?._client = client;
      try {
        final streamed = await client.send(request);
        final response = await http.Response.fromStream(streamed);
        return _decodeOrThrow(response);
      } on http.ClientException {
        if (cancelToken?._cancelled == true) {
          throw AIContentServiceException('cancelled', 'Generation stopped.');
        }
        rethrow;
      } finally {
        client.close();
      }
    });
  }

  // ── Conversations ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listConversations({String? search}) {
    return _guarded((baseUrl) async {
      final userId = await getOrCreateAnonymousUserId();
      final uri = Uri.parse('$baseUrl/api/ai/conversations').replace(queryParameters: {
        'user_id': userId,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      final response = await http.get(uri);
      final body = _decodeOrThrow(response);
      return List<Map<String, dynamic>>.from(body['conversations'] as List);
    });
  }

  Future<List<Map<String, dynamic>>> getMessages(String conversationId) {
    return _guarded((baseUrl) async {
      final userId = await getOrCreateAnonymousUserId();
      final uri = Uri.parse('$baseUrl/api/ai/conversations/$conversationId/messages')
          .replace(queryParameters: {'user_id': userId});
      final response = await http.get(uri);
      final body = _decodeOrThrow(response);
      return List<Map<String, dynamic>>.from(body['messages'] as List);
    });
  }

  Future<Map<String, dynamic>> renameConversation(String conversationId, String title) {
    return _guarded((baseUrl) async {
      final userId = await getOrCreateAnonymousUserId();
      final uri = Uri.parse('$baseUrl/api/ai/conversations/$conversationId');
      final response = await http.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'title': title}),
      );
      final body = _decodeOrThrow(response);
      return body['conversation'] as Map<String, dynamic>;
    });
  }

  Future<void> deleteConversation(String conversationId) {
    return _guarded((baseUrl) async {
      final userId = await getOrCreateAnonymousUserId();
      final uri = Uri.parse('$baseUrl/api/ai/conversations/$conversationId')
          .replace(queryParameters: {'user_id': userId});
      final response = await http.delete(uri);
      _decodeOrThrow(response);
    });
  }

  // ── Saved content ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listSaved({String? category, String? search}) {
    return _guarded((baseUrl) async {
      final userId = await getOrCreateAnonymousUserId();
      final uri = Uri.parse('$baseUrl/api/ai/saved').replace(queryParameters: {
        'user_id': userId,
        if (category != null) 'category': category,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      final response = await http.get(uri);
      final body = _decodeOrThrow(response);
      return List<Map<String, dynamic>>.from(body['items'] as List);
    });
  }

  Future<Map<String, dynamic>> saveContent({
    String? conversationId,
    required String title,
    required String content,
    String category = 'other',
  }) {
    return _guarded((baseUrl) async {
      final userId = await getOrCreateAnonymousUserId();
      final uri = Uri.parse('$baseUrl/api/ai/saved');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'conversationId': conversationId,
          'title': title,
          'content': content,
          'category': category,
        }),
      );
      final body = _decodeOrThrow(response);
      return body['item'] as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> updateSaved({
    required String id,
    String? title,
    String? content,
    String? category,
  }) {
    return _guarded((baseUrl) async {
      final userId = await getOrCreateAnonymousUserId();
      final uri = Uri.parse('$baseUrl/api/ai/saved/$id');
      final response = await http.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          if (title != null) 'title': title,
          if (content != null) 'content': content,
          if (category != null) 'category': category,
        }),
      );
      final body = _decodeOrThrow(response);
      return body['item'] as Map<String, dynamic>;
    });
  }

  Future<void> deleteSaved(String id) {
    return _guarded((baseUrl) async {
      final userId = await getOrCreateAnonymousUserId();
      final uri = Uri.parse('$baseUrl/api/ai/saved/$id').replace(queryParameters: {'user_id': userId});
      final response = await http.delete(uri);
      _decodeOrThrow(response);
    });
  }
}

/// Thrown for every failure surfaced by [AIContentService] — both backend
/// error responses (`code` mirrors the backend's error `code`, see
/// routes/ai.js) and client-side network conditions (`backend_unavailable`,
/// `claude_timeout`). The UI layer (ai_content_screen.dart) maps `code` to
/// the friendly Thanglish copy from spec.md FR-034/FR-035.
class AIContentServiceException implements Exception {
  final String code;
  final String message;

  /// Set only for `createContent` failures where the backend had already
  /// created (or resolved) the conversation before the failure occurred —
  /// retry `createContent` with this id instead of leaving it null.
  final String? conversationId;

  AIContentServiceException(this.code, this.message, {this.conversationId});

  @override
  String toString() => 'AIContentServiceException($code): $message';
}

/// Pass to [AIContentService.createContent] and call [cancel] to implement
/// the Stop-generation button — genuinely aborts the underlying HTTP request.
class AICancelToken {
  http.Client? _client;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _client?.close();
  }
}
