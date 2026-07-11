-- SQL Schema for Home Page Carousel/Banner Management
-- Run this in your Supabase SQL Editor to create the table

CREATE TABLE IF NOT EXISTS home_carousel (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  subtitle TEXT,
  description TEXT,
  media_type VARCHAR(50) DEFAULT 'image', -- 'image' or 'video'
  media_url TEXT NOT NULL,
  thumbnail_url TEXT,
  button_text VARCHAR(100),
  button_link TEXT,
  sort_order INTEGER DEFAULT 0,
  status VARCHAR(50) DEFAULT 'active', -- 'active' or 'inactive'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Enable Row Level Security (RLS)
ALTER TABLE home_carousel ENABLE ROW LEVEL SECURITY;

-- Create public read policy (Allow anonymous read)
CREATE POLICY "Allow public read access" ON home_carousel
  FOR SELECT USING (true);

-- Create public insert/update/delete policy (Allow all operations for now, or adapt as needed)
CREATE POLICY "Allow all access for admin portal" ON home_carousel
  FOR ALL USING (true) WITH CHECK (true);
