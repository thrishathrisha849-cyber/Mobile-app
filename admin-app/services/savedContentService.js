// CRUD + search for saved_ai_content. Same app-layer ownership-check
// convention as conversationService.js (see ai_schema.sql for why).

const VALID_CATEGORIES = ['social_media', 'advertisement', 'business', 'personal', 'video_script', 'email', 'other'];

class SavedContentServiceError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

async function getOwnedItem(supabase, id, userId) {
  const { data, error } = await supabase.from('saved_ai_content').select('*').eq('id', id).single();
  if (error || !data) throw new SavedContentServiceError('not_found', 'Saved item not found.');
  if (data.user_id !== userId) throw new SavedContentServiceError('forbidden', 'You do not have access to this item.');
  return data;
}

async function save(supabase, { userId, conversationId, title, content, category }) {
  if (!title || !title.trim() || !content || !content.trim()) {
    throw new SavedContentServiceError('empty_input', 'Title and content are required.');
  }
  const normalizedCategory = VALID_CATEGORIES.includes(category) ? category : 'other';
  const { data, error } = await supabase
    .from('saved_ai_content')
    .insert({
      user_id: userId,
      conversation_id: conversationId || null,
      title: title.trim(),
      content,
      category: normalizedCategory,
    })
    .select()
    .single();
  if (error) { console.error('service error:', error); throw new SavedContentServiceError('server_error', 'Could not save this content.'); }
  return data;
}

async function list(supabase, { userId, category, search, limit = 50, offset = 0 }) {
  let query = supabase
    .from('saved_ai_content')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (category) query = query.eq('category', category);
  if (search) query = query.or(`title.ilike.%${search}%,content.ilike.%${search}%`);

  const { data, error } = await query;
  if (error) { console.error('service error:', error); throw new SavedContentServiceError('server_error', 'Could not load saved content.'); }
  return data;
}

async function update(supabase, { id, userId, title, content, category }) {
  await getOwnedItem(supabase, id, userId);
  const patch = {};
  if (title !== undefined) {
    if (!title.trim()) throw new SavedContentServiceError('empty_input', 'Title cannot be empty.');
    patch.title = title.trim();
  }
  if (content !== undefined) {
    if (!content.trim()) throw new SavedContentServiceError('empty_input', 'Content cannot be empty.');
    patch.content = content;
  }
  if (category !== undefined) patch.category = VALID_CATEGORIES.includes(category) ? category : 'other';
  patch.updated_at = new Date().toISOString();

  const { data, error } = await supabase.from('saved_ai_content').update(patch).eq('id', id).select().single();
  if (error) { console.error('service error:', error); throw new SavedContentServiceError('server_error', 'Could not update this content.'); }
  return data;
}

async function remove(supabase, { id, userId }) {
  await getOwnedItem(supabase, id, userId);
  const { error } = await supabase.from('saved_ai_content').delete().eq('id', id);
  if (error) { console.error('service error:', error); throw new SavedContentServiceError('server_error', 'Could not delete this content.'); }
}

module.exports = { save, list, update, remove, VALID_CATEGORIES, SavedContentServiceError };
