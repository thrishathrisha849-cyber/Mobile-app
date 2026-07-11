-- SQL Schema for Mobile App Notifications (admin -> mobile broadcast)
-- Distinct from `admin_notifications` (mobile -> admin, e.g. new tickets/feedback).
-- Run this in your Supabase SQL Editor to create the table

CREATE TABLE IF NOT EXISTS mobile_notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(50) NOT NULL DEFAULT 'community_post',
  reference_id UUID,
  reference_type VARCHAR(50),
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Safe to re-run: patches an already-created table that predates is_read.
ALTER TABLE mobile_notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_mobile_notifications_created_at ON mobile_notifications(created_at);
CREATE INDEX IF NOT EXISTS idx_mobile_notifications_is_read ON mobile_notifications(is_read);

-- Enable Row Level Security (RLS)
ALTER TABLE mobile_notifications ENABLE ROW LEVEL SECURITY;

-- Mobile app reads all broadcast notifications (no per-user auth in this app,
-- so notifications are global rather than targeted to a specific user).
-- DROP + CREATE (not CREATE POLICY IF NOT EXISTS, which Postgres doesn't
-- support) so this file is safe to re-run.
DROP POLICY IF EXISTS "Allow public read access" ON mobile_notifications;
CREATE POLICY "Allow public read access" ON mobile_notifications FOR SELECT USING (true);

-- Admin portal creates notifications
DROP POLICY IF EXISTS "Allow admin portal full access" ON mobile_notifications;
CREATE POLICY "Allow admin portal full access" ON mobile_notifications FOR ALL USING (true) WITH CHECK (true);
