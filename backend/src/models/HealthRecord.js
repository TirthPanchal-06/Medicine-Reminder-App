const mongoose = require('mongoose');

const HealthRecordSchema = new mongoose.Schema({
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
  type: {
    type: String,
    enum: ['blood_pressure', 'blood_sugar', 'weight', 'heart_rate'],
    required: true
  },
  value: {
    type: mongoose.Schema.Types.Mixed,
    required: true
    // Structure examples:
    // blood_pressure: { systolic: 120, diastolic: 80 }
    // blood_sugar: { value: 110, mealType: 'fasting' | 'post_prandial' | 'random' }
    // weight: { value: 72.5, unit: 'kg' }
    // heart_rate: { value: 72 }
  },
  timestamp: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('HealthRecord', HealthRecordSchema);
