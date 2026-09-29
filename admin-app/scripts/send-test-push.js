// Sends a one-off test FCM push to every installed app (the `all_users`
// topic), to check the push pipeline end to end from a terminal.
//
// Usage, from admin-app/:
//   node scripts/send-test-push.js                   default title/body
//   node scripts/send-test-push.js "Title" "Body"    custom title/body
//
// Reuses services/pushService.js (same credentials from .env, same topic,
// channel and payload shape as real notifications). It does NOT create a
// mobile_notifications row, so nothing appears in the in-app Notifications
// list; tapping the push just opens that list.

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { sendNotificationPush, ALL_USERS_TOPIC } = require('../services/pushService');

const title = process.argv[2] || 'TBT Test Notification';
const body = process.argv[3] || 'Hello! This is a test push notification from Git Bash.';

(async () => {
  console.log(`Sending test push to FCM topic "${ALL_USERS_TOPIC}"...`);
  console.log(`  Title: ${title}`);
  console.log(`  Body:  ${body}`);

  // No `type`, so the app treats a tap as "open the Notifications list".
  const result = await sendNotificationPush({
    id: `test-${Date.now()}`,
    title,
    message: body,
  });

  if (result.sent) {
    console.log(`\nSUCCESS: Firebase Cloud Messaging accepted the push.`);
    console.log(`  FCM message id: ${result.messageId}`);
    process.exit(0);
  }
  console.error(`\nFAILED: push was not sent (${result.reason}).`);
  console.error('  Check FIREBASE_SERVICE_ACCOUNT_PATH in admin-app/.env and the error logged above.');
  process.exit(1);
})();
