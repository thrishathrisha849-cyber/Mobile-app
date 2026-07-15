// CRUD for ai_conversations / ai_messages. Ownership (a user can only see
// their own conversations) is enforced here in application code, not via
// Supabase RLS — see ai_schema.sql for why (no real auth session to key RLS on).

const { deleteConversationImages } = require('./imageUploadService');

class ConversationServiceError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

async function getOwnedConversation(supabase, conversationId, userId) {
  const { data, error } = await supabase
    .from('ai_conversations')
    .select('*')
    .eq('id', conversationId)
    .single();

  if (error || !data) {
    throw new ConversationServiceError('not_found', 'Conversation not found.');
  }
  if (data.user_id !== userId) {
    throw new ConversationServiceError('forbidden', 'You do not have access to this conversation.');
  }
  return data;
}

async function createConversation(supabase, userId) {
  const { data, error } = await supabase
    .from('ai_conversations')
    .insert({ user_id: userId })
    .select()
    .single();
  if (error) { console.error('service error:', error); throw new ConversationServiceError('server_error', 'Could not start a new conversation.'); }
  return data;
}

async function appendMessage(supabase, { conversationId, sender, message, inputType, imageUrl, contentType, language, tone }) {
  const { data, error } = await supabase
    .from('ai_messages')
    .insert({
      conversation_id: conversationId,
      sender,
      message,
      input_type: inputType,
      image_url: imageUrl || null,
      content_type: contentType || null,
      language: language || null,
      tone: tone || null,
    })
    .select()
    .single();
  if (error) { console.error('service error:', error); throw new ConversationServiceError('server_error', 'Could not save the message.'); }

  await supabase.from('ai_conversations').update({ updated_at: new Date().toISOString() }).eq('id', conversationId);
  return data;
}

async function setConversationTitle(supabase, conversationId, title) {
  if (!title) return;
  await supabase.from('ai_conversations').update({ title }).eq('id', conversationId);
}

async function listConversations(supabase, { userId, search, limit = 50, offset = 0 }) {
  let query = supabase
    .from('ai_conversations')
    .select('*')
    .eq('user_id', userId)
    .order('updated_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (search) query = query.ilike('title', `%${search}%`);

  const { data, error } = await query;
  if (error) { console.error('service error:', error); throw new ConversationServiceError('server_error', 'Could not load conversations.'); }
  return data;
}

async function getMessages(supabase, { conversationId, userId }) {
  await getOwnedConversation(supabase, conversationId, userId);
  const { data, error } = await supabase
    .from('ai_messages')
    .select('*')
    .eq('conversation_id', conversationId)
    .order('created_at', { ascending: true });
  if (error) { console.error('service error:', error); throw new ConversationServiceError('server_error', 'Could not load messages.'); }
  return data;
}

async function renameConversation(supabase, { conversationId, userId, title }) {
  await getOwnedConversation(supabase, conversationId, userId);
  if (!title || !title.trim()) {
    throw new ConversationServiceError('empty_input', 'Title cannot be empty.');
  }
  const { data, error } = await supabase
    .from('ai_conversations')
    .update({ title: title.trim() })
    .eq('id', conversationId)
    .select()
    .single();
  if (error) { console.error('service error:', error); throw new ConversationServiceError('server_error', 'Could not rename the conversation.'); }
  return data;
}

async function deleteConversation(supabase, { conversationId, userId }) {
  await getOwnedConversation(supabase, conversationId, userId);
  await deleteConversationImages(supabase, { userId, conversationId });
  const { error } = await supabase.from('ai_conversations').delete().eq('id', conversationId);
  if (error) { console.error('service error:', error); throw new ConversationServiceError('server_error', 'Could not delete the conversation.'); }
}

module.exports = {
  createConversation,
  appendMessage,
  setConversationTitle,
  listConversations,
  getMessages,
  renameConversation,
  deleteConversation,
  getOwnedConversation,
  ConversationServiceError,
};
