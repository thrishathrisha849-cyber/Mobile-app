-- SQL Schema for the TBT Points educational task path
-- Run this in your Supabase SQL Editor to create the tables

-- 1. Task Definitions (static config, admin-editable content — not per-user).
-- Content below is carried over from the existing local 90-Day Task flow
-- (see lib/task.dart's seeded _tasks list) so the real task titles/points
-- already in use are preserved, just made backend-driven.
CREATE TABLE IF NOT EXISTS tbt_tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  task_order INTEGER NOT NULL UNIQUE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  required_action VARCHAR(255),
  reward_points INTEGER NOT NULL DEFAULT 0,
  status VARCHAR(50) DEFAULT 'active', -- 'active' or 'inactive'
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Task Completions (anonymous per-device user id, no auth system in this app)
CREATE TABLE IF NOT EXISTS tbt_task_completions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id TEXT NOT NULL,
  task_id UUID REFERENCES tbt_tasks(id) ON DELETE CASCADE,
  completed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (user_id, task_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tbt_tasks_order ON tbt_tasks(task_order);
CREATE INDEX IF NOT EXISTS idx_tbt_task_completions_user ON tbt_task_completions(user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE tbt_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbt_task_completions ENABLE ROW LEVEL SECURITY;

-- Public read access (mobile app reads active rows / its own completions)
-- Policies are dropped first so this script is safe to re-run (CREATE
-- POLICY has no IF NOT EXISTS clause, unlike CREATE TABLE above — matches
-- the DROP/CREATE POLICY convention already used in home_carousel.sql).
DROP POLICY IF EXISTS "Allow public read access" ON tbt_tasks;
DROP POLICY IF EXISTS "Allow public read access" ON tbt_task_completions;
CREATE POLICY "Allow public read access" ON tbt_tasks FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON tbt_task_completions FOR SELECT USING (true);

-- Allow all operations (admin portal + anonymous completion writes, matches tbt_activity_log convention)
DROP POLICY IF EXISTS "Allow all access for admin portal" ON tbt_tasks;
DROP POLICY IF EXISTS "Allow all access for admin portal" ON tbt_task_completions;
CREATE POLICY "Allow all access for admin portal" ON tbt_tasks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for admin portal" ON tbt_task_completions FOR ALL USING (true) WITH CHECK (true);

-- Seed starter tasks (editable afterwards from the admin panel / SQL) —
-- content carried over from the existing local 90-Day Task flow.
INSERT INTO tbt_tasks (task_order, title, description, required_action, reward_points, status, sort_order) VALUES
  (1, 'Attend Onboarding Call',
     'Attend the live onboarding kick-off session or watch the video replay to align on the core 90-day execution framework.',
     'Complete your onboarding profile and join the community groups.', 250, 'active', 1),
  (2, 'Define Your Customer Segment',
     'Define the high-value target audience for your product. Focus on psychological triggers, spending capacity, and pain points that align with your unique value proposition.',
     'Fill in the Customer Segment section of your Business Model Canvas.', 500, 'active', 2),
  (3, 'Conduct 5 Customer Interviews',
     'Validate the core problem statement with potential target clients and record feedback. Gather qualitative data regarding their constraints.',
     'Complete 5 customer interviews and summarize the feedback.', 300, 'active', 3),
  (4, 'Launch Landing Page MVP',
     'Create a simple landing page showcasing the offer value proposition and signup form. Collect early subscriber signups.',
     'Publish your landing page and share the link.', 400, 'active', 4),
  (5, 'Submit Step 4 Milestone',
     'Consolidate all learnings, customer interviews, and MVP landing page analytics into the final execution summary.',
     'Submit your consolidated milestone summary.', 500, 'active', 5)
ON CONFLICT (task_order) DO NOTHING;
