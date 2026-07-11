import 'package:supabase_flutter/supabase_flutter.dart';
import 'connections_service.dart';
import 'podcast_service.dart';

/// One educational task definition merged with the current user's progress
/// toward it.
class TbtTask {
  final String id;
  final int order;
  final String title;
  final String description;
  final String requiredAction;
  final int rewardPoints;
  final String status; // 'locked' | 'current' | 'completed'
  final bool isLocked;
  final bool isCompleted;
  final DateTime? completedAt;

  const TbtTask({
    required this.id,
    required this.order,
    required this.title,
    required this.description,
    required this.requiredAction,
    required this.rewardPoints,
    required this.status,
    required this.isLocked,
    required this.isCompleted,
    required this.completedAt,
  });
}

class TbtTaskPath {
  final int totalPoints;
  final int dailyStreak;
  final int currentLevel;
  final List<TbtTask> tasks;

  const TbtTaskPath({
    required this.totalPoints,
    required this.dailyStreak,
    required this.currentLevel,
    required this.tasks,
  });

  // Derived from the same task list — one star per completed task, and
  // percent progress toward finishing the whole path. Not separately
  // fetched/hardcoded; always consistent with `tasks`.
  int get totalStars => tasks.where((t) => t.isCompleted).length;

  int get progressPercent =>
      tasks.isEmpty ? 0 : ((totalStars / tasks.length) * 100).round();
}

/// Data access layer for Daily Streak / Connections / TBT Points / Levels.
///
/// Mirrors `podcast_service.dart` / `ebook_service.dart`: talks directly to
/// Supabase, returns plain data (no heavy model layer), and reuses the same
/// anonymous per-device identity (there is no auth system in this app).
///
/// `tbt_activity_log` is the single source of truth for both TBT Points
/// (SUM of points) and Daily Streak (consecutive distinct activity_date
/// values counting back from today) — this is the app's real "existing
/// point-earning activity" (90-Day Task / Spotlight completion in
/// task.dart), not an invented rule.
class TbtPointsService {
  TbtPointsService._();
  static final TbtPointsService instance = TbtPointsService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ── Anonymous device identity (shared with Podcast/E-book — same device, same id) ──
  Future<String> getOrCreateAnonymousUserId() {
    return PodcastService.instance.getOrCreateAnonymousUserId();
  }

  Future<int> _fetchTotalPoints(String userId) async {
    final rows = await _client.from('tbt_activity_log').select('points').eq('user_id', userId);

    int total = 0;
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      total += (row['points'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  Future<int> _fetchDailyStreak(String userId) async {
    final rows = await _client
        .from('tbt_activity_log')
        .select('activity_date')
        .eq('user_id', userId)
        .order('activity_date', ascending: false);

    final distinctDates = <DateTime>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final raw = row['activity_date'] as String?;
      if (raw == null) continue;
      final d = DateTime.parse(raw);
      distinctDates.add(DateTime(d.year, d.month, d.day));
    }
    if (distinctDates.isEmpty) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Count back from today if today already has activity, otherwise from
    // yesterday — so an in-progress streak isn't shown as broken before the
    // current day's activity has actually happened yet.
    var cursor = distinctDates.contains(todayDate)
        ? todayDate
        : todayDate.subtract(const Duration(days: 1));
    if (!distinctDates.contains(cursor)) return 0;

    var streak = 0;
    while (distinctDates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Profile page stats: Daily Streak, Connections, TBT Points.
  /// Never throws — on any failure (offline, RLS, etc.) returns all-zero
  /// rather than crashing or showing stale/fake data.
  Future<Map<String, int>> fetchProfileStats() async {
    try {
      final userId = await getOrCreateAnonymousUserId();
      final totalPoints = await _fetchTotalPoints(userId);
      final dailyStreak = await _fetchDailyStreak(userId);
      final connections = await ConnectionsService.instance.fetchConnectionsCount();
      return {
        'dailyStreak': dailyStreak,
        'connections': connections,
        'tbtPoints': totalPoints,
      };
    } catch (e) {
      return {'dailyStreak': 0, 'connections': 0, 'tbtPoints': 0};
    }
  }

  /// TBT Points page: the educational task path, derived from real task
  /// definitions in `tbt_tasks` (admin/DB content, not hardcoded) merged
  /// with this user's completions from `tbt_task_completions`. Unlocking is
  /// strictly sequential — a task is only available once every earlier task
  /// (by task_order) is completed.
  Future<TbtTaskPath> fetchTaskPath() async {
    try {
      final userId = await getOrCreateAnonymousUserId();
      final totalPointsFuture = _fetchTotalPoints(userId);
      final dailyStreakFuture = _fetchDailyStreak(userId);
      final taskRowsFuture = _client
          .from('tbt_tasks')
          .select()
          .eq('status', 'active')
          .order('task_order', ascending: true);
      final completionRowsFuture =
          _client.from('tbt_task_completions').select('task_id, completed_at').eq('user_id', userId);

      final taskRows = List<Map<String, dynamic>>.from(await taskRowsFuture);
      final completionRows = List<Map<String, dynamic>>.from(await completionRowsFuture);
      final totalPoints = await totalPointsFuture;
      final dailyStreak = await dailyStreakFuture;

      final completedAtByTaskId = <String, DateTime?>{
        for (final row in completionRows)
          row['task_id'].toString(): row['completed_at'] != null
              ? DateTime.tryParse(row['completed_at'] as String)
              : null,
      };

      var currentAssigned = false;
      var completedCount = 0;
      final tasks = <TbtTask>[];

      for (final row in taskRows) {
        final id = row['id'].toString();
        final isCompleted = completedAtByTaskId.containsKey(id);
        if (isCompleted) completedCount++;

        String status;
        bool isLocked;
        if (isCompleted) {
          status = 'completed';
          isLocked = false;
        } else if (!currentAssigned) {
          status = 'current';
          isLocked = false;
          currentAssigned = true;
        } else {
          status = 'locked';
          isLocked = true;
        }

        tasks.add(TbtTask(
          id: id,
          order: (row['task_order'] as num?)?.toInt() ?? 0,
          title: (row['title'] as String?) ?? '',
          description: (row['description'] as String?) ?? '',
          requiredAction: (row['required_action'] as String?) ?? '',
          rewardPoints: (row['reward_points'] as num?)?.toInt() ?? 0,
          status: status,
          isLocked: isLocked,
          isCompleted: isCompleted,
          completedAt: completedAtByTaskId[id],
        ));
      }

      final currentLevel = tasks.isEmpty ? 1 : (completedCount + 1).clamp(1, tasks.length);

      return TbtTaskPath(
        totalPoints: totalPoints,
        dailyStreak: dailyStreak,
        currentLevel: currentLevel,
        tasks: tasks,
      );
    } catch (e) {
      return const TbtTaskPath(totalPoints: 0, dailyStreak: 0, currentLevel: 1, tasks: []);
    }
  }

  /// Marks a task complete for the current user: records the completion
  /// (idempotent — a unique constraint on (user_id, task_id) means a double
  /// tap can't double-award) and logs the reward into the same
  /// `tbt_activity_log` ledger that powers Total TBT Points / Daily Streak
  /// everywhere else in the app. Returns true on success.
  Future<bool> completeTask({required String taskId, required int rewardPoints}) async {
    try {
      final userId = await getOrCreateAnonymousUserId();
      await _client.from('tbt_task_completions').insert({
        'user_id': userId,
        'task_id': taskId,
      });
      await logActivity(points: rewardPoints, source: 'tbt_task_completion');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Logs one point-earning event. Additive only — does not replace or
  /// touch task.dart's existing local-file tracking. Failures are swallowed
  /// (matches the app's existing "silently fail, don't block the user's
  /// flow" convention used for the LAN habits fetch in main.dart) so a
  /// network hiccup never blocks task submission.
  Future<void> logActivity({required int points, required String source}) async {
    try {
      final userId = await getOrCreateAnonymousUserId();
      await _client.from('tbt_activity_log').insert({
        'user_id': userId,
        'points': points,
        'source': source,
      });
    } catch (e) {
      // Intentionally swallowed — see doc comment above.
    }
  }
}
