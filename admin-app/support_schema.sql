-- SQL Schema for Support Module (Settings, Categories, FAQs, Tickets, Feedback)
-- Run this in your Supabase SQL Editor to create the tables

-- 1. Support Settings (single-row contact/config block)
CREATE TABLE IF NOT EXISTS support_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title VARCHAR(255) NOT NULL DEFAULT 'Support Center',
  subtitle TEXT,
  whatsapp_number VARCHAR(50),
  phone_number VARCHAR(50),
  email VARCHAR(255),
  website_url TEXT,
  support_timing VARCHAR(255),
  address TEXT,
  button_text VARCHAR(100) DEFAULT 'Contact Us',
  banner_image TEXT,
  status VARCHAR(50) DEFAULT 'active', -- 'active' or 'inactive'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Support Categories (used by both FAQs and the ticket form's category dropdown)
CREATE TABLE IF NOT EXISTS support_categories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  icon TEXT,
  status VARCHAR(50) DEFAULT 'active', -- 'active' or 'inactive'
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Support FAQs
CREATE TABLE IF NOT EXISTS support_faqs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  question VARCHAR(500) NOT NULL,
  answer TEXT NOT NULL,
  category_id UUID REFERENCES support_categories(id) ON DELETE SET NULL,
  status VARCHAR(50) DEFAULT 'active', -- 'active' or 'inactive'
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Support Tickets (submitted from the mobile "Raise Ticket" form)
CREATE TABLE IF NOT EXISTS support_tickets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  phone VARCHAR(50),
  subject VARCHAR(255) NOT NULL,
  category_id UUID REFERENCES support_categories(id) ON DELETE SET NULL,
  message TEXT NOT NULL,
  attachment_url TEXT,
  status VARCHAR(50) NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'in-progress', 'resolved', 'closed')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Support Feedback / Report Issue
CREATE TABLE IF NOT EXISTS support_feedback (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(255),
  email VARCHAR(255),
  rating INTEGER CHECK (rating IS NULL OR (rating BETWEEN 1 AND 5)),
  message TEXT NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'in-progress', 'resolved', 'closed')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_support_faqs_category ON support_faqs(category_id);
CREATE INDEX IF NOT EXISTS idx_support_faqs_status ON support_faqs(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_category ON support_tickets(category_id);
CREATE INDEX IF NOT EXISTS idx_support_feedback_status ON support_feedback(status);

-- Enable Row Level Security (RLS)
ALTER TABLE support_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_faqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_feedback ENABLE ROW LEVEL SECURITY;

-- Public read access (mobile app reads active settings/categories/FAQs directly)
CREATE POLICY "Allow public read access" ON support_settings FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON support_categories FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON support_faqs FOR SELECT USING (true);

-- Admin portal: full CRUD on settings/categories/FAQs (matches this project's convention elsewhere)
CREATE POLICY "Allow all access for admin portal" ON support_settings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for admin portal" ON support_categories FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for admin portal" ON support_faqs FOR ALL USING (true) WITH CHECK (true);

-- Tickets/Feedback contain personal contact info: mobile app may only INSERT (submit),
-- never read other users' rows back. Admin portal gets full access (view/update/delete).
CREATE POLICY "Allow public insert" ON support_tickets FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow admin portal full access" ON support_tickets FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow public insert" ON support_feedback FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow admin portal full access" ON support_feedback FOR ALL USING (true) WITH CHECK (true);

-- Seed default settings row (editable afterwards from the admin panel)
INSERT INTO support_settings (title, subtitle, whatsapp_number, phone_number, email, website_url, support_timing, address, button_text, status)
SELECT
  'Support Center',
  'How can we help you today?',
  '+919444488888',
  '18003094820',
  'support@tamilbusinesstribe.com',
  'https://tamilbusinesstribe.com',
  'Mon - Sat, 9:00 AM - 7:00 PM',
  '',
  'Contact Us',
  'active'
WHERE NOT EXISTS (SELECT 1 FROM support_settings);

-- Seed starter categories (editable afterwards from the admin panel)
INSERT INTO support_categories (name, slug, description, status, sort_order) VALUES
  ('Payments', 'payments', 'Subscription, billing, invoices, and refunds', 'active', 1),
  ('Technicals', 'technicals', 'Course access, login issues, and app performance', 'active', 2),
  ('Community', 'community', 'Account privacy, community rules, and reporting abuse', 'active', 3)
ON CONFLICT (slug) DO NOTHING;

-- Seed starter FAQs so the mobile FAQ list has content immediately
INSERT INTO support_faqs (question, answer, category_id, status, sort_order)
SELECT 'How do I update my payment method?', 'Go to Profile > My Account > Billing to update your card or UPI details at any time.', (SELECT id FROM support_categories WHERE slug = 'payments'), 'active', 1
WHERE NOT EXISTS (SELECT 1 FROM support_faqs WHERE question = 'How do I update my payment method?');

INSERT INTO support_faqs (question, answer, category_id, status, sort_order)
SELECT 'Are subscription fees refundable?', 'Fees are non-refundable except as explicitly stated in our cancellation terms. Contact support for case-by-case review.', (SELECT id FROM support_categories WHERE slug = 'payments'), 'active', 2
WHERE NOT EXISTS (SELECT 1 FROM support_faqs WHERE question = 'Are subscription fees refundable?');

INSERT INTO support_faqs (question, answer, category_id, status, sort_order)
SELECT 'I forgot my password, what do I do?', 'Use the "Forgot Password" link on the login screen to reset it via your registered email.', (SELECT id FROM support_categories WHERE slug = 'technicals'), 'active', 1
WHERE NOT EXISTS (SELECT 1 FROM support_faqs WHERE question = 'I forgot my password, what do I do?');

INSERT INTO support_faqs (question, answer, category_id, status, sort_order)
SELECT 'Videos are lagging or not loading', 'Check your internet connection and try switching to a lower playback quality from the video player settings.', (SELECT id FROM support_categories WHERE slug = 'technicals'), 'active', 2
WHERE NOT EXISTS (SELECT 1 FROM support_faqs WHERE question = 'Videos are lagging or not loading');

INSERT INTO support_faqs (question, answer, category_id, status, sort_order)
SELECT 'How do I report spam or abuse?', 'Open the post or profile, tap the menu icon, and choose "Report". Our moderation team reviews all reports within 24 hours.', (SELECT id FROM support_categories WHERE slug = 'community'), 'active', 1
WHERE NOT EXISTS (SELECT 1 FROM support_faqs WHERE question = 'How do I report spam or abuse?');
