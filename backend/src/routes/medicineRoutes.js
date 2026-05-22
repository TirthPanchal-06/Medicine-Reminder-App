const express = require('express');
const router = express.Router();
const { createSchedule, getSchedules, getScheduleById, updateSchedule, deleteSchedule } = require('../controllers/medicineController');
const { protect } = require('../middlewares/auth');
const upload = require('../middlewares/upload');

router.use(protect);

router.route('/')
  .post(upload.single('prescription'), createSchedule)
  .get(getSchedules);

router.route('/:id')
  .get(getScheduleById)
  .put(upload.single('prescription'), updateSchedule)
  .delete(deleteSchedule);

module.exports = router;
