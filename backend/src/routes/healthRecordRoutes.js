const express = require('express');
const router = express.Router();
const { createRecord, getRecords, getVitalsSummary } = require('../controllers/healthRecordController');
const { protect } = require('../middlewares/auth');

router.use(protect);

router.route('/')
  .post(createRecord)
  .get(getRecords);

router.get('/summary', getVitalsSummary);

module.exports = router;
