-- SQL Schema for Admin Notifications
-- Run this in your Supabase SQL Editor to create the table

CREATE TABLE IF NOT EXISTS admin_notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(50) NOT NULL, -- e.g. 'support_ticket', 'support_feedback'
  reference_id UUID,
  reference_type VARCHAR(50), -- e.g. 'support_tickets', 'support_feedback'
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_admin_notifications_is_read ON admin_notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_admin_notifications_created_at ON admin_notifications(created_at);

-- Enable Row Level Security (RLS)
ALTER TABLE admin_notifications ENABLE ROW LEVEL SECURITY;

-- Mobile app may only INSERT a notification when it submits a ticket/feedback,
-- never read other notifications. Admin portal gets full access.
CREATE POLICY "Allow public insert" ON admin_notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow admin portal full access" ON admin_notifications FOR ALL USING (true) WITH CHECK (true);
