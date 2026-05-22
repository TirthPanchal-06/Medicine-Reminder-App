const express = require('express');
const router = express.Router();
const { createAppointment, getAppointments, updateAppointment, deleteAppointment } = require('../controllers/appointmentController');
const { protect } = require('../middlewares/auth');

router.use(protect);

router.route('/')
  .post(createAppointment)
  .get(getAppointments);

router.route('/:id')
  .put(updateAppointment)
  .delete(deleteAppointment);

module.exports = router;
