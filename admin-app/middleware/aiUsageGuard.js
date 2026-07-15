// Applied per-route inside routes/ai.js (not as a single blanket app.use in
// server.js) because POST /content/create is multipart/form-data — its fields
// only exist on req.body after multer runs, so on that route this middleware
// must be mounted *after* upload.single('image'). On every other (JSON/query)
// route it can run directly since express.json() (already global in server.js)
// has parsed req.body by the time any /api/ai route is reached.
//
// No other route in admin-app is touched by this — see plan.md §1 "Deliberate
// deviation" and §6.4 for why this isn't retrofitted onto the rest of the
// existing backend.

const { checkAndConsume } = require('../services/usageLimitService');

// Only the generation endpoint counts against the daily/minute quota — listing
// or editing existing conversations/saved content is free (plan.md §6).
const QUOTA_CONSUMING_ROUTES = new Set(['POST /content/create']);

function extractUserId(req) {
  if (req.body && req.body.userId) return req.body.userId;
  // multipart /content/create: structured fields arrive JSON-encoded inside
  // the 'payload' form field (see routes/ai.js), not as top-level fields.
  if (req.body && typeof req.body.payload === 'string') {
    try {
      const parsed = JSON.parse(req.body.payload);
      if (parsed.userId) return parsed.userId;
    } catch (_) {
      // handled as empty_input below
    }
  }
  return req.query.user_id || req.query.userId || null;
}

module.exports = function aiUsageGuard(req, res, next) {
  const userId = extractUserId(req);
  if (!userId) {
    return res.status(400).json({ success: false, code: 'empty_input', message: 'A user identifier is required.' });
  }
  req.aiUserId = userId;

  const routeKey = `${req.method} ${req.path}`;
  if (!QUOTA_CONSUMING_ROUTES.has(routeKey)) {
    return next();
  }

  const result = checkAndConsume(userId);
  if (!result.allowed) {
    const message =
      result.reason === 'daily_limit_reached'
        ? "You've reached today's content generation limit. Please try again tomorrow."
        : "You're sending requests a bit too fast. Please wait a moment and try again.";
    return res.status(429).json({ success: false, code: result.reason, message });
  }

  next();
};
