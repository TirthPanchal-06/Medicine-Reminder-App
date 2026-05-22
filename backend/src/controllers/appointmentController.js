const Appointment = require('../models/Appointment');

// @desc    Create a doctor appointment
// @route   POST /api/appointments
// @access  Private
exports.createAppointment = async (req, res) => {
  const { doctorName, specialty, dateTime, venue, notes } = req.body;

  try {
    const appointment = await Appointment.create({
      userId: req.user._id,
      doctorName,
      specialty: specialty || '',
      dateTime,
      venue: venue || '',
      notes: notes || ''
    });

    res.status(201).json({ success: true, data: appointment });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get all doctor appointments for user
// @route   GET /api/appointments
// @access  Private
exports.getAppointments = async (req, res) => {
  try {
    const appointments = await Appointment.find({ userId: req.user._id })
      .sort({ dateTime: 1 }); // Sort upcoming first
    res.json({ success: true, count: appointments.length, data: appointments });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update appointment
// @route   PUT /api/appointments/:id
// @access  Private
exports.updateAppointment = async (req, res) => {
  try {
    let appointment = await Appointment.findOne({ _id: req.params.id, userId: req.user._id });
    if (!appointment) {
      return res.status(404).json({ success: false, message: 'Appointment not found' });
    }

    appointment = await Appointment.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true
    });

    res.json({ success: true, data: appointment });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Delete appointment
// @route   DELETE /api/appointments/:id
// @access  Private
exports.deleteAppointment = async (req, res) => {
  try {
    const appointment = await Appointment.findOne({ _id: req.params.id, userId: req.user._id });
    if (!appointment) {
      return res.status(404).json({ success: false, message: 'Appointment not found' });
    }

    await Appointment.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Appointment deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
