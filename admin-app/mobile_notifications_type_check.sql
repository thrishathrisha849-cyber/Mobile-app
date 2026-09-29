-- Migration: restrict mobile_notifications.type to the notification types
-- the app knows about. For an EXISTING database — new installs get the same
-- constraint from the CREATE TABLE in mobile_notifications_schema.sql /
-- FULL_MIGRATION.sql. Run this in your Supabase SQL Editor.
--
-- The allowed list must match NotificationType in
-- lib/notification_service.dart (test/notification_type_test.dart checks this).
--
-- Safe to run on live data and safe to re-run:
--   * If any existing row has a type outside the list, it STOPS with an error
--     listing those values and their row counts. It never deletes or rewrites
--     rows — fix those rows yourself, then run it again.
--   * If the constraint already exists, it does nothing.
--
-- Optional preview (run on its own first to see what would block it):
--   SELECT type, COUNT(*) FROM mobile_notifications
--   WHERE type NOT IN ('community_post', 'podcast_series', 'podcast_episode',
--                      'ebook_book', 'ebook_banner', 'support_faq',
--                      'support_ticket', 'support_feedback')
--   GROUP BY type;

DO $$
DECLARE
  invalid_types TEXT;
BEGIN
  SELECT string_agg(format('%L (%s rows)', type, row_count), ', ' ORDER BY type)
    INTO invalid_types
    FROM (
      SELECT type, COUNT(*) AS row_count
        FROM mobile_notifications
       WHERE type NOT IN ('community_post', 'podcast_series', 'podcast_episode',
                          'ebook_book', 'ebook_banner', 'support_faq',
                          'support_ticket', 'support_feedback')
       GROUP BY type
    ) invalid;

  IF invalid_types IS NOT NULL THEN
    RAISE EXCEPTION 'mobile_notifications_type_check not added: existing rows have unsupported type values: %. No rows were changed. Update or remove those rows, then re-run this migration.', invalid_types;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'mobile_notifications_type_check'
       AND conrelid = 'mobile_notifications'::regclass
  ) THEN
    ALTER TABLE mobile_notifications
      ADD CONSTRAINT mobile_notifications_type_check
      CHECK (type IN ('community_post', 'podcast_series', 'podcast_episode',
                      'ebook_book', 'ebook_banner', 'support_faq',
                      'support_ticket', 'support_feedback'));
  END IF;
END $$;
