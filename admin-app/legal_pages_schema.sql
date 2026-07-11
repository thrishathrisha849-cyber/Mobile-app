-- SQL Schema for Legal Pages (Terms & Conditions, Privacy Policy) Management
-- Run this in your Supabase SQL Editor to create the table

CREATE TABLE IF NOT EXISTS legal_pages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  type VARCHAR(20) NOT NULL UNIQUE CHECK (type IN ('terms', 'privacy')),
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  status VARCHAR(50) DEFAULT 'active', -- 'active' or 'inactive'
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_legal_pages_type ON legal_pages(type);

-- Enable Row Level Security (RLS)
ALTER TABLE legal_pages ENABLE ROW LEVEL SECURITY;

-- Public read access (mobile app reads active rows)
CREATE POLICY "Allow public read access" ON legal_pages FOR SELECT USING (true);

-- Allow all operations (admin portal)
CREATE POLICY "Allow all access for admin portal" ON legal_pages FOR ALL USING (true) WITH CHECK (true);

-- Seed default records so the mobile app and admin panel have content immediately.
-- Content mirrors the app's original Terms/Privacy copy; '## ' marks a section
-- heading and '- ' marks a bullet point (parsed by the mobile app and shown
-- as plain formatted text in the admin textarea).
INSERT INTO legal_pages (type, title, content, status, sort_order) VALUES
  (
    'terms',
    'Terms & Conditions',
    '## 1. Acceptance of Terms
By accessing or using the Tamil Business Tribe app, you agree to comply with and be bound by these Terms and Conditions. If you do not agree, please do not use our services.

## 2. Member Account & Security
You are responsible for keeping your credentials confidential. Any activity taking place on your registered profile is your exclusive liability. Please inform support immediately of any unauthorized access.

## 3. Community Guidelines
The Tamil Business Tribe thrives on cooperation, respect, and mutual business growth.
- Do not post spam or offensive content
- Do not violate the privacy of other members
- Infringing items will be removed without notice

## 4. Premium Services & Fees
Elite memberships, ticket bookings, and special mentor workshops are subject to payments. All fees are non-refundable except as explicitly specified in our cancellation terms.',
    'active',
    1
  ),
  (
    'privacy',
    'Privacy Policy',
    '## 1. Information We Collect
We collect business information, company metadata, profile photo references, and contact details during elite registration to facilitate community interactions and networking metrics.

## 2. How We Use Data
Your information is utilized to maintain your virtual membership card, custom badge rewards, and timeline statistics. We do not sell or leak member records to third-party databases.

## 3. Storage & Security
We employ secure encryption standards to store credentials and transaction data. Only approved TBT mentors have access to metrics for accountability and task evaluation.

## 4. Your Privacy Rights
- Restrict details shown to public members via "Public Visibility" in settings
- Request account deletion by emailing support',
    'active',
    2
  )
ON CONFLICT (type) DO NOTHING;
