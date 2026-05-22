const mongoose = require('mongoose');

const MedicineScheduleSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  familyMemberId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'FamilyMember',
    default: null
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  dosage: {
    type: String,
    required: true // e.g. "1 pill", "5 ml"
  },
  frequency: {
    type: String,
    enum: ['daily', 'weekly', 'specific_days', 'interval'],
    default: 'daily'
  },
  specificDays: {
    type: [String], // e.g. ['Mon', 'Wed', 'Fri']
    default: []
  },
  interval: {
    type: Number, // e.g. every 2 days (if frequency is 'interval')
    default: 1
  },
  times: {
    type: [String], // Array of 'HH:MM' strings e.g. ['08:00', '13:00', '20:00']
    required: true
  },
  timezone: {
    type: String,
    default: '+05:30'
  },
  startDate: {
    type: Date,
    required: true,
    default: Date.now
  },
  endDate: {
    type: Date,
    default: null // null means infinite/ongoing
  },
  instructions: {
    type: String,
    default: '' // e.g. "Before food", "With water"
  },
  imageUrl: {
    type: String,
    default: '' // URL of uploaded prescription image/PDF or pill photo
  },
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('MedicineSchedule', MedicineScheduleSchema);
