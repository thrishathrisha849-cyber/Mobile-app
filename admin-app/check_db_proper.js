const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;

console.log("Supabase URL:", supabaseUrl);

const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
  try {
    const { data: habits, error: habitsError } = await supabase.from('habits').select('*').limit(1);
    if (habitsError) {
      console.log("habits table check: Error =", habitsError.message);
    } else {
      console.log("habits table check: OK, Data =", habits);
    }
  } catch (err) {
    console.error("habits check failed:", err);
  }

  try {
    const { data: buttons, error: buttonsError } = await supabase.from('buttons_config').select('*').limit(1);
    if (buttonsError) {
      console.log("buttons_config table check: Error =", buttonsError.message);
    } else {
      console.log("buttons_config table check: OK, Data =", buttons);
    }
  } catch (err) {
    console.error("buttons_config check failed:", err);
  }
}

check();
