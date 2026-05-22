const mongoose = require('mongoose');

const DoseLogSchema = new mongoose.Schema({
  scheduleId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'MedicineSchedule',
    required: true
  },
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
  dueTime: {
    type: Date,
    required: true
  },
  takenTime: {
    type: Date,
    default: null // Will be populated when marked as taken
  },
  status: {
    type: String,
    enum: ['taken', 'missed', 'skipped'],
    default: 'missed'
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('DoseLog', DoseLogSchema);
