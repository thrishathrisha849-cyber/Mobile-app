-- SQL Schema for TBT Points (Daily Streak, Connections, TBT Points, Levels)
-- Run this in your Supabase SQL Editor to create the tables

-- 1. Activity Log (anonymous per-device user id, no auth system in this app)
-- One row per point-earning event (e.g. a 90-Day Task / Spotlight submission).
-- total_points = SUM(points) for a user. daily_streak = consecutive distinct
-- activity_date values counting back from today with at least one row.
CREATE TABLE IF NOT EXISTS tbt_activity_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id TEXT NOT NULL,
  points INTEGER NOT NULL DEFAULT 0,
  source VARCHAR(50) NOT NULL DEFAULT 'task_completion',
  activity_date DATE NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')::DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Level Definitions (static config, admin-editable content — not per-user)
-- required_points is the INCREMENTAL point cost of this level (not cumulative);
-- the service sums levels in order to compute each level's cumulative threshold.
CREATE TABLE IF NOT EXISTS tbt_levels (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  level_number INTEGER NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  required_points INTEGER NOT NULL,
  reward VARCHAR(255),
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tbt_activity_log_user ON tbt_activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_tbt_activity_log_user_date ON tbt_activity_log(user_id, activity_date);

-- Enable Row Level Security (RLS)
ALTER TABLE tbt_activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbt_levels ENABLE ROW LEVEL SECURITY;

-- Public read access (mobile app reads its own rows client-side)
-- Policies are dropped first so this script is safe to re-run (CREATE
-- POLICY has no IF NOT EXISTS clause, unlike CREATE TABLE above).
DROP POLICY IF EXISTS "Allow public read access" ON tbt_activity_log;
DROP POLICY IF EXISTS "Allow public read access" ON tbt_levels;
CREATE POLICY "Allow public read access" ON tbt_activity_log FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON tbt_levels FOR SELECT USING (true);

-- Allow all operations (admin portal + anonymous activity writes, matches podcast_progress convention)
DROP POLICY IF EXISTS "Allow all access for admin portal" ON tbt_activity_log;
DROP POLICY IF EXISTS "Allow all access for admin portal" ON tbt_levels;
CREATE POLICY "Allow all access for admin portal" ON tbt_activity_log FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for admin portal" ON tbt_levels FOR ALL USING (true) WITH CHECK (true);

-- Seed starter levels (editable afterwards from the admin panel / SQL)
INSERT INTO tbt_levels (level_number, name, description, required_points, reward, sort_order) VALUES
  (1, 'Starter', 'Complete your first tasks and get the ball rolling.', 200, 'Bronze Badge', 1),
  (2, 'Builder', 'Keep the momentum going with consistent daily progress.', 300, 'Silver Badge', 2),
  (3, 'Achiever', 'Turn consistency into real, visible business results.', 500, 'Gold Badge', 3),
  (4, 'Momentum Maker', 'Push through the mid-program grind and compound your gains.', 800, 'Platinum Badge', 4),
  (5, 'Elite Performer', 'Join the top tier of consistently high-performing members.', 1200, 'Elite Badge', 5),
  (6, 'Legend', 'Complete the full journey and cement your status as a TBT Legend.', 2000, 'Legend Trophy', 6)
ON CONFLICT (level_number) DO NOTHING;
