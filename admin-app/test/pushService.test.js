// Tests for services/pushService.js. Run with `npm test` from admin-app/.
//
// These must never send a real push, so Firebase credentials are removed
// from the environment before the service is loaded (and .env is never
// loaded here): the service then stays in its "push not configured" state
// and cannot reach Firebase.

const { test, before } = require('node:test');
const assert = require('node:assert/strict');

delete process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
const { sendNotificationPush, ALL_USERS_TOPIC } = require('../services/pushService');

// Silence the service's "not configured" warning in test output.
before(() => {
  console.warn = () => {};
});

// Must match NotificationType in lib/notification_service.dart and the
// mobile_notifications_type_check constraint.
const PUSHED_TYPES = [
  'community_post', 'podcast_series', 'podcast_episode',
  'ebook_book', 'ebook_banner', 'support_faq',
];
const PERSONAL_TYPES = ['support_ticket', 'support_feedback'];

function row(type) {
  return { id: 'test-id', title: 'Test', message: 'Test', type };
}

test('pushes go to the all_users topic', () => {
  assert.equal(ALL_USERS_TOPIC, 'all_users');
});

for (const type of PERSONAL_TYPES) {
  test(`"${type}" is personal: never pushed, stays in-app only`, async () => {
    assert.deepEqual(await sendNotificationPush(row(type)), {
      sent: false,
      reason: `"${type}" notifications are in-app only`,
    });
  });
}

for (const type of PUSHED_TYPES) {
  test(`"${type}" is not excluded from push`, async () => {
    // Without credentials it can't actually send, but it must get past the
    // personal-type check to the "not configured" step.
    assert.deepEqual(await sendNotificationPush(row(type)), {
      sent: false,
      reason: 'push not configured',
    });
  });
}

test('a missing notification row is rejected without throwing', async () => {
  assert.deepEqual(await sendNotificationPush(null), {
    sent: false,
    reason: 'no notification row',
  });
});
