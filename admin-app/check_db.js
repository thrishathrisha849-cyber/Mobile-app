const { createClient } = require('@supabase/supabase-js');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../../../Downloads/moble app/admin-app/.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;

console.log("Supabase URL:", supabaseUrl);

const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
  try {
    const { data: habits, error: habitsError } = await supabase.from('habits').select('*').limit(1);
    console.log("habits table check: Error =", habitsError?.message, "Data =", habits);
  } catch (err) {
    console.error("habits check failed:", err);
  }

  try {
    const { data: buttons, error: buttonsError } = await supabase.from('buttons_config').select('*').limit(1);
    console.log("buttons_config table check: Error =", buttonsError?.message, "Data =", buttons);
  } catch (err) {
    console.error("buttons_config check failed:", err);
  }
  
  // Also print all table schemas/information we can find by query
  try {
    const { data, error } = await supabase.rpc('get_tables');
    console.log("RPC get_tables:", error?.message, data);
  } catch (e) {}
}

check();
