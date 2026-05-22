const express = require('express');
const router = express.Router();
const { registerUser, loginUser, getUserProfile, updateSettings, updatePushToken } = require('../controllers/authController');
const { protect } = require('../middlewares/auth');

router.post('/register', registerUser);
router.post('/login', loginUser);
router.get('/profile', protect, getUserProfile);
router.put('/settings', protect, updateSettings);
router.put('/push-token', protect, updatePushToken);

module.exports = router;
