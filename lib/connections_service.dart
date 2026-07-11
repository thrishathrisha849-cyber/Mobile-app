import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'podcast_service.dart';

/// Data access layer for the Community "Follow" relationship, backed by the
/// `user_connections` table (see admin-app/user_connections_schema.sql for
/// why `followed_name` — not a real per-post author id — is the join key:
/// there is no user_id column on `posts` and no auth system in this app).
///
/// Mirrors `tbt_points_service.dart` / `notification_service.dart`: talks
/// directly to Supabase, reuses the same per-device anonymous id as every
/// other service (Podcast/E-book/TBT Points), no model classes.
class ConnectionsService {
  ConnectionsService._();
  static final ConnectionsService instance = ConnectionsService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> getOrCreateAnonymousUserId() {
    return PodcastService.instance.getOrCreateAnonymousUserId();
  }

  /// The set of display names the current user already follows. Used to
  /// mark posts as `isFollowing: true` when the feed loads, so follow
  /// status survives an app restart instead of always starting false.
  Future<Set<String>> fetchFollowedNames() async {
    try {
      final userId = await getOrCreateAnonymousUserId();
      final rows = await _client
          .from('user_connections')
          .select('followed_name')
          .eq('follower_id', userId);
      return List<Map<String, dynamic>>.from(rows)
          .map((r) => r['followed_name'] as String)
          .toSet();
    } catch (e) {
      debugPrint('Error fetching followed names: $e');
      return <String>{};
    }
  }

  /// Number of people the current user follows — the Profile page's
  /// "Connections" count.
  Future<int> fetchConnectionsCount() async {
    try {
      final userId = await getOrCreateAnonymousUserId();
      final rows = await _client
          .from('user_connections')
          .select('id')
          .eq('follower_id', userId);
      return List.from(rows).length;
    } catch (e) {
      debugPrint('Error fetching connections count: $e');
      return 0;
    }
  }

  /// Follows [followedName]. A no-op if already following (the table's
  /// unique(follower_id, followed_name) constraint prevents a duplicate row;
  /// that specific error is swallowed so re-tapping Follow never surfaces an
  /// error to the user).
  Future<void> follow(String followedName) async {
    final userId = await getOrCreateAnonymousUserId();
    try {
      await _client.from('user_connections').insert({
        'follower_id': userId,
        'followed_name': followedName,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // 23505 = unique_violation (already following)
    }
  }

  Future<void> unfollow(String followedName) async {
    final userId = await getOrCreateAnonymousUserId();
    await _client
        .from('user_connections')
        .delete()
        .eq('follower_id', userId)
        .eq('followed_name', followedName);
  }
}
