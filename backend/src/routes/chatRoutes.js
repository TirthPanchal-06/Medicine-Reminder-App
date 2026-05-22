const express = require('express');
const router = express.Router();
const { getChatResponse } = require('../utils/chatbot');
const { protect } = require('../middlewares/auth');

router.post('/message', protect, async (req, res) => {
  const { history = [], message } = req.body;

  if (!message) {
    return res.status(400).json({ success: false, message: 'Please provide a message' });
  }

  try {
    const response = await getChatResponse(history, message);
    res.json({
      success: true,
      data: {
        response: response
      }
    });
  } catch (error) {
    console.error('Chatbot Route Error:', error.message);
    res.status(500).json({ success: false, message: 'AI Health assistant failed. ' + error.message });
  }
});

module.exports = router;
