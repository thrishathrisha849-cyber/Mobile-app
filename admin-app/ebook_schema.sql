-- Drop existing policies first
DROP POLICY IF EXISTS "Allow public read access" ON ebook_categories;
DROP POLICY IF EXISTS "Allow public read access" ON ebooks;
DROP POLICY IF EXISTS "Allow public read access" ON ebook_progress;
DROP POLICY IF EXISTS "Allow public read access" ON ebook_bookmarks;
DROP POLICY IF EXISTS "Allow public read access" ON ebook_banners;

DROP POLICY IF EXISTS "Allow all access for admin portal" ON ebook_categories;
DROP POLICY IF EXISTS "Allow all access for admin portal" ON ebooks;
DROP POLICY IF EXISTS "Allow all access for admin portal" ON ebook_progress;
DROP POLICY IF EXISTS "Allow all access for admin portal" ON ebook_bookmarks;
DROP POLICY IF EXISTS "Allow all access for admin portal" ON ebook_banners;

-- Public read access
CREATE POLICY "Allow public read access" ON ebook_categories FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON ebooks FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON ebook_progress FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON ebook_bookmarks FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON ebook_banners FOR SELECT USING (true);

-- Allow all operations
CREATE POLICY "Allow all access for admin portal" ON ebook_categories FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for admin portal" ON ebooks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for admin portal" ON ebook_progress FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for admin portal" ON ebook_bookmarks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for admin portal" ON ebook_banners FOR ALL USING (true) WITH CHECK (true);