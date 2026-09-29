import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moble_app/notification_service.dart';

/// Every `type IN (...)` / `type NOT IN (...)` value list in [sql] that
/// follows [anchor] (or anywhere, if [anchor] is null), as sets of strings.
List<Set<String>> _typeLists(String sql, {Pattern? anchor}) {
  final pattern = RegExp(
      '${anchor == null ? '' : '$anchor\\s+CHECK\\s*\\(\\s*'}type\\s+(?:NOT\\s+)?IN\\s*\\(([^)]*)\\)');
  return pattern
      .allMatches(sql)
      .map((m) => RegExp(r"'([^']*)'")
          .allMatches(m.group(1)!)
          .map((v) => v.group(1)!)
          .toSet())
      .toList();
}

void main() {
  const expected = {
    NotificationType.communityPost: 'community_post',
    NotificationType.podcastSeries: 'podcast_series',
    NotificationType.podcastEpisode: 'podcast_episode',
    NotificationType.ebookBook: 'ebook_book',
    NotificationType.ebookBanner: 'ebook_banner',
    NotificationType.supportFaq: 'support_faq',
    NotificationType.supportTicket: 'support_ticket',
    NotificationType.supportFeedback: 'support_feedback',
  };
  final dbValues = NotificationType.values.map((t) => t.dbValue).toSet();

  group('NotificationType <-> database string', () {
    test('has exactly the 8 supported types', () {
      expect(NotificationType.values, hasLength(8));
      expect(NotificationType.values.toSet(), expected.keys.toSet());
      expect(dbValues, hasLength(8), reason: 'dbValues must be unique');
    });

    for (final entry in expected.entries) {
      test('${entry.key.name} <-> "${entry.value}"', () {
        expect(entry.key.dbValue, entry.value);
        expect(NotificationType.fromDbValue(entry.value), entry.key);
      });
    }

    test('rejects values that are not database notification types', () {
      for (final invalid in [
        'general', // FCM test messages only, never stored
        'invalid_type',
        'Community_Post', // exact match only, like the database
        'community_post ',
        'communityPost', // the Dart name is not the database value
        '',
        null,
      ]) {
        expect(NotificationType.fromDbValue(invalid), isNull,
            reason: 'fromDbValue(${invalid == null ? 'null' : '"$invalid"'})');
      }
    });
  });

  group('database CHECK constraint matches the enum', () {
    test('new-install schema (mobile_notifications_schema.sql)', () {
      final sql =
          File('admin-app/mobile_notifications_schema.sql').readAsStringSync();
      final lists =
          _typeLists(sql, anchor: 'mobile_notifications_type_check');
      expect(lists, hasLength(1));
      expect(lists.single, dbValues);
      expect(sql, contains("DEFAULT 'community_post'"));
    });

    test('new-install schema (FULL_MIGRATION.sql)', () {
      final sql = File('admin-app/FULL_MIGRATION.sql').readAsStringSync();
      final lists =
          _typeLists(sql, anchor: 'mobile_notifications_type_check');
      expect(lists, hasLength(1));
      expect(lists.single, dbValues);
    });

    test('existing-database migration (every list in the file)', () {
      final sql = File('admin-app/mobile_notifications_type_check.sql')
          .readAsStringSync();
      final lists = _typeLists(sql);
      // Preview query, invalid-row check, and the constraint itself.
      expect(lists, hasLength(3));
      for (final list in lists) {
        expect(list, dbValues);
      }
    });

    test('"general" is not an allowed database type', () {
      expect(dbValues, isNot(contains('general')));
    });
  });

  group('FCM push exclusions (admin-app/services/pushService.js)', () {
    test('support_ticket and support_feedback stay personal, non-push types',
        () {
      final js =
          File('admin-app/services/pushService.js').readAsStringSync();
      final match =
          RegExp(r'PERSONAL_TYPES\s*=\s*new Set\(\[([^\]]*)\]\)').firstMatch(js);
      expect(match, isNotNull, reason: 'PERSONAL_TYPES not found');
      final personal = RegExp(r"'([^']*)'")
          .allMatches(match!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();

      expect(personal, {
        NotificationType.supportTicket.dbValue,
        NotificationType.supportFeedback.dbValue,
      });
      // ...while remaining valid database types.
      expect(dbValues, containsAll(personal));
    });
  });
}
