const webpush = require('web-push');
const fs = require('fs');
const path = require('path');

let vapidKeys = {
  publicKey: process.env.VAPID_PUBLIC_KEY,
  privateKey: process.env.VAPID_PRIVATE_KEY
};

// If not present, try to generate a persistent set for local development
if (!vapidKeys.publicKey || !vapidKeys.privateKey) {
  const localVapidPath = path.join(__dirname, '../../vapid.json');
  if (fs.existsSync(localVapidPath)) {
    try {
      vapidKeys = JSON.parse(fs.readFileSync(localVapidPath, 'utf8'));
    } catch (_) {}
  }

  if (!vapidKeys.publicKey || !vapidKeys.privateKey) {
    console.log('VAPID keys not configured in env. Generating temporary stable development keys...');
    const generated = webpush.generateVAPIDKeys();
    vapidKeys = {
      publicKey: generated.publicKey,
      privateKey: generated.privateKey
    };
    try {
      fs.writeFileSync(localVapidPath, JSON.stringify(vapidKeys, null, 2), 'utf8');
      console.log('Saved generated development VAPID keys to backend/vapid.json');
    } catch (err) {
      console.error('Failed to save VAPID keys locally:', err.message);
    }
  }
}

// Set standard VAPID details
// We specify a mock contact email for webpush notifications
webpush.setVapidDetails(
  'mailto:support@smartmedreminder.local',
  vapidKeys.publicKey,
  vapidKeys.privateKey
);

module.exports = {
  publicKey: vapidKeys.publicKey,
  webpush
};
