-- SQL Schema for AI Content Creation Assistant ("Content Buddy AI")
-- Run this in your Supabase SQL Editor to create the tables
-- See specs/001-ai-content-assistant/plan.md §4 for design rationale.

-- 1. Conversations
CREATE TABLE IF NOT EXISTS ai_conversations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT 'New Conversation',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Messages (ordered log of a conversation)
CREATE TABLE IF NOT EXISTS ai_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
  sender TEXT NOT NULL CHECK (sender IN ('user', 'assistant')),
  message TEXT NOT NULL,
  input_type TEXT NOT NULL CHECK (input_type IN ('text', 'voice', 'image')),
  image_url TEXT,
  content_type TEXT,
  language TEXT,
  tone TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Saved Content
CREATE TABLE IF NOT EXISTS saved_ai_content (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id TEXT NOT NULL,
  conversation_id UUID REFERENCES ai_conversations(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'other'
    CHECK (category IN ('social_media', 'advertisement', 'business', 'personal', 'video_script', 'email', 'other')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Usage counters (persistent fallback; v1 enforcement is in-memory in usageLimitService.js —
-- see plan.md §2/§5. Kept here for a future persistent/multi-instance upgrade.)
CREATE TABLE IF NOT EXISTS ai_usage_counters (
  user_id TEXT NOT NULL,
  window_type TEXT NOT NULL CHECK (window_type IN ('day', 'minute')),
  window_start TIMESTAMP WITH TIME ZONE NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, window_type, window_start)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user ON ai_conversations(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation ON ai_messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_saved_ai_content_user ON saved_ai_content(user_id, created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_ai_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_usage_counters ENABLE ROW LEVEL SECURITY;

-- This app has no Supabase Auth session (anonymous per-device user_id only — see spec.md §0),
-- so RLS cannot be keyed on auth.uid(). All access goes through the admin-app backend using the
-- service-role key (which bypasses RLS); ownership checks (a user can only see their own rows)
-- are enforced in application code (conversationService.js / savedContentService.js), matching
-- the same fully-permissive-RLS-plus-app-layer-checks convention already used by podcast_schema.sql.
CREATE POLICY "Allow all access for backend service role" ON ai_conversations FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for backend service role" ON ai_messages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for backend service role" ON saved_ai_content FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for backend service role" ON ai_usage_counters FOR ALL USING (true) WITH CHECK (true);
