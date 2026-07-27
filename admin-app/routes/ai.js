// All /api/ai/** endpoints for the AI Content Creation Assistant.
// Thin by design: validates input shape, delegates to services, shapes the
// JSON response. See specs/001-ai-content-assistant/plan.md §6 for the contract.

const express = require('express');
const multer = require('multer');
const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');

const aiUsageGuard = require('../middleware/aiUsageGuard');
const claudeService = require('../services/claudeService');
const imageUploadService = require('../services/imageUploadService');
const conversationService = require('../services/conversationService');
const savedContentService = require('../services/savedContentService');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);

// Client-input validation codes — expected, routine, and already
// self-explanatory from the request; not worth logging as errors.
const VALIDATION_CODES = new Set(['empty_input', 'invalid_image_type', 'image_too_large']);

function sendError(res, err, extra) {
  const knownCodes = new Set([
    'empty_input', 'invalid_image_type', 'image_too_large', 'daily_limit_reached',
    'rate_limited', 'claude_timeout', 'claude_error', 'claude_not_configured', 'claude_auth_error',
    'claude_forbidden', 'claude_rate_limited', 'claude_billing_error', 'claude_server_error',
    'claude_parse_error', 'not_found', 'forbidden', 'server_error',
  ]);
  const code = knownCodes.has(err.code) ? err.code : 'server_error';
  const status = {
    not_found: 404, forbidden: 403, empty_input: 400, invalid_image_type: 400, image_too_large: 400,
    daily_limit_reached: 429, rate_limited: 429, claude_timeout: 504, claude_rate_limited: 429,
    claude_billing_error: 503, claude_not_configured: 500, claude_auth_error: 502, claude_forbidden: 502,
    claude_server_error: 502, claude_parse_error: 502,
  }[code] || 500;
  // Log everything except routine client-input validation — a silently
  // swallowed claude_error/claude_timeout/etc. is exactly what made this
  // whole class of bug hard to diagnose from outside the server process.
  if (!VALIDATION_CODES.has(code)) {
    // Full stack trace for genuinely unexpected errors (code got coerced to
    // server_error because it wasn't one of our typed service errors) —
    // typed errors from claudeService/etc. already log their own detail
    // (request summary, upstream status/body) at the point they're thrown.
    console.error(`[AI route error] code=${code} status=${status}:`, err.message || err, code === 'server_error' ? err.stack : '');
  }
  res.status(status).json({ success: false, code, message: err.message || 'Something went wrong. Please try again.', ...extra });
}

// ── POST /api/ai/content/create ────────────────────────────────────────────
router.post('/content/create', upload.single('image'), aiUsageGuard, async (req, res) => {
  // Tracked outside the try block so the catch handler can return it even if
  // the failure happens after the conversation/user-message were already
  // persisted (e.g. the Claude call itself fails) — without this, a client
  // retry would have no conversationId to continue, and would silently spawn
  // a new orphan conversation on every retry instead of continuing the same one.
  let conversation = null;
  try {
    let payload;
    try {
      payload = JSON.parse(req.body.payload || '{}');
    } catch (_) {
      return sendError(res, { code: 'empty_input', message: 'Malformed request payload.' });
    }

    const { message, contentType, tone, language, length, conversationId } = payload;
    const userId = req.aiUserId;

    // An image alone is valid content (matches the mobile client's guard,
    // ai_content_screen.dart's _sendMessage) — only reject when there's
    // neither text nor an image.
    if ((!message || !message.trim()) && !req.file) {
      return sendError(res, { code: 'empty_input', message: 'Please enter or say what content you want to create.' });
    }
    const safeMessage = message && message.trim() ? message : 'Describe this image.';

    // Resolve (or create) the conversation.
    if (conversationId) {
      conversation = await conversationService.getOwnedConversation(supabase, conversationId, userId);
    } else {
      conversation = await conversationService.createConversation(supabase, userId);
    }

    const priorMessages = await conversationService.getMessages(supabase, { conversationId: conversation.id, userId });
    const isFirstTurn = priorMessages.length === 0;

    // Image (optional).
    let imageForClaude = null;
    let imageUrl = null;
    if (req.file) {
      const uploaded = await imageUploadService.processAndUploadImage(supabase, {
        file: req.file,
        userId,
        conversationId: conversation.id,
        messageId: crypto.randomUUID(),
      });
      imageForClaude = { mimeType: uploaded.mimeType, base64: uploaded.base64 };
      imageUrl = uploaded.publicUrl;
    }

    const inputType = req.file ? 'image' : (payload.inputType === 'voice' ? 'voice' : 'text');

    // Persist the user's turn.
    await conversationService.appendMessage(supabase, {
      conversationId: conversation.id,
      sender: 'user',
      message: safeMessage,
      inputType,
      imageUrl,
      contentType,
      language,
      tone,
    });

    // Generate.
    const result = await claudeService.generateContent({
      history: priorMessages.map((m) => ({ sender: m.sender, message: m.message })),
      message: safeMessage,
      image: imageForClaude,
      isFirstTurn,
      context: { contentType, tone, language, length },
    });

    if (isFirstTurn && result.title) {
      await conversationService.setConversationTitle(supabase, conversation.id, result.title);
    }

    await conversationService.appendMessage(supabase, {
      conversationId: conversation.id,
      sender: 'assistant',
      message: result.content,
      inputType: 'text',
      contentType,
      language,
      tone,
    });

    res.json({
      success: true,
      conversationId: conversation.id,
      content: result.content,
      suggestions: ['Make it shorter', 'Add emojis', 'Make it more professional'],
    });
  } catch (err) {
    sendError(res, err, conversation ? { conversationId: conversation.id } : undefined);
  }
});

// ── Conversations ───────────────────────────────────────────────────────────
router.get('/conversations', aiUsageGuard, async (req, res) => {
  try {
    const data = await conversationService.listConversations(supabase, {
      userId: req.aiUserId,
      search: req.query.search,
    });
    res.json({ success: true, conversations: data });
  } catch (err) {
    sendError(res, err);
  }
});

router.get('/conversations/:id/messages', aiUsageGuard, async (req, res) => {
  try {
    const data = await conversationService.getMessages(supabase, {
      conversationId: req.params.id,
      userId: req.aiUserId,
    });
    res.json({ success: true, messages: data });
  } catch (err) {
    sendError(res, err);
  }
});

router.patch('/conversations/:id', aiUsageGuard, async (req, res) => {
  try {
    const data = await conversationService.renameConversation(supabase, {
      conversationId: req.params.id,
      userId: req.aiUserId,
      title: req.body.title,
    });
    res.json({ success: true, conversation: data });
  } catch (err) {
    sendError(res, err);
  }
});

router.delete('/conversations/:id', aiUsageGuard, async (req, res) => {
  try {
    await conversationService.deleteConversation(supabase, {
      conversationId: req.params.id,
      userId: req.aiUserId,
    });
    res.json({ success: true });
  } catch (err) {
    sendError(res, err);
  }
});

// ── Saved content ────────────────────────────────────────────────────────
router.get('/saved', aiUsageGuard, async (req, res) => {
  try {
    const data = await savedContentService.list(supabase, {
      userId: req.aiUserId,
      category: req.query.category,
      search: req.query.search,
    });
    res.json({ success: true, items: data });
  } catch (err) {
    sendError(res, err);
  }
});

router.post('/saved', aiUsageGuard, async (req, res) => {
  try {
    const data = await savedContentService.save(supabase, {
      userId: req.aiUserId,
      conversationId: req.body.conversationId,
      title: req.body.title,
      content: req.body.content,
      category: req.body.category,
    });
    res.json({ success: true, item: data });
  } catch (err) {
    sendError(res, err);
  }
});

router.patch('/saved/:id', aiUsageGuard, async (req, res) => {
  try {
    const data = await savedContentService.update(supabase, {
      id: req.params.id,
      userId: req.aiUserId,
      title: req.body.title,
      content: req.body.content,
      category: req.body.category,
    });
    res.json({ success: true, item: data });
  } catch (err) {
    sendError(res, err);
  }
});

router.delete('/saved/:id', aiUsageGuard, async (req, res) => {
  try {
    await savedContentService.remove(supabase, { id: req.params.id, userId: req.aiUserId });
    res.json({ success: true });
  } catch (err) {
    sendError(res, err);
  }
});

module.exports = router;
