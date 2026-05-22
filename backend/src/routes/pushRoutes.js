const express = require('express');
const router = express.Router();
const { getVapidPublicKey, subscribe } = require('../controllers/pushController');
const { protect } = require('../middlewares/auth');

// Public route to fetch public key for subscription
router.get('/vapid-key', getVapidPublicKey);

// Protected subscription route
router.post('/subscribe', protect, subscribe);

module.exports = router;
