const axios = require('axios');
const prisma = require('../config/db');

/**
 * Send a push notification via Firebase Cloud Messaging (HTTP v1 API).
 * Requires FIREBASE_PROJECT_ID and FIREBASE_SERVER_KEY in .env
 */
const sendPush = async (userId, title, body, data = {}) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { fcmToken: true },
    }).catch(() => null);

    if (!user?.fcmToken) return; // no token registered

    await axios.post(
      `https://fcm.googleapis.com/fcm/send`,
      {
        to: user.fcmToken,
        notification: { title, body, sound: 'default' },
        data,
        priority: 'high',
      },
      {
        headers: {
          Authorization: `key=${process.env.FIREBASE_SERVER_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (err) {
    console.error('Push notification error:', err.message);
  }
};

/**
 * Register or update FCM token for a user
 */
const registerToken = async (userId, fcmToken) => {
  await prisma.user.update({
    where: { id: userId },
    data: { fcmToken },
  });
};

module.exports = { sendPush, registerToken };
