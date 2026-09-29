// FCM push notifications for the mobile app, sent via the Firebase Admin SDK.
//
// Every `mobile_notifications` row is a global broadcast (the mobile app has
// no per-user auth), so pushes go to the `all_users` FCM topic that every
// device subscribes to on startup (lib/firebase_notification_service.dart)
// rather than to individual device tokens.
//
// Credentials (never commit them — see .env.example):
//   FIREBASE_SERVICE_ACCOUNT_PATH  path to the service-account JSON file,
//                                  relative to admin-app/ (or absolute), or
//   FIREBASE_SERVICE_ACCOUNT_JSON  the whole JSON as one line, for hosts
//                                  where writing a file isn't convenient.
// With neither set, pushes are skipped and in-app notifications still work.

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

const ALL_USERS_TOPIC = 'all_users';

// Must match the channel id created by the app and the manifest's
// default_notification_channel_id, and the app's drawable/colour resources.
const ANDROID_CHANNEL_ID = 'tbt_notifications';
const ANDROID_ICON = 'ic_stat_notification';
const ANDROID_COLOR = '#D30814';

// Notification types about one user's own ticket/feedback. They're still
// written to mobile_notifications as before, but not pushed: a topic push
// would put that user's message on every device's lock screen.
const PERSONAL_TYPES = new Set(['support_ticket', 'support_feedback']);

let messaging = null;
let initAttempted = false;

function loadServiceAccount() {
  const inline = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  const filePath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!inline && !filePath) return null;

  let raw;
  let source;
  if (inline) {
    raw = inline;
    source = 'FIREBASE_SERVICE_ACCOUNT_JSON';
  } else {
    const resolved = path.resolve(__dirname, '..', filePath);
    if (!fs.existsSync(resolved)) {
      throw new Error(`service-account file not found at FIREBASE_SERVICE_ACCOUNT_PATH (${filePath})`);
    }
    raw = fs.readFileSync(resolved, 'utf8');
    source = 'FIREBASE_SERVICE_ACCOUNT_PATH';
  }

  try {
    return JSON.parse(raw);
  } catch (_) {
    // Deliberately not rethrowing the parse error: its message can quote
    // part of the input, i.e. of the private key.
    throw new Error(`${source} does not contain valid JSON`);
  }
}

function getMessagingClient() {
  if (initAttempted) return messaging;
  initAttempted = true;
  try {
    const serviceAccount = loadServiceAccount();
    if (!serviceAccount) {
      console.warn('[push] Firebase service account not configured — FCM pushes are disabled (in-app notifications unaffected).');
      return null;
    }
    const app = initializeApp({ credential: cert(serviceAccount) }, 'tbt-push');
    messaging = getMessaging(app);
    console.log(`[push] Firebase Admin initialized for project "${serviceAccount.project_id}"`);
  } catch (err) {
    console.error(`[push] Firebase Admin initialization failed: ${err.message}`);
  }
  return messaging;
}

// FCM `data` values must all be strings; absent ones are omitted so the app
// sees them as null.
function buildData(notification) {
  const data = {
    notification_id: notification.id,
    type: notification.type,
    reference_id: notification.reference_id,
    reference_type: notification.reference_type,
  };
  return Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => value !== null && value !== undefined)
      .map(([key, value]) => [key, String(value)]),
  );
}

/**
 * Pushes a just-inserted `mobile_notifications` row to the `all_users` topic.
 * Never throws — a push failure must not fail the in-app notification that
 * was already saved — and returns a small status object for the API response.
 */
async function sendNotificationPush(notification) {
  if (!notification) return { sent: false, reason: 'no notification row' };
  if (PERSONAL_TYPES.has(notification.type)) {
    return { sent: false, reason: `"${notification.type}" notifications are in-app only` };
  }

  const client = getMessagingClient();
  if (!client) return { sent: false, reason: 'push not configured' };

  try {
    const messageId = await client.send({
      topic: ALL_USERS_TOPIC,
      notification: {
        title: notification.title,
        body: notification.message,
      },
      data: buildData(notification),
      android: {
        priority: 'high',
        notification: {
          channelId: ANDROID_CHANNEL_ID,
          icon: ANDROID_ICON,
          color: ANDROID_COLOR,
        },
      },
      apns: {
        payload: { aps: { sound: 'default' } },
      },
    });
    console.log(`[push] Sent "${notification.type}" notification ${notification.id} to topic "${ALL_USERS_TOPIC}" (${messageId})`);
    return { sent: true, messageId };
  } catch (err) {
    console.error(`[push] Failed to send notification ${notification.id}: ${err.code || ''} ${err.message}`);
    return { sent: false, reason: err.code || 'send failed' };
  }
}

module.exports = { sendNotificationPush, ALL_USERS_TOPIC };
