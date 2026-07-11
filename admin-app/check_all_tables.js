const { createClient } = require('@supabase/supabase-js');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("Missing environment variables in .env file");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
  const tables = [
    'posts',
    'home_carousel',
    'podcast_categories',
    'podcast_series',
    'podcast_episodes',
    'ebook_categories',
    'ebooks',
    'ebook_banners',
    'support_faq',
    'support_faq_categories',
    'support_helpline_settings',
    'legal_pages'
  ];

  for (const t of tables) {
    try {
      const { count, error } = await supabase
        .from(t)
        .select('*', { count: 'exact', head: true });
      if (error) {
        console.log(`Table "${t}": Error -> ${error.message}`);
      } else {
        console.log(`Table "${t}": OK, Row Count = ${count}`);
      }
    } catch (e) {
      console.log(`Table "${t}": Exception -> ${e.message}`);
    }
  }
}

check();
