// In-memory rate/usage limiting for the AI Content Creation Assistant's
// generation endpoint, keyed by the anonymous per-device user_id.
// v1 decision (spec.md §6.4): in-process only, no Redis in this stack today.
// ai_usage_counters table exists as the persistent fallback if this backend
// is ever run as more than one instance.

const DAY_MS = 24 * 60 * 60 * 1000;
const MINUTE_MS = 60 * 1000;
const DAILY_LIMIT = 30;
const MINUTE_LIMIT = 10;

/** @type {Map<string, { dayStart: number, dayCount: number, minuteStart: number, minuteCount: number }>} */
const counters = new Map();

function getOrInit(userId) {
  const now = Date.now();
  let entry = counters.get(userId);
  if (!entry) {
    entry = { dayStart: now, dayCount: 0, minuteStart: now, minuteCount: 0 };
    counters.set(userId, entry);
  }
  if (now - entry.dayStart >= DAY_MS) {
    entry.dayStart = now;
    entry.dayCount = 0;
  }
  if (now - entry.minuteStart >= MINUTE_MS) {
    entry.minuteStart = now;
    entry.minuteCount = 0;
  }
  return entry;
}

/**
 * Checks and, if allowed, consumes one unit against both the per-minute and
 * per-day quotas for userId.
 * @returns {{ allowed: boolean, remaining: number, resetAt: number, reason?: 'rate_limited'|'daily_limit_reached' }}
 */
function checkAndConsume(userId) {
  const entry = getOrInit(userId);

  if (entry.minuteCount >= MINUTE_LIMIT) {
    return { allowed: false, remaining: 0, resetAt: entry.minuteStart + MINUTE_MS, reason: 'rate_limited' };
  }
  if (entry.dayCount >= DAILY_LIMIT) {
    return { allowed: false, remaining: 0, resetAt: entry.dayStart + DAY_MS, reason: 'daily_limit_reached' };
  }

  entry.minuteCount += 1;
  entry.dayCount += 1;
  return { allowed: true, remaining: DAILY_LIMIT - entry.dayCount, resetAt: entry.dayStart + DAY_MS };
}

// Periodic cleanup so long-running processes don't accumulate stale entries
// for users who never come back.
setInterval(() => {
  const now = Date.now();
  for (const [userId, entry] of counters) {
    if (now - entry.dayStart >= DAY_MS && now - entry.minuteStart >= MINUTE_MS) {
      counters.delete(userId);
    }
  }
}, DAY_MS).unref();

module.exports = { checkAndConsume, DAILY_LIMIT, MINUTE_LIMIT };
