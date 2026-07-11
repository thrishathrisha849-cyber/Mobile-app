-- SQL Schema for Podcast Management (Categories, Series, Episodes, Progress)
-- Run this in your Supabase SQL Editor to create the tables

-- 1. Categories
CREATE TABLE IF NOT EXISTS podcast_categories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL UNIQUE,
  status VARCHAR(50) DEFAULT 'active', -- 'active' or 'inactive'
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Series
CREATE TABLE IF NOT EXISTS podcast_series (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  cover_image TEXT,
  status VARCHAR(50) DEFAULT 'active', -- 'active' or 'inactive'
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Episodes
CREATE TABLE IF NOT EXISTS podcast_episodes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  category_id UUID REFERENCES podcast_categories(id) ON DELETE SET NULL,
  series_id UUID REFERENCES podcast_series(id) ON DELETE SET NULL,
  cover_image TEXT,
  audio_url TEXT NOT NULL,
  duration_seconds INTEGER DEFAULT 0,
  speaker VARCHAR(255),
  tags TEXT[] DEFAULT '{}',
  is_featured BOOLEAN DEFAULT false,
  status VARCHAR(50) DEFAULT 'active', -- 'active' or 'inactive'
  publish_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Listening Progress (anonymous per-device user id, no auth system in this app)
CREATE TABLE IF NOT EXISTS podcast_progress (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id TEXT NOT NULL,
  episode_id UUID REFERENCES podcast_episodes(id) ON DELETE CASCADE,
  current_position_seconds INTEGER DEFAULT 0,
  total_duration_seconds INTEGER DEFAULT 0,
  completed BOOLEAN DEFAULT false,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (user_id, episode_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_podcast_episodes_category ON podcast_episodes(category_id);
CREATE INDEX IF NOT EXISTS idx_podcast_episodes_series ON podcast_episodes(series_id);
CREATE INDEX IF NOT EXISTS idx_podcast_episodes_status ON podcast_episodes(status);
CREATE INDEX IF NOT EXISTS idx_podcast_progress_user ON podcast_progress(user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE podcast_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE podcast_series ENABLE ROW LEVEL SECURITY;
ALTER TABLE podcast_episodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE podcast_progress ENABLE ROW LEVEL SECURITY;

-- Public read access (mobile app reads active rows)
CREATE POLICY "Allow public read access" ON podcast_categories FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON podcast_series FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON podcast_episodes FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON podcast_progress FOR SELECT USING (true);

-- Allow all operations (admin portal + anonymous progress writes, matches home_carousel convention)
CREATE POLICY "Allow all access for admin portal" ON podcast_categories FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for admin portal" ON podcast_series FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for admin portal" ON podcast_episodes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for admin portal" ON podcast_progress FOR ALL USING (true) WITH CHECK (true);

-- Seed starter categories (editable afterwards from the admin panel)
INSERT INTO podcast_categories (name, slug, status, sort_order) VALUES
  ('Mindset', 'mindset', 'active', 1),
  ('Business', 'business', 'active', 2),
  ('Growth', 'growth', 'active', 3),
  ('Leadership', 'leadership', 'active', 4)
ON CONFLICT (slug) DO NOTHING;
