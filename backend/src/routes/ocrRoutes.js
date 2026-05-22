const express = require('express');
const router = express.Router();
const { scanPrescription } = require('../utils/ocr');
const { protect } = require('../middlewares/auth');
const upload = require('../middlewares/upload');

router.post('/scan', protect, upload.single('prescription'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'Please upload a prescription image or PDF file' });
  }

  try {
    const { text, medicines } = await scanPrescription(req.file.path);
    res.json({
      success: true,
      data: {
        rawText: text,
        medicines: medicines,
        fileUrl: `/uploads/${req.file.filename}`
      }
    });
  } catch (error) {
    console.error('OCR Route Error:', error.message);
    res.status(500).json({ success: false, message: 'OCR analysis failed. ' + error.message });
  }
});

module.exports = router;
