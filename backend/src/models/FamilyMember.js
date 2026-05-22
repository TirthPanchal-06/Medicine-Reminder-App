const mongoose = require('mongoose');

const FamilyMemberSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  relationship: {
    type: String,
    required: true,
    enum: ['parent', 'child', 'spouse', 'sibling', 'other']
  },
  age: {
    type: Number
  },
  gender: {
    type: String,
    enum: ['male', 'female', 'other']
  },
  medicalHistory: {
    type: String,
    default: ''
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('FamilyMember', FamilyMemberSchema);
