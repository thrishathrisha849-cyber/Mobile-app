-- Drop existing tables if they exist
DROP TABLE IF EXISTS habits;
DROP TABLE IF EXISTS buttons_config;

-- 1. Create habits table
CREATE TABLE habits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  icon VARCHAR(100) DEFAULT 'fa-sun',
  raw_question TEXT NOT NULL,
  highlight_word VARCHAR(255) DEFAULT '',
  subtitle VARCHAR(255) DEFAULT '',
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create buttons_config table
CREATE TABLE buttons_config (
  id VARCHAR(50) PRIMARY KEY DEFAULT 'default',
  yes_label VARCHAR(100) DEFAULT 'Yes',
  not_yet_label VARCHAR(100) DEFAULT 'Not Yet',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Enable RLS on tables
ALTER TABLE habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE buttons_config ENABLE ROW LEVEL SECURITY;

-- 4. Create policies for habits
CREATE POLICY "Allow public read access for habits" ON habits
  FOR SELECT USING (true);

CREATE POLICY "Allow all access for admin on habits" ON habits
  FOR ALL USING (true) WITH CHECK (true);

-- 5. Create policies for buttons_config
CREATE POLICY "Allow public read access for buttons_config" ON buttons_config
  FOR SELECT USING (true);

CREATE POLICY "Allow all access for admin on buttons_config" ON buttons_config
  FOR ALL USING (true) WITH CHECK (true);

-- 6. Insert initial habits data matching habits.json
INSERT INTO habits (icon, raw_question, highlight_word, subtitle, sort_order)
VALUES 
  ('fa-sun', 'Did you finish this new habit?', 'new habit', 'Start your day right.', 0),
  ('fa-sun', 'Did you finish this new habit?', 'new habit', 'Start your day right.', 1),
  ('fa-sun', 'Did you finish this new habit?', 'new habit', 'Start your day right.', 2);

-- 7. Insert initial buttons_config
INSERT INTO buttons_config (id, yes_label, not_yet_label)
VALUES ('default', 'Yes', 'Not Yet');
