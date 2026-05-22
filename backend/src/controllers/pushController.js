const PushSubscription = require('../models/PushSubscription');
const vapidConfig = require('../config/vapid');

// @desc    Get VAPID public key
// @route   GET /api/push/vapid-key
// @access  Public (or Private)
exports.getVapidPublicKey = async (req, res) => {
  try {
    res.json({ success: true, publicKey: vapidConfig.publicKey });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Subscribe to push notifications
// @route   POST /api/push/subscribe
// @access  Private
exports.subscribe = async (req, res) => {
  const { endpoint, keys } = req.body;

  if (!endpoint || !keys || !keys.p256dh || !keys.auth) {
    return res.status(400).json({ success: false, message: 'Invalid subscription payload' });
  }

  try {
    // Check if subscription already exists for this endpoint
    let subscription = await PushSubscription.findOne({ endpoint });

    if (subscription) {
      // Update the user assignment or keys if needed
      subscription.userId = req.user._id;
      subscription.keys = keys;
      await subscription.save();
    } else {
      // Create a new subscription
      subscription = await PushSubscription.create({
        userId: req.user._id,
        endpoint,
        keys
      });
    }

    res.status(201).json({ success: true, data: subscription });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
