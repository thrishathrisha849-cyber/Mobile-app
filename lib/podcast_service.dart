import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data access layer for the Podcast module.
///
/// Talks directly to Supabase (same pattern already used for `home_carousel`
/// in main.dart) instead of the admin-app Express server, since the mobile
/// app already ships a configured Supabase client and this avoids depending
/// on the LAN-only admin server for production reads/writes.
class PodcastService {
  PodcastService._();
  static final PodcastService instance = PodcastService._();

  SupabaseClient get _client => Supabase.instance.client;

  static const String _episodeSelect =
      '*, podcast_categories(id, name, slug), podcast_series(id, title, slug)';

  // ── Anonymous device identity (no auth system exists in this app) ──
  static const String _anonUserIdKey = 'podcast_anonymous_user_id';

  Future<String> getOrCreateAnonymousUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_anonUserIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _generateUuidV4();
    await prefs.setString(_anonUserIdKey, generated);
    return generated;
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  // ── Categories ──
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final rows = await _client
        .from('podcast_categories')
        .select()
        .eq('status', 'active')
        .order('sort_order', ascending: true);

    return List<Map<String, dynamic>>.from(rows).map((row) {
      return {
        'id': row['id'],
        'name': row['name'],
        'slug': row['slug'],
      };
    }).toList();
  }

  // ── Episodes ──
  Map<String, dynamic> _normalizeEpisode(Map<String, dynamic> row) {
    final category = row['podcast_categories'] as Map<String, dynamic>?;
    final series = row['podcast_series'] as Map<String, dynamic>?;
    final rawDuration = row['duration_seconds'];
    final durationSecs = (rawDuration as num?)?.toInt() ?? 0;

    return {
      'id': row['id'],
      'title': row['title'] ?? '',
      'slug': row['slug'],
      'desc': row['description'] ?? '',
      'description': row['description'] ?? '',
      'category': category != null ? category['name'] : 'General',
      'categoryId': row['category_id'],
      'seriesId': row['series_id'],
      'seriesTitle': series != null ? series['title'] : null,
      'cover': row['cover_image'] ?? '',
      'audioUrl': row['audio_url'] ?? '',
      'durationSecs': durationSecs,
      // Formatted from the raw value (not the `?? 0`-collapsed durationSecs
      // above) so a genuinely missing duration renders as "Duration
      // unavailable" instead of the misleading "0 min".
      'info': formatDurationLabel(rawDuration),
      'speaker': row['speaker'],
      'tags': row['tags'] != null ? List<String>.from(row['tags']) : <String>[],
      'isFeatured': row['is_featured'] ?? false,
      'sortOrder': row['sort_order'] ?? 0,
      'publishDate': row['publish_date'],
    };
  }

  /// Fetches a page of active episodes, optionally filtered by category id
  /// and/or a title search query. Pagination is page-based; the caller can
  /// tell it's the last page when fewer than [limit] items come back.
  Future<List<Map<String, dynamic>>> fetchEpisodes({
    String? categoryId,
    int page = 1,
    int limit = 10,
    String search = '',
  }) async {
    var query = _client
        .from('podcast_episodes')
        .select(_episodeSelect)
        .eq('status', 'active');

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.eq('category_id', categoryId);
    }
    if (search.isNotEmpty) {
      query = query.ilike('title', '%$search%');
    }

    final from = (page - 1) * limit;
    final to = from + limit - 1;

    final rows = await query
        .order('sort_order', ascending: true)
        .order('publish_date', ascending: false)
        .range(from, to);

    return List<Map<String, dynamic>>.from(rows)
        .map(_normalizeEpisode)
        .toList();
  }

  Future<Map<String, dynamic>?> fetchEpisodeById(String id) async {
    final row = await _client
        .from('podcast_episodes')
        .select(_episodeSelect)
        .eq('id', id)
        .eq('status', 'active')
        .maybeSingle();
    if (row == null) return null;
    return _normalizeEpisode(row);
  }

  // ── Featured Series ──
  Future<List<Map<String, dynamic>>> fetchFeaturedSeries() async {
    final seriesRows = await _client
        .from('podcast_series')
        .select()
        .eq('status', 'active')
        .order('sort_order', ascending: true);

    final result = <Map<String, dynamic>>[];
    for (final row in List<Map<String, dynamic>>.from(seriesRows)) {
      final count = await _client
          .from('podcast_episodes')
          .select('id')
          .eq('series_id', row['id'])
          .eq('status', 'active')
          .count(CountOption.exact);

      result.add({
        'id': row['id'],
        'title': row['title'] ?? '',
        'desc': row['description'] ?? '',
        'description': row['description'] ?? '',
        'cover': row['cover_image'] ?? '',
        'episodesCountRaw': count.count,
        'episodesCount': '${count.count} Episode${count.count == 1 ? '' : 's'}',
      });
    }
    return result;
  }

  Future<Map<String, dynamic>?> fetchSeriesById(String id) async {
    final row = await _client
        .from('podcast_series')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;

    final episodeRows = await _client
        .from('podcast_episodes')
        .select(_episodeSelect)
        .eq('series_id', id)
        .eq('status', 'active')
        .order('sort_order', ascending: true);

    final episodes = List<Map<String, dynamic>>.from(episodeRows)
        .map(_normalizeEpisode)
        .toList();

    return {
      'id': row['id'],
      'title': row['title'] ?? '',
      'desc': row['description'] ?? '',
      'description': row['description'] ?? '',
      'cover': row['cover_image'] ?? '',
      'episodes': episodes,
    };
  }

  // ── Continue Listening / Progress ──
  Future<List<Map<String, dynamic>>> fetchContinueListening(
      String userId) async {
    final rows = await _client
        .from('podcast_progress')
        .select('*, podcast_episodes!inner($_episodeSelect)')
        .eq('user_id', userId)
        .eq('completed', false)
        .gt('current_position_seconds', 0)
        .eq('podcast_episodes.status', 'active')
        .order('updated_at', ascending: false);

    final result = <Map<String, dynamic>>[];
    final seenEpisodeIds = <dynamic>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final episodeRow = Map<String, dynamic>.from(row['podcast_episodes']);
      final episodeId = row['episode_id'];

      // Defensive de-dup: the table already has a unique(user_id,
      // episode_id) constraint so this shouldn't fire in practice, but
      // guarantees the list can never show the same episode twice.
      if (!seenEpisodeIds.add(episodeId)) continue;

      final episode = _normalizeEpisode(episodeRow);
      final currentSecs =
          (row['current_position_seconds'] as num?)?.toInt() ?? 0;
      final totalSecs = (row['total_duration_seconds'] as num?)?.toInt() ??
          (episode['durationSecs'] as int? ?? 0);

      // Only genuinely "in progress" — position must still be short of the
      // end. Guards against a stray row that reached the end without ever
      // being marked completed (e.g. a manual seek to the very end).
      if (totalSecs > 0 && currentSecs >= totalSecs) continue;

      final remainingSecs = (totalSecs - currentSecs).clamp(0, totalSecs);
      final progress =
          totalSecs > 0 ? (currentSecs / totalSecs).clamp(0.0, 1.0) : 0.0;

      final resolvedDurationSecs =
          totalSecs > 0 ? totalSecs : episode['durationSecs'];

      result.add({
        ...episode,
        'series': episode['seriesTitle'] ?? episode['category'],
        'currentSecs': currentSecs,
        'durationSecs': resolvedDurationSecs,
        // Keeps this item's duration label consistent with the player if
        // the tracked progress total differs from the episode row's own
        // duration_seconds (e.g. that was 0/missing when playback started).
        'info': formatDurationLabel(resolvedDurationSecs),
        'progress': progress,
        'timeLeft': '${(remainingSecs / 60).ceil()} min left',
      });
    }
    return result;
  }

  Future<void> saveProgress({
    required String userId,
    required String episodeId,
    required int currentPositionSeconds,
    required int totalDurationSeconds,
    bool completed = false,
  }) async {
    await _client.from('podcast_progress').upsert({
      'user_id': userId,
      'episode_id': episodeId,
      'current_position_seconds': currentPositionSeconds,
      'total_duration_seconds': totalDurationSeconds,
      'completed': completed,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,episode_id');
  }

  Future<void> markCompleted({
    required String userId,
    required String episodeId,
    required int totalDurationSeconds,
  }) async {
    await saveProgress(
      userId: userId,
      episodeId: episodeId,
      currentPositionSeconds: totalDurationSeconds,
      totalDurationSeconds: totalDurationSeconds,
      completed: true,
    );
  }

  // ── Formatting helpers ──

  /// Coerces a raw `duration_seconds`-style value into whole seconds.
  /// Accepts the normal case (an int/num already in seconds) plus, for
  /// safety, a numeric string or a "MM:SS"/"HH:MM:SS" string, since the
  /// backend field is expected to hold seconds but this keeps the formatter
  /// from mis-parsing if a differently-shaped value ever comes through.
  /// Returns null when the value is missing or not parseable.
  static int? _coerceSeconds(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.contains(':')) {
        final parts =
            trimmed.split(':').map((p) => int.tryParse(p.trim())).toList();
        if (parts.any((p) => p == null)) return null;
        final nums = parts.cast<int>();
        if (nums.length == 3) return nums[0] * 3600 + nums[1] * 60 + nums[2];
        if (nums.length == 2) return nums[0] * 60 + nums[1];
        return null;
      }
      final asNum = num.tryParse(trimmed);
      return asNum?.round();
    }
    return null;
  }

  /// The single duration label formatter used everywhere an episode's total
  /// duration is shown (Latest Episodes, Continue Listening, and the
  /// player), so null/0/negative/unparseable durations never render as the
  /// misleading "0 min" — they show "Duration unavailable" instead.
  static String formatDurationLabel(dynamic rawSeconds) {
    final seconds = _coerceSeconds(rawSeconds);
    if (seconds == null || seconds <= 0) return 'Duration unavailable';

    final totalMinutes = (seconds / 60).round();
    if (totalMinutes <= 0) return 'Duration unavailable';

    final hours = totalMinutes ~/ 60;
    final remainderMinutes = totalMinutes % 60;
    if (hours > 0 && remainderMinutes > 0) {
      return '$hours hr $remainderMinutes min';
    }
    return '$totalMinutes min';
  }

  /// Clock-style duration formatter (MM:SS, or H:MM:SS once the duration
  /// reaches an hour) — the single formatter shared by every place in the
  /// player that shows the same total-duration value, so they can never
  /// disagree (e.g. one showing "02:09" and another showing "2 min").
  /// Negative/invalid input is clamped to 0 ("00:00") rather than throwing.
  static String formatClock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final hours = s ~/ 3600;
    final minutes = (s % 3600) ~/ 60;
    final secs = s % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
