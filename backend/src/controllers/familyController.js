const FamilyMember = require('../models/FamilyMember');
const MedicineSchedule = require('../models/MedicineSchedule');

// @desc    Add a family member
// @route   POST /api/family
// @access  Private
exports.addMember = async (req, res) => {
  const { name, relationship, age, gender, medicalHistory } = req.body;

  try {
    const member = await FamilyMember.create({
      userId: req.user._id,
      name,
      relationship,
      age: age ? parseInt(age) : undefined,
      gender,
      medicalHistory: medicalHistory || ''
    });

    res.status(201).json({ success: true, data: member });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get all family members
// @route   GET /api/family
// @access  Private
exports.getMembers = async (req, res) => {
  try {
    const members = await FamilyMember.find({ userId: req.user._id }).sort({ name: 1 });
    res.json({ success: true, count: members.length, data: members });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update a family member
// @route   PUT /api/family/:id
// @access  Private
exports.updateMember = async (req, res) => {
  try {
    let member = await FamilyMember.findOne({ _id: req.params.id, userId: req.user._id });
    if (!member) {
      return res.status(404).json({ success: false, message: 'Family member not found' });
    }

    member = await FamilyMember.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true
    });

    res.json({ success: true, data: member });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Remove a family member and deactivate their schedules
// @route   DELETE /api/family/:id
// @access  Private
exports.deleteMember = async (req, res) => {
  try {
    const member = await FamilyMember.findOne({ _id: req.params.id, userId: req.user._id });
    if (!member) {
      return res.status(404).json({ success: false, message: 'Family member not found' });
    }

    await FamilyMember.findByIdAndDelete(req.params.id);

    // Deactivate schedules linked to this family member
    await MedicineSchedule.updateMany(
      { familyMemberId: req.params.id, userId: req.user._id },
      { isActive: false }
    );

    res.json({ success: true, message: 'Family member and their schedules removed successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
