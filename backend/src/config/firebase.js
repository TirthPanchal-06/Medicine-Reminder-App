const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

let firebaseApp = null;
let messaging = null;

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

if (serviceAccountPath && fs.existsSync(path.resolve(serviceAccountPath))) {
  try {
    const serviceAccount = require(path.resolve(serviceAccountPath));
    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    messaging = admin.messaging();
    console.log('Firebase Admin SDK initialized successfully.');
  } catch (error) {
    console.error('Failed to initialize Firebase Admin SDK:', error.message);
  }
} else {
  console.warn('Firebase Service Account path not found or invalid. Notifications will run in MOCK mode.');
}

const sendPushNotification = async (token, payload) => {
  if (messaging && token) {
    try {
      const response = await messaging.send({
        token: token,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data || {},
      });
      console.log('FCM Notification sent successfully:', response);
      return response;
    } catch (error) {
      console.error('Error sending FCM notification:', error.message);
      return null;
    }
  } else {
    console.log(`[MOCK NOTIFICATION] Token: ${token || 'N/A'}`);
    console.log(`[MOCK NOTIFICATION] Title: ${payload.title}`);
    console.log(`[MOCK NOTIFICATION] Body: ${payload.body}`);
    console.log(`[MOCK NOTIFICATION] Data:`, payload.data || {});
    return { mockSent: true };
  }
};

module.exports = {
  firebaseApp,
  sendPushNotification
};
