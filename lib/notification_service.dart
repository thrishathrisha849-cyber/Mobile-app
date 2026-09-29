import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every value `mobile_notifications.type` may hold. The database enforces
/// the same list with the `mobile_notifications_type_check` constraint
/// (admin-app/mobile_notifications_type_check.sql); keep them in sync —
/// test/notification_type_test.dart fails if they drift apart.
///
/// The type travels as its [dbValue] string everywhere outside Dart (the
/// database, admin-app's server.js, and the FCM `data.type` field), so only
/// convert at the edges with [fromDbValue] / [dbValue].
enum NotificationType {
  communityPost('community_post'),
  podcastSeries('podcast_series'),
  podcastEpisode('podcast_episode'),
  ebookBook('ebook_book'),
  ebookBanner('ebook_banner'),
  supportFaq('support_faq'),
  supportTicket('support_ticket'),
  supportFeedback('support_feedback');

  const NotificationType(this.dbValue);

  /// Exact string stored in the database and sent as FCM `data.type`.
  final String dbValue;

  /// Exact-match lookup; returns null for anything that isn't one of the
  /// database values (e.g. the FCM test type `general`, or a typo), so
  /// callers can keep their "unknown type" fallback.
  static NotificationType? fromDbValue(String? value) {
    for (final type in values) {
      if (type.dbValue == value) return type;
    }
    return null;
  }
}

/// Data access layer for mobile-facing app notifications (broadcasts sent
/// from the admin panel, e.g. when a community post is published). Mirrors
/// `legal_service.dart` / `support_service.dart`: talks directly to
/// Supabase and returns a plain `Map<String, dynamic>` (no model classes).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchNotifications(
      {int limit = 50}) async {
    final rows = await _client
        .from('mobile_notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows).map((row) {
      return {
        'id': row['id'],
        'title': row['title'] ?? '',
        'message': row['message'] ?? '',
        'type': row['type'] ?? 'general',
        'referenceId': row['reference_id'],
        'referenceType': row['reference_type'],
        'isRead': row['is_read'] ?? false,
        'createdAt': row['created_at'],
      };
    }).toList();
  }

  Future<int> fetchUnreadCount() async {
    final rows = await _client
        .from('mobile_notifications')
        .select('id')
        .eq('is_read', false);
    return List.from(rows).length;
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('mobile_notifications')
        .update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    await _client
        .from('mobile_notifications')
        .update({'is_read': true}).eq('is_read', false);
  }

  /// Fetches a single community post directly from Supabase by id. Used when
  /// a notification is tapped and the post isn't present in the mobile app's
  /// local/device-only community feed list (see `community.dart`'s
  /// `communityPosts`, which is not synced with the admin panel's Supabase
  /// `posts` table), so the app can still show the exact post.
  Future<Map<String, dynamic>?> fetchCommunityPostById(String postId) async {
    final row =
        await _client.from('posts').select().eq('id', postId).maybeSingle();
    return row;
  }
}

/// App-wide unread-notification badge state, shared by every notification
/// bell icon (Home, Community, Courses, Podcast headers) so they all show
/// the same count instead of each maintaining its own local/fake badge.
class NotificationBadge extends ChangeNotifier {
  NotificationBadge._();
  static final NotificationBadge instance = NotificationBadge._();

  int unreadCount = 0;
  bool _isLoaded = false;

  Future<void> refresh() async {
    try {
      final count = await NotificationService.instance.fetchUnreadCount();
      unreadCount = count;
      _isLoaded = true;
      notifyListeners();
    } catch (_) {
      // Keep the last known count on a transient fetch failure.
    }
  }

  Future<void> ensureLoaded() async {
    if (_isLoaded) return;
    await refresh();
  }

  Future<void> markAllRead() async {
    try {
      await NotificationService.instance.markAllAsRead();
    } catch (_) {}
    unreadCount = 0;
    notifyListeners();
  }

  void decrement() {
    if (unreadCount > 0) {
      unreadCount--;
      notifyListeners();
    }
  }
}
