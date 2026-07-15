const express = require('express');
const { createClient } = require('@supabase/supabase-js');
const path = require('path');
const multer = require('multer');
require('dotenv').config();

const app = express();
const upload = multer({ storage: multer.memoryStorage() });
const PORT = process.env.PORT || 5000;

// Initialize Supabase Client
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;

if (!supabaseUrl || !supabaseKey || supabaseUrl.includes('your-project-id')) {
  console.warn('WARNING: Supabase URL or Key is not configured correctly in .env');
}

const supabase = createClient(supabaseUrl || 'https://placeholder.supabase.co', supabaseKey || 'placeholder');

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// CORS and Request Logger Middleware
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Authorization");
  res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  console.log(`[SERVER LOG] ${new Date().toISOString()} - ${req.method} ${req.url}`);
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

// API Routes

// AI Content Creation Assistant ("Content Buddy AI") — see specs/001-ai-content-assistant/
app.use('/api/ai', require('./routes/ai'));

// Get all posts
app.get('/api/posts', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('posts')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create a post
app.post('/api/posts', async (req, res) => {
  try {
    const postData = req.body;
    if (postData.is_approved === undefined) {
      postData.is_approved = true; // Fallback default
    }
    const { data, error } = await supabase
      .from('posts')
      .insert([postData])
      .select();

    if (error) throw error;
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update a post
app.put('/api/posts/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    const { data, error } = await supabase
      .from('posts')
      .update(updateData)
      .eq('id', id)
      .select();

    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Approve a post
app.put('/api/posts/:id/approve', async (req, res) => {
  try {
    const { id } = req.params;
    const { data, error } = await supabase
      .from('posts')
      .update({ is_approved: true })
      .eq('id', id)
      .select();

    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete a post
app.delete('/api/posts/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabase
      .from('posts')
      .delete()
      .eq('id', id);

    if (error) throw error;
    res.json({ message: 'Post deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Send a mobile app notification for a community post (admin-triggered broadcast)
app.post('/api/admin/community/posts/:id/send-notification', async (req, res) => {
  try {
    const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!UUID_RE.test(req.params.id)) {
      return res.status(404).json({ error: 'Post not found' });
    }

    const { data: post, error: fetchError } = await supabase
      .from('posts')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (fetchError) throw fetchError;
    if (!post) return res.status(404).json({ error: 'Post not found' });
    // Mirrors the admin UI's own "is this post approved" check (see
    // isPostApproved in public/index.html) so the two never disagree:
    // is_approved is the primary field, with status === 'approved' as a
    // fallback for any row where only the status column was set.
    const isApproved = post.is_approved === true || post.status === 'approved';
    if (!isApproved) {
      return res.status(400).json({ error: 'Approve/publish this post before sending a notification for it.' });
    }

    const title = post.name ? `New Community Post by ${post.name}` : 'New Community Post';
    const content = (post.content || '').trim();
    const message = content.length > 140 ? `${content.slice(0, 140)}...` : (content || 'Check out the latest update in the community feed.');

    const { data, error } = await supabase
      .from('mobile_notifications')
      .insert([{
        title,
        message,
        type: 'community_post',
        reference_id: post.id,
        reference_type: 'community_feed',
      }])
      .select();
    if (error) throw error;
    res.status(201).json({ success: true, notification: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET all carousel items
app.get('/api/home_carousel', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('home_carousel')
      .select('*')
      .order('sort_order', { ascending: true });

    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// CREATE a carousel item
app.post('/api/home_carousel', async (req, res) => {
  try {
    const itemData = req.body;
    const { data, error } = await supabase
      .from('home_carousel')
      .insert([itemData])
      .select();

    if (error) throw error;
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// UPDATE a carousel item
app.put('/api/home_carousel/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    const { data, error } = await supabase
      .from('home_carousel')
      .update(updateData)
      .eq('id', id)
      .select();

    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE a carousel item
app.delete('/api/home_carousel/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabase
      .from('home_carousel')
      .delete()
      .eq('id', id);

    if (error) throw error;
    res.json({ message: 'Carousel item deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// FILE UPLOAD ENDPOINT
app.post('/api/upload', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }
    const file = req.file;
    const fileExtension = path.extname(file.originalname);
    const fileName = `${Date.now()}-${Math.random().toString(36).substring(7)}${fileExtension}`;
    const folder = (req.body.folder || '').replace(/^\/+|\/+$/g, '');
    const storagePath = folder ? `${folder}/${fileName}` : fileName;

    const { data, error } = await supabase.storage
      .from('community')
      .upload(storagePath, file.buffer, {
        contentType: file.mimetype,
        cacheControl: '3600',
        upsert: false
      });

    if (error) throw error;

    const { data: publicData } = supabase.storage
      .from('community')
      .getPublicUrl(storagePath);

    res.json({ url: publicData.publicUrl });
  } catch (error) {
    console.error('Upload API error:', error);
    res.status(500).json({ error: error.message });
  }
});

// =====================================================================
// PODCAST MANAGEMENT API
// =====================================================================

const PODCAST_EPISODE_SELECT = '*, podcast_categories(id, name, slug), podcast_series(id, title, slug)';

// ---- Admin CRUD: Categories ----
app.get('/api/podcast_categories', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('podcast_categories')
      .select('*')
      .order('sort_order', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/podcast_categories', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('podcast_categories')
      .insert([req.body])
      .select();
    if (error) throw error;
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/podcast_categories/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('podcast_categories')
      .update(req.body)
      .eq('id', req.params.id)
      .select();
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/podcast_categories/:id', async (req, res) => {
  try {
    const { error } = await supabase
      .from('podcast_categories')
      .delete()
      .eq('id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Category deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---- Admin CRUD: Series ----
app.get('/api/podcast_series', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('podcast_series')
      .select('*')
      .order('sort_order', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/podcast_series', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('podcast_series')
      .insert([req.body])
      .select();
    if (error) throw error;
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/podcast_series/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('podcast_series')
      .update(req.body)
      .eq('id', req.params.id)
      .select();
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/podcast_series/:id', async (req, res) => {
  try {
    const { error } = await supabase
      .from('podcast_series')
      .delete()
      .eq('id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Series deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Send a mobile app notification for a podcast series (admin-triggered broadcast)
app.post('/api/admin/podcast/series/:id/send-notification', async (req, res) => {
  try {
    const { data: series, error: fetchError } = await supabase
      .from('podcast_series')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (fetchError) throw fetchError;
    if (!series) return res.status(404).json({ error: 'Series not found' });
    if (series.status !== 'active') {
      return res.status(400).json({ error: 'Activate/publish this series before sending a notification for it.' });
    }

    const title = series.title || 'New Podcast Series';
    const description = (series.description || '').trim();
    const message = description.length > 140 ? `${description.slice(0, 140)}...` : (description || 'A new series is now available.');

    const { data, error } = await supabase
      .from('mobile_notifications')
      .insert([{
        title,
        message,
        type: 'podcast_series',
        reference_id: series.id,
        reference_type: 'podcast_series',
      }])
      .select();
    if (error) throw error;
    res.status(201).json({ success: true, notification: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ---- Admin CRUD: Episodes ----
app.get('/api/podcast_episodes', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('podcast_episodes')
      .select(PODCAST_EPISODE_SELECT)
      .order('sort_order', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/podcast_episodes', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('podcast_episodes')
      .insert([req.body])
      .select(PODCAST_EPISODE_SELECT);
    if (error) throw error;
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/podcast_episodes/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('podcast_episodes')
      .update(req.body)
      .eq('id', req.params.id)
      .select(PODCAST_EPISODE_SELECT);
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/podcast_episodes/:id/toggle-status', async (req, res) => {
  try {
    const { status } = req.body;
    const { data, error } = await supabase
      .from('podcast_episodes')
      .update({ status })
      .eq('id', req.params.id)
      .select(PODCAST_EPISODE_SELECT);
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/podcast_episodes/:id', async (req, res) => {
  try {
    const { error } = await supabase
      .from('podcast_episodes')
      .delete()
      .eq('id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Episode deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Send a mobile app notification for a podcast episode (admin-triggered broadcast)
app.post('/api/admin/podcast/episodes/:id/send-notification', async (req, res) => {
  try {
    const { data: episode, error: fetchError } = await supabase
      .from('podcast_episodes')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (fetchError) throw fetchError;
    if (!episode) return res.status(404).json({ error: 'Episode not found' });
    if (episode.status !== 'active') {
      return res.status(400).json({ error: 'Activate/publish this episode before sending a notification for it.' });
    }

    const title = episode.title || 'New Podcast Episode';
    const description = (episode.description || '').trim();
    const message = description.length > 140 ? `${description.slice(0, 140)}...` : (description || 'A new episode is now available.');

    const { data, error } = await supabase
      .from('mobile_notifications')
      .insert([{
        title,
        message,
        type: 'podcast_episode',
        reference_id: episode.id,
        reference_type: 'podcast_episode',
      }])
      .select();
    if (error) throw error;
    res.status(201).json({ success: true, notification: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ---- Admin Dashboard ----
app.get('/api/podcast_dashboard', async (req, res) => {
  try {
    const [totalEpisodes, activeEpisodes, inactiveEpisodes, totalCategories, totalSeries] = await Promise.all([
      supabase.from('podcast_episodes').select('*', { count: 'exact', head: true }),
      supabase.from('podcast_episodes').select('*', { count: 'exact', head: true }).eq('status', 'active'),
      supabase.from('podcast_episodes').select('*', { count: 'exact', head: true }).eq('status', 'inactive'),
      supabase.from('podcast_categories').select('*', { count: 'exact', head: true }),
      supabase.from('podcast_series').select('*', { count: 'exact', head: true }),
    ]);

    res.json({
      totalEpisodes: totalEpisodes.count || 0,
      activeEpisodes: activeEpisodes.count || 0,
      inactiveEpisodes: inactiveEpisodes.count || 0,
      totalCategories: totalCategories.count || 0,
      totalSeries: totalSeries.count || 0,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---- Public/Mobile-facing endpoints ----

// Categories (active only)
app.get('/api/podcast/categories', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('podcast_categories')
      .select('*')
      .eq('status', 'active')
      .order('sort_order', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Episodes list with category slug filter, search, pagination
app.get('/api/podcast/episodes', async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page) || 1, 1);
    const limit = Math.min(Math.max(parseInt(req.query.limit) || 10, 1), 100);
    const from = (page - 1) * limit;
    const to = from + limit - 1;

    let query = supabase
      .from('podcast_episodes')
      .select(PODCAST_EPISODE_SELECT, { count: 'exact' })
      .eq('status', 'active');

    if (req.query.category && req.query.category !== 'All' && req.query.category !== 'all') {
      const { data: cat, error: catError } = await supabase
        .from('podcast_categories')
        .select('id')
        .eq('slug', req.query.category)
        .maybeSingle();
      if (catError) throw catError;
      if (cat) {
        query = query.eq('category_id', cat.id);
      } else {
        return res.json({ data: [], page, limit, total: 0 });
      }
    }

    if (req.query.search) {
      query = query.ilike('title', `%${req.query.search}%`);
    }

    const { data, error, count } = await query
      .order('sort_order', { ascending: true })
      .order('publish_date', { ascending: false })
      .range(from, to);

    if (error) throw error;
    res.json({ data, page, limit, total: count || 0 });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Single episode
app.get('/api/podcast/episodes/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('podcast_episodes')
      .select(PODCAST_EPISODE_SELECT)
      .eq('id', req.params.id)
      .eq('status', 'active')
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ error: 'Episode not found' });
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Featured series (with episode counts)
app.get('/api/podcast/featured-series', async (req, res) => {
  try {
    const { data: seriesList, error } = await supabase
      .from('podcast_series')
      .select('*')
      .eq('status', 'active')
      .order('sort_order', { ascending: true });
    if (error) throw error;

    const withCounts = await Promise.all(seriesList.map(async (series) => {
      const { count } = await supabase
        .from('podcast_episodes')
        .select('*', { count: 'exact', head: true })
        .eq('series_id', series.id)
        .eq('status', 'active');
      return { ...series, episodes_count: count || 0 };
    }));

    res.json(withCounts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Series detail + its episodes
app.get('/api/podcast/series/:id', async (req, res) => {
  try {
    const { data: series, error: seriesError } = await supabase
      .from('podcast_series')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (seriesError) throw seriesError;
    if (!series) return res.status(404).json({ error: 'Series not found' });

    const { data: episodes, error: episodesError } = await supabase
      .from('podcast_episodes')
      .select(PODCAST_EPISODE_SELECT)
      .eq('series_id', req.params.id)
      .eq('status', 'active')
      .order('sort_order', { ascending: true });
    if (episodesError) throw episodesError;

    res.json({ ...series, episodes });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Continue listening (in-progress, not completed) for a given anonymous user id
app.get('/api/podcast/continue-listening', async (req, res) => {
  try {
    const { user_id } = req.query;
    if (!user_id) return res.status(400).json({ error: 'user_id is required' });

    const { data, error } = await supabase
      .from('podcast_progress')
      .select(`*, podcast_episodes!inner(${PODCAST_EPISODE_SELECT})`)
      .eq('user_id', user_id)
      .eq('completed', false)
      .gt('current_position_seconds', 0)
      .eq('podcast_episodes.status', 'active')
      .order('updated_at', { ascending: false });

    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Save/update playback progress (upsert)
app.post('/api/podcast/progress', async (req, res) => {
  try {
    const { user_id, episode_id, current_position_seconds, total_duration_seconds, completed } = req.body;
    if (!user_id || !episode_id) {
      return res.status(400).json({ error: 'user_id and episode_id are required' });
    }

    const { data, error } = await supabase
      .from('podcast_progress')
      .upsert([{
        user_id,
        episode_id,
        current_position_seconds: current_position_seconds || 0,
        total_duration_seconds: total_duration_seconds || 0,
        completed: completed || false,
        updated_at: new Date().toISOString(),
      }], { onConflict: 'user_id,episode_id' })
      .select();

    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Mark an episode as completed
app.post('/api/podcast/mark-completed', async (req, res) => {
  try {
    const { user_id, episode_id, total_duration_seconds } = req.body;
    if (!user_id || !episode_id) {
      return res.status(400).json({ error: 'user_id and episode_id are required' });
    }

    const { data, error } = await supabase
      .from('podcast_progress')
      .upsert([{
        user_id,
        episode_id,
        current_position_seconds: total_duration_seconds || 0,
        total_duration_seconds: total_duration_seconds || 0,
        completed: true,
        updated_at: new Date().toISOString(),
      }], { onConflict: 'user_id,episode_id' })
      .select();

    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// =====================================================================
// EBOOK MANAGEMENT API
// =====================================================================

const EBOOK_SELECT = '*, ebook_categories(id, name, slug)';

// ---- Admin CRUD: Categories ----
app.get('/api/ebook_categories', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebook_categories')
      .select('*')
      .order('sort_order', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/ebook_categories', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebook_categories')
      .insert([req.body])
      .select();
    if (error) throw error;
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/ebook_categories/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebook_categories')
      .update(req.body)
      .eq('id', req.params.id)
      .select();
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/ebook_categories/:id', async (req, res) => {
  try {
    const { error } = await supabase
      .from('ebook_categories')
      .delete()
      .eq('id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Category deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---- Admin CRUD: Books ----
app.get('/api/ebooks', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebooks')
      .select(EBOOK_SELECT)
      .order('sort_order', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

function ebookErrorMessage(error) {
  if (error.code === '23505') return 'A book with this slug already exists. Please choose a different slug.';
  if (error.code === '23503') return 'The selected category no longer exists. Please refresh the page and choose another category.';
  return error.message;
}

app.post('/api/ebooks', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebooks')
      .insert([req.body])
      .select(EBOOK_SELECT);
    if (error) throw error;
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(error.code === '23505' || error.code === '23503' ? 400 : 500).json({ error: ebookErrorMessage(error) });
  }
});

app.put('/api/ebooks/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebooks')
      .update(req.body)
      .eq('id', req.params.id)
      .select(EBOOK_SELECT);
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(error.code === '23505' || error.code === '23503' ? 400 : 500).json({ error: ebookErrorMessage(error) });
  }
});

app.put('/api/ebooks/:id/toggle-status', async (req, res) => {
  try {
    const { status } = req.body;
    const { data, error } = await supabase
      .from('ebooks')
      .update({ status })
      .eq('id', req.params.id)
      .select(EBOOK_SELECT);
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/ebooks/:id', async (req, res) => {
  try {
    const { error } = await supabase
      .from('ebooks')
      .delete()
      .eq('id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Book deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Send a mobile app notification for a book (admin-triggered broadcast)
app.post('/api/admin/ebooks/books/:id/send-notification', async (req, res) => {
  try {
    const { data: book, error: fetchError } = await supabase
      .from('ebooks')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (fetchError) throw fetchError;
    if (!book) return res.status(404).json({ error: 'Book not found' });
    if (book.status !== 'active') {
      return res.status(400).json({ error: 'Activate/publish this book before sending a notification for it.' });
    }

    const title = book.title || 'New E-book';
    const description = (book.description || '').trim();
    const message = description.length > 140 ? `${description.slice(0, 140)}...` : (description || 'A new book is now available.');

    const { data, error } = await supabase
      .from('mobile_notifications')
      .insert([{
        title,
        message,
        type: 'ebook_book',
        reference_id: book.id,
        reference_type: 'ebook_book',
      }])
      .select();
    if (error) throw error;
    res.status(201).json({ success: true, notification: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ---- Admin CRUD: Banner ----
app.get('/api/ebook_banners', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebook_banners')
      .select('*')
      .order('created_at', { ascending: false });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/ebook_banners', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebook_banners')
      .insert([req.body])
      .select();
    if (error) throw error;
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/ebook_banners/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebook_banners')
      .update(req.body)
      .eq('id', req.params.id)
      .select();
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/ebook_banners/:id', async (req, res) => {
  try {
    const { error } = await supabase
      .from('ebook_banners')
      .delete()
      .eq('id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Banner deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Send a mobile app notification for the Discover Banner (admin-triggered broadcast)
app.post('/api/admin/ebooks/banner/:id/send-notification', async (req, res) => {
  try {
    const { data: banner, error: fetchError } = await supabase
      .from('ebook_banners')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (fetchError) throw fetchError;
    if (!banner) return res.status(404).json({ error: 'Banner not found' });
    if (banner.status !== 'active') {
      return res.status(400).json({ error: 'Activate this banner before sending a notification for it.' });
    }

    const title = banner.title || 'New E-book Discovery';
    const subtitle = (banner.subtitle || '').trim();
    const message = subtitle.length > 140 ? `${subtitle.slice(0, 140)}...` : (subtitle || 'Check out the latest e-book discovery.');

    const { data, error } = await supabase
      .from('mobile_notifications')
      .insert([{
        title,
        message,
        type: 'ebook_banner',
        reference_id: banner.id,
        reference_type: 'ebook_banner',
      }])
      .select();
    if (error) throw error;
    res.status(201).json({ success: true, notification: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ---- Admin Dashboard ----
app.get('/api/ebook_dashboard', async (req, res) => {
  try {
    const [totalBooks, activeBooks, inactiveBooks, totalCategories, authorsRows, readerRows] = await Promise.all([
      supabase.from('ebooks').select('*', { count: 'exact', head: true }),
      supabase.from('ebooks').select('*', { count: 'exact', head: true }).eq('status', 'active'),
      supabase.from('ebooks').select('*', { count: 'exact', head: true }).eq('status', 'inactive'),
      supabase.from('ebook_categories').select('*', { count: 'exact', head: true }),
      supabase.from('ebooks').select('author'),
      supabase.from('ebook_progress').select('user_id'),
    ]);

    const totalAuthors = new Set(
      (authorsRows.data || []).map((r) => (r.author || '').trim()).filter((a) => a.length > 0)
    ).size;
    const totalReaders = new Set((readerRows.data || []).map((r) => r.user_id)).size;

    res.json({
      totalBooks: totalBooks.count || 0,
      activeBooks: activeBooks.count || 0,
      inactiveBooks: inactiveBooks.count || 0,
      totalCategories: totalCategories.count || 0,
      totalAuthors,
      totalReaders,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---- Public/Mobile-facing endpoints ----
// (spec parity with the requested /api/ebooks/* surface — the Flutter app
// itself talks directly to Supabase, same as Podcast's /api/podcast/* routes)

app.get('/api/ebooks/categories', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebook_categories')
      .select('*')
      .eq('status', 'active')
      .order('sort_order', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/ebooks/featured', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebooks')
      .select(EBOOK_SELECT)
      .eq('status', 'active')
      .eq('is_featured', true)
      .order('sort_order', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/ebooks/banner', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebook_banners')
      .select('*')
      .eq('status', 'active')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    res.json(data || null);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/ebooks/library', async (req, res) => {
  try {
    const { user_id } = req.query;
    if (!user_id) return res.status(400).json({ error: 'user_id is required' });

    const { data: bookmarkRows, error: bookmarkError } = await supabase
      .from('ebook_bookmarks')
      .select('book_id')
      .eq('user_id', user_id);
    if (bookmarkError) throw bookmarkError;

    const { data: progressRows, error: progressError } = await supabase
      .from('ebook_progress')
      .select('book_id, current_page, total_pages, completed, updated_at')
      .eq('user_id', user_id)
      .gt('current_page', 0);
    if (progressError) throw progressError;

    const progressByBook = {};
    (progressRows || []).forEach((r) => { progressByBook[r.book_id] = r; });
    const ids = Array.from(new Set([
      ...(bookmarkRows || []).map((r) => r.book_id),
      ...Object.keys(progressByBook),
    ]));

    if (ids.length === 0) return res.json([]);

    const { data: books, error: booksError } = await supabase
      .from('ebooks')
      .select(EBOOK_SELECT)
      .eq('status', 'active')
      .in('id', ids);
    if (booksError) throw booksError;

    const bookmarkedIds = new Set((bookmarkRows || []).map((r) => r.book_id));
    const merged = (books || []).map((book) => {
      const progress = progressByBook[book.id];
      return {
        ...book,
        is_bookmarked: bookmarkedIds.has(book.id),
        current_page: progress ? progress.current_page : 0,
        progress_total_pages: progress ? progress.total_pages : book.total_pages,
        completed: progress ? progress.completed : false,
      };
    });

    res.json(merged);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/ebooks/bookmark', async (req, res) => {
  try {
    const { user_id, book_id, page_number } = req.body;
    if (!user_id || !book_id) {
      return res.status(400).json({ error: 'user_id and book_id are required' });
    }
    const { data, error } = await supabase
      .from('ebook_bookmarks')
      .upsert([{ user_id, book_id, page_number: page_number ?? null }], { onConflict: 'user_id,book_id' })
      .select();
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/ebooks/bookmark/:bookId', async (req, res) => {
  try {
    const { user_id } = req.query;
    if (!user_id) return res.status(400).json({ error: 'user_id is required' });
    const { error } = await supabase
      .from('ebook_bookmarks')
      .delete()
      .eq('user_id', user_id)
      .eq('book_id', req.params.bookId);
    if (error) throw error;
    res.json({ message: 'Bookmark removed successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/ebooks/progress', async (req, res) => {
  try {
    const { user_id, book_id, current_page, total_pages, completed } = req.body;
    if (!user_id || !book_id) {
      return res.status(400).json({ error: 'user_id and book_id are required' });
    }
    const totalPages = total_pages || 0;
    const currentPage = current_page || 0;
    const progressPercentage = totalPages > 0 ? Math.min(currentPage / totalPages, 1) * 100 : 0;

    const { data, error } = await supabase
      .from('ebook_progress')
      .upsert([{
        user_id,
        book_id,
        current_page: currentPage,
        total_pages: totalPages,
        progress_percentage: progressPercentage,
        completed: completed || false,
        updated_at: new Date().toISOString(),
      }], { onConflict: 'user_id,book_id' })
      .select();

    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/ebooks/progress/:bookId', async (req, res) => {
  try {
    const { user_id } = req.query;
    if (!user_id) return res.status(400).json({ error: 'user_id is required' });
    const { data, error } = await supabase
      .from('ebook_progress')
      .select('*')
      .eq('user_id', user_id)
      .eq('book_id', req.params.bookId)
      .maybeSingle();
    if (error) throw error;
    res.json(data || null);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Books list — category slug filter, search, pagination (kept last since
// it's the most general /api/ebooks/* GET route)
app.get('/api/ebooks/books', async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page) || 1, 1);
    const limit = Math.min(Math.max(parseInt(req.query.limit) || 10, 1), 100);
    const from = (page - 1) * limit;
    const to = from + limit - 1;

    let query = supabase
      .from('ebooks')
      .select(EBOOK_SELECT, { count: 'exact' })
      .eq('status', 'active');

    if (req.query.category && req.query.category !== 'All' && req.query.category !== 'all') {
      const { data: cat, error: catError } = await supabase
        .from('ebook_categories')
        .select('id')
        .eq('slug', req.query.category)
        .maybeSingle();
      if (catError) throw catError;
      if (cat) {
        query = query.eq('category_id', cat.id);
      } else {
        return res.json({ data: [], page, limit, total: 0 });
      }
    }

    if (req.query.search) {
      query = query.or(`title.ilike.%${req.query.search}%,author.ilike.%${req.query.search}%`);
    }

    const { data, error, count } = await query
      .order('sort_order', { ascending: true })
      .order('publish_date', { ascending: false })
      .range(from, to);

    if (error) throw error;
    res.json({ data, page, limit, total: count || 0 });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/ebooks/books/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ebooks')
      .select(EBOOK_SELECT)
      .eq('id', req.params.id)
      .eq('status', 'active')
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ error: 'Book not found' });
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const fs = require('fs');

// GET habits
app.get('/api/habits', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('habits')
      .select('*')
      .order('sort_order', { ascending: true });
    
    if (error) throw error;
    if (data && data.length > 0) {
      const habits = data.map(item => ({
        icon: item.icon || 'fa-sun',
        rawQuestion: item.raw_question || '',
        highlightWord: item.highlight_word || '',
        subtitle: item.subtitle || ''
      }));
      return res.json(habits);
    }
  } catch (supabaseError) {
    console.error("[Supabase] Error fetching habits, falling back to local habits.json:", supabaseError.message);
  }

  const filepath = path.join(__dirname, 'habits.json');
  if (fs.existsSync(filepath)) {
    try {
      let data = fs.readFileSync(filepath, 'utf8');
      if (data.charCodeAt(0) === 0xFEFF) {
        data = data.substring(1);
      }
      return res.json(JSON.parse(data));
    } catch (e) {
      console.error("Error reading habits.json:", e);
    }
  }
  res.json([]);
});

// POST habits
app.post('/api/habits', async (req, res) => {
  try {
    const filepath = path.join(__dirname, 'habits.json');
    fs.writeFileSync(filepath, JSON.stringify(req.body, null, 2), 'utf8');
  } catch (fsError) {
    console.error("Error writing local habits.json:", fsError);
  }

  try {
    const supabaseHabits = req.body.map((item, idx) => ({
      icon: item.icon || 'fa-sun',
      raw_question: item.rawQuestion || '',
      highlight_word: item.highlightWord || '',
      subtitle: item.subtitle || '',
      sort_order: idx
    }));

    // Delete existing records and insert new
    await supabase.from('habits').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    const { error } = await supabase.from('habits').insert(supabaseHabits);
    if (error) throw error;
  } catch (supabaseError) {
    console.error("[Supabase] Error writing habits to database:", supabaseError.message);
  }

  res.json({ success: true });
});

// GET buttons config
app.get('/api/buttons_config', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('buttons_config')
      .select('*')
      .eq('id', 'default')
      .maybeSingle();

    if (error) throw error;
    if (data) {
      return res.json({
        yesLabel: data.yes_label || 'Yes',
        notYetLabel: data.not_yet_label || 'Not Yet'
      });
    }
  } catch (supabaseError) {
    console.error("[Supabase] Error fetching buttons_config, falling back to local buttons_config.json:", supabaseError.message);
  }

  const filepath = path.join(__dirname, 'buttons_config.json');
  if (fs.existsSync(filepath)) {
    try {
      let data = fs.readFileSync(filepath, 'utf8');
      if (data.charCodeAt(0) === 0xFEFF) {
        data = data.substring(1);
      }
      return res.json(JSON.parse(data));
    } catch (e) {
      console.error("Error reading buttons_config.json:", e);
    }
  }
  res.json({ yesLabel: "Yes", notYetLabel: "Not Yet" });
});

// POST buttons config
app.post('/api/buttons_config', async (req, res) => {
  try {
    const filepath = path.join(__dirname, 'buttons_config.json');
    fs.writeFileSync(filepath, JSON.stringify(req.body, null, 2), 'utf8');
  } catch (fsError) {
    console.error("Error writing local buttons_config.json:", fsError);
  }

  try {
    const payload = {
      id: 'default',
      yes_label: req.body.yesLabel || 'Yes',
      not_yet_label: req.body.notYetLabel || 'Not Yet',
      updated_at: new Date().toISOString()
    };
    const { error } = await supabase.from('buttons_config').upsert(payload);
    if (error) throw error;
  } catch (supabaseError) {
    console.error("[Supabase] Error writing buttons_config to database:", supabaseError.message);
  }

  res.json({ success: true });
});

// ---- Legal Pages (Terms & Conditions / Privacy Policy) ----
const LEGAL_TYPES = ['terms', 'privacy'];

// Mobile-facing: active content only
app.get('/api/legal/terms', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('legal_pages')
      .select('*')
      .eq('type', 'terms')
      .eq('status', 'active')
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ error: 'Terms & Conditions not available' });
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/legal/privacy', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('legal_pages')
      .select('*')
      .eq('type', 'privacy')
      .eq('status', 'active')
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ error: 'Privacy Policy not available' });
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Admin-facing: full management (one record per type)
app.get('/api/admin/legal', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('legal_pages')
      .select('*')
      .order('sort_order', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/admin/legal/:type', async (req, res) => {
  const { type } = req.params;
  if (!LEGAL_TYPES.includes(type)) {
    return res.status(400).json({ error: 'type must be "terms" or "privacy"' });
  }
  try {
    const { data, error } = await supabase
      .from('legal_pages')
      .select('*')
      .eq('type', type)
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ error: `No ${type} page found` });
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/admin/legal/:type', async (req, res) => {
  const { type } = req.params;
  if (!LEGAL_TYPES.includes(type)) {
    return res.status(400).json({ error: 'type must be "terms" or "privacy"' });
  }
  const { title, content, sort_order } = req.body;
  if (!title || !title.trim()) {
    return res.status(400).json({ error: 'Title is required' });
  }
  if (!content || !content.trim()) {
    return res.status(400).json({ error: 'Content is required' });
  }
  try {
    const { data, error } = await supabase
      .from('legal_pages')
      .update({
        title: title.trim(),
        content: content.trim(),
        sort_order: sort_order || 0,
        updated_at: new Date().toISOString(),
      })
      .eq('type', type)
      .select();
    if (error) throw error;
    if (!data || !data.length) return res.status(404).json({ error: `No ${type} page found` });
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/api/admin/legal/:type/status', async (req, res) => {
  const { type } = req.params;
  if (!LEGAL_TYPES.includes(type)) {
    return res.status(400).json({ error: 'type must be "terms" or "privacy"' });
  }
  const { status } = req.body;
  if (status !== 'active' && status !== 'inactive') {
    return res.status(400).json({ error: 'status must be "active" or "inactive"' });
  }
  try {
    const { data, error } = await supabase
      .from('legal_pages')
      .update({ status, updated_at: new Date().toISOString() })
      .eq('type', type)
      .select();
    if (error) throw error;
    if (!data || !data.length) return res.status(404).json({ error: `No ${type} page found` });
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ═══════════════════════════════════════════
// Support Module (settings, categories, FAQs, tickets, feedback)
// ═══════════════════════════════════════════
const SUPPORT_STATUS_VALUES = ['new', 'in-progress', 'resolved', 'closed'];
const SUPPORT_FAQ_SELECT = '*, support_categories(id, name, slug)';
const SUPPORT_TICKET_SELECT = '*, support_categories(id, name, slug)';

// ---- Mobile: Settings ----
app.get('/api/support/settings', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('support_settings')
      .select('*')
      .eq('status', 'active')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    res.json(data || null);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---- Mobile: Categories ----
app.get('/api/support/categories', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('support_categories')
      .select('*')
      .eq('status', 'active')
      .order('sort_order', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---- Mobile: FAQs (with optional category/search/pagination) ----
app.get('/api/support/faqs', async (req, res) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 50;
    const from = (page - 1) * limit;
    const to = from + limit - 1;

    let query = supabase.from('support_faqs').select(SUPPORT_FAQ_SELECT).eq('status', 'active');
    if (req.query.category) query = query.eq('category_id', req.query.category);
    if (req.query.search) {
      query = query.or(`question.ilike.%${req.query.search}%,answer.ilike.%${req.query.search}%`);
    }

    const { data, error } = await query.order('sort_order', { ascending: true }).range(from, to);
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---- Mobile: Submit a ticket ----
// Creates an admin notification row; failures here must never block the
// actual ticket/feedback submission since it already succeeded.
async function createAdminNotification({ title, message, type, referenceId, referenceType }) {
  try {
    await supabase.from('admin_notifications').insert([{
      title,
      message,
      type,
      reference_id: referenceId || null,
      reference_type: referenceType || null,
      is_read: false,
    }]);
  } catch (err) {
    console.error('Failed to create admin notification:', err.message);
  }
}

app.post('/api/support/tickets', async (req, res) => {
  const { name, email, phone, subject, category_id, message, attachment_url } = req.body;
  if (!name || !name.trim()) return res.status(400).json({ error: 'Name is required' });
  if (!email || !email.trim()) return res.status(400).json({ error: 'Email is required' });
  if (!subject || !subject.trim()) return res.status(400).json({ error: 'Subject is required' });
  if (!message || !message.trim()) return res.status(400).json({ error: 'Message is required' });
  try {
    const { data, error } = await supabase
      .from('support_tickets')
      .insert([{
        name: name.trim(),
        email: email.trim(),
        phone: phone ? phone.trim() : null,
        subject: subject.trim(),
        category_id: category_id || null,
        message: message.trim(),
        attachment_url: attachment_url || null,
        status: 'new',
      }])
      .select();
    if (error) throw error;
    await createAdminNotification({
      title: 'New Support Ticket',
      message: `New ticket submitted: ${subject.trim()}`,
      type: 'support_ticket',
      referenceId: data[0].id,
      referenceType: 'support_ticket',
    });
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---- Mobile: Submit feedback / report an issue ----
app.post('/api/support/feedback', async (req, res) => {
  const { name, email, rating, message } = req.body;
  if (!message || !message.trim()) return res.status(400).json({ error: 'Message is required' });
  if (rating !== undefined && rating !== null && (rating < 1 || rating > 5)) {
    return res.status(400).json({ error: 'Rating must be between 1 and 5' });
  }
  try {
    const { data, error } = await supabase
      .from('support_feedback')
      .insert([{
        name: name ? name.trim() : null,
        email: email ? email.trim() : null,
        rating: rating || null,
        message: message.trim(),
        status: 'new',
      }])
      .select();
    if (error) throw error;
    await createAdminNotification({
      title: 'New Feedback Received',
      message: name && name.trim() ? `${name.trim()} submitted feedback` : 'Anonymous feedback submitted',
      type: 'support_feedback',
      referenceId: data[0].id,
      referenceType: 'support_feedback',
    });
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---- Admin: Dashboard ----
app.get('/api/admin/support/dashboard', async (req, res) => {
  try {
    const [totalFaqs, activeFaqs, totalTickets, newTickets, resolvedTickets, totalCategories] = await Promise.all([
      supabase.from('support_faqs').select('*', { count: 'exact', head: true }),
      supabase.from('support_faqs').select('*', { count: 'exact', head: true }).eq('status', 'active'),
      supabase.from('support_tickets').select('*', { count: 'exact', head: true }),
      supabase.from('support_tickets').select('*', { count: 'exact', head: true }).eq('status', 'new'),
      supabase.from('support_tickets').select('*', { count: 'exact', head: true }).eq('status', 'resolved'),
      supabase.from('support_categories').select('*', { count: 'exact', head: true }),
    ]);
    res.json({
      totalFaqs: totalFaqs.count || 0,
      activeFaqs: activeFaqs.count || 0,
      totalTickets: totalTickets.count || 0,
      newTickets: newTickets.count || 0,
      resolvedTickets: resolvedTickets.count || 0,
      totalCategories: totalCategories.count || 0,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---- Admin: Categories CRUD ----
app.get('/api/admin/support/categories', async (req, res) => {
  try {
    const { data, error } = await supabase.from('support_categories').select('*').order('sort_order', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/admin/support/categories', async (req, res) => {
  const { name, slug } = req.body;
  if (!name || !name.trim()) return res.status(400).json({ error: 'Name is required' });
  if (!slug || !slug.trim()) return res.status(400).json({ error: 'Slug is required' });
  try {
    const { data, error } = await supabase.from('support_categories').insert([req.body]).select();
    if (error) throw error;
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(error.code === '23505' ? 400 : 500).json({
      error: error.code === '23505' ? 'A category with this slug already exists.' : error.message,
    });
  }
});

app.put('/api/admin/support/categories/:id', async (req, res) => {
  const { name, slug } = req.body;
  if (!name || !name.trim()) return res.status(400).json({ error: 'Name is required' });
  if (!slug || !slug.trim()) return res.status(400).json({ error: 'Slug is required' });
  try {
    const { data, error } = await supabase
      .from('support_categories')
      .update({ ...req.body, updated_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .select();
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(error.code === '23505' ? 400 : 500).json({
      error: error.code === '23505' ? 'A category with this slug already exists.' : error.message,
    });
  }
});

app.patch('/api/admin/support/categories/:id/status', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('support_categories')
      .update({ status: req.body.status, updated_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .select();
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/admin/support/categories/:id', async (req, res) => {
  try {
    const { error } = await supabase.from('support_categories').delete().eq('id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Category deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---- Admin: FAQ CRUD ----
app.get('/api/admin/support/faqs', async (req, res) => {
  try {
    const { data, error } = await supabase.from('support_faqs').select(SUPPORT_FAQ_SELECT).order('sort_order', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/admin/support/faqs', async (req, res) => {
  const { question, answer } = req.body;
  if (!question || !question.trim()) return res.status(400).json({ error: 'Question is required' });
  if (!answer || !answer.trim()) return res.status(400).json({ error: 'Answer is required' });
  try {
    const { data, error } = await supabase.from('support_faqs').insert([req.body]).select(SUPPORT_FAQ_SELECT);
    if (error) throw error;
    res.status(201).json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/admin/support/faqs/:id', async (req, res) => {
  const { question, answer } = req.body;
  if (!question || !question.trim()) return res.status(400).json({ error: 'Question is required' });
  if (!answer || !answer.trim()) return res.status(400).json({ error: 'Answer is required' });
  try {
    const { data, error } = await supabase
      .from('support_faqs')
      .update({ ...req.body, updated_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .select(SUPPORT_FAQ_SELECT);
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/api/admin/support/faqs/:id/status', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('support_faqs')
      .update({ status: req.body.status, updated_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .select(SUPPORT_FAQ_SELECT);
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/admin/support/faqs/:id', async (req, res) => {
  try {
    const { error } = await supabase.from('support_faqs').delete().eq('id', req.params.id);
    if (error) throw error;
    res.json({ message: 'FAQ deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Send a mobile app notification for a FAQ (admin-triggered broadcast)
app.post('/api/admin/support/faqs/:id/send-notification', async (req, res) => {
  try {
    const { data: faq, error: fetchError } = await supabase
      .from('support_faqs')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (fetchError) throw fetchError;
    if (!faq) return res.status(404).json({ error: 'FAQ not found' });
    if (faq.status !== 'active') {
      return res.status(400).json({ error: 'Activate this FAQ before sending a notification for it.' });
    }

    const title = faq.question || 'Support FAQ Update';
    const answer = (faq.answer || '').trim();
    const message = answer.length > 140 ? `${answer.slice(0, 140)}...` : (answer || 'A support FAQ has been updated.');

    const { data, error } = await supabase
      .from('mobile_notifications')
      .insert([{
        title,
        message,
        type: 'support_faq',
        reference_id: faq.id,
        reference_type: 'support_faq',
      }])
      .select();
    if (error) throw error;
    res.status(201).json({ success: true, notification: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ---- Admin: Settings (single row) ----
app.get('/api/admin/support/settings', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('support_settings')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    res.json(data || null);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/admin/support/settings', async (req, res) => {
  const { title } = req.body;
  if (!title || !title.trim()) return res.status(400).json({ error: 'Title is required' });
  try {
    const existing = await supabase.from('support_settings').select('id').limit(1).maybeSingle();
    if (existing.error) throw existing.error;

    let result;
    if (existing.data) {
      result = await supabase
        .from('support_settings')
        .update({ ...req.body, updated_at: new Date().toISOString() })
        .eq('id', existing.data.id)
        .select();
    } else {
      result = await supabase.from('support_settings').insert([req.body]).select();
    }
    if (result.error) throw result.error;
    res.json(result.data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/api/admin/support/settings/status', async (req, res) => {
  try {
    const existing = await supabase.from('support_settings').select('id').limit(1).maybeSingle();
    if (existing.error) throw existing.error;
    if (!existing.data) return res.status(404).json({ error: 'No settings record found' });

    const { data, error } = await supabase
      .from('support_settings')
      .update({ status: req.body.status, updated_at: new Date().toISOString() })
      .eq('id', existing.data.id)
      .select();
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---- Admin: Tickets ----
app.get('/api/admin/support/tickets', async (req, res) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 20;
    const from = (page - 1) * limit;
    const to = from + limit - 1;

    let query = supabase.from('support_tickets').select(SUPPORT_TICKET_SELECT, { count: 'exact' });
    if (req.query.status) query = query.eq('status', req.query.status);
    if (req.query.category) query = query.eq('category_id', req.query.category);
    if (req.query.search) {
      query = query.or(`name.ilike.%${req.query.search}%,email.ilike.%${req.query.search}%,subject.ilike.%${req.query.search}%`);
    }

    const { data, error, count } = await query.order('created_at', { ascending: false }).range(from, to);
    if (error) throw error;
    res.json({ data, page, limit, total: count || 0 });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/admin/support/tickets/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('support_tickets')
      .select(SUPPORT_TICKET_SELECT)
      .eq('id', req.params.id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ error: 'Ticket not found' });
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/api/admin/support/tickets/:id/status', async (req, res) => {
  if (!SUPPORT_STATUS_VALUES.includes(req.body.status)) {
    return res.status(400).json({ error: `status must be one of ${SUPPORT_STATUS_VALUES.join(', ')}` });
  }
  try {
    const { data, error } = await supabase
      .from('support_tickets')
      .update({ status: req.body.status, updated_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .select(SUPPORT_TICKET_SELECT);
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/admin/support/tickets/:id', async (req, res) => {
  try {
    const { error } = await supabase.from('support_tickets').delete().eq('id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Ticket deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Send a mobile app notification for a ticket (admin-triggered broadcast)
app.post('/api/admin/support/tickets/:id/send-notification', async (req, res) => {
  try {
    const { data: ticket, error: fetchError } = await supabase
      .from('support_tickets')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (fetchError) throw fetchError;
    if (!ticket) return res.status(404).json({ error: 'Ticket not found' });

    const title = ticket.subject || 'Support Ticket Update';
    const message = (ticket.message || '').trim();
    const shortMessage = message.length > 140 ? `${message.slice(0, 140)}...` : (message || 'There is an update on your support ticket.');

    const { data, error } = await supabase
      .from('mobile_notifications')
      .insert([{
        title,
        message: shortMessage,
        type: 'support_ticket',
        reference_id: ticket.id,
        reference_type: 'support_ticket',
      }])
      .select();
    if (error) throw error;
    res.status(201).json({ success: true, notification: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ---- Admin: Feedback (view + status, not part of mobile-facing spec but needed for admin visibility) ----
app.get('/api/admin/support/feedback', async (req, res) => {
  try {
    let query = supabase.from('support_feedback').select('*', { count: 'exact' });
    if (req.query.status) query = query.eq('status', req.query.status);
    const { data, error } = await query.order('created_at', { ascending: false });
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/api/admin/support/feedback/:id/status', async (req, res) => {
  if (!SUPPORT_STATUS_VALUES.includes(req.body.status)) {
    return res.status(400).json({ error: `status must be one of ${SUPPORT_STATUS_VALUES.join(', ')}` });
  }
  try {
    const { data, error } = await supabase
      .from('support_feedback')
      .update({ status: req.body.status, updated_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .select();
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/admin/support/feedback/:id', async (req, res) => {
  try {
    const { error } = await supabase.from('support_feedback').delete().eq('id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Feedback deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Send a mobile app notification for a feedback entry (admin-triggered broadcast)
app.post('/api/admin/support/feedback/:id/send-notification', async (req, res) => {
  try {
    const { data: feedback, error: fetchError } = await supabase
      .from('support_feedback')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (fetchError) throw fetchError;
    if (!feedback) return res.status(404).json({ error: 'Feedback not found' });

    const title = feedback.name || 'Feedback Update';
    const message = (feedback.message || '').trim();
    const shortMessage = message.length > 140 ? `${message.slice(0, 140)}...` : (message || 'There is an update on your feedback.');

    const { data, error } = await supabase
      .from('mobile_notifications')
      .insert([{
        title,
        message: shortMessage,
        type: 'support_feedback',
        reference_id: feedback.id,
        reference_type: 'support_feedback',
      }])
      .select();
    if (error) throw error;
    res.status(201).json({ success: true, notification: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ═══════════════════════════════════════════
// Admin Notifications
// ═══════════════════════════════════════════
app.get('/api/admin/notifications', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit, 10) || 50;
    const { data, error } = await supabase
      .from('admin_notifications')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/admin/notifications/unread-count', async (req, res) => {
  try {
    const { count, error } = await supabase
      .from('admin_notifications')
      .select('*', { count: 'exact', head: true })
      .eq('is_read', false);
    if (error) throw error;
    res.json({ count: count || 0 });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/api/admin/notifications/:id/read', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('admin_notifications')
      .update({ is_read: true, updated_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .select();
    if (error) throw error;
    res.json(data[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/api/admin/notifications/mark-all-read', async (req, res) => {
  try {
    const { error } = await supabase
      .from('admin_notifications')
      .update({ is_read: true, updated_at: new Date().toISOString() })
      .eq('is_read', false);
    if (error) throw error;
    res.json({ message: 'All notifications marked as read' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Start Server
app.listen(PORT, () => {
  console.log(`Admin Server running on http://localhost:${PORT}`);
});
