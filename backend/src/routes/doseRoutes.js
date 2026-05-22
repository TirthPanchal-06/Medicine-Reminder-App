const express = require('express');
const router = express.Router();
const { getTodayDoses, logDose, getComplianceStats } = require('../controllers/doseController');
const { protect } = require('../middlewares/auth');

router.use(protect);

router.get('/today', getTodayDoses);
router.post('/log', logDose);
router.get('/stats', getComplianceStats);

module.exports = router;
