const mongoose = require('mongoose');

const AppointmentSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  doctorName: {
    type: String,
    required: true,
    trim: true
  },
  specialty: {
    type: String,
    default: ''
  },
  dateTime: {
    type: Date,
    required: true
  },
  venue: {
    type: String,
    default: ''
  },
  notes: {
    type: String,
    default: ''
  },
  reminderSent: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Appointment', AppointmentSchema);
