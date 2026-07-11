const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
  const { data, error } = await supabase.from('posts').select('*').limit(1);
  if (error) {
    console.error('Error fetching post:', error);
  } else {
    console.log('Post columns:', data[0] ? Object.keys(data[0]) : 'No posts in table');
    console.log('Sample post:', data[0]);
  }
}
check();
