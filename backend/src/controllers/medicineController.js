const MedicineSchedule = require('../models/MedicineSchedule');

// @desc    Create a new medicine schedule
// @route   POST /api/medicines
// @access  Private
exports.createSchedule = async (req, res) => {
  const { name, dosage, frequency, specificDays, interval, times, startDate, endDate, instructions, familyMemberId, timezone } = req.body;

  try {
    const imageUrl = req.file ? `/uploads/${req.file.filename}` : req.body.imageUrl || '';

    const schedule = await MedicineSchedule.create({
      userId: req.user._id,
      familyMemberId: familyMemberId || null,
      name,
      dosage,
      frequency,
      specificDays: specificDays ? JSON.parse(specificDays) : [],
      interval: interval ? parseInt(interval) : 1,
      times: typeof times === 'string' ? JSON.parse(times) : times,
      timezone: timezone || '+05:30',
      startDate: startDate || new Date(),
      endDate: endDate || null,
      instructions: instructions || '',
      imageUrl
    });

    res.status(201).json({ success: true, data: schedule });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get all medicine schedules for user (or family member)
// @route   GET /api/medicines
// @access  Private
exports.getSchedules = async (req, res) => {
  const { familyMemberId } = req.query;

  try {
    const query = { userId: req.user._id, isActive: true };
    if (familyMemberId) {
      query.familyMemberId = familyMemberId === 'null' ? null : familyMemberId;
    }

    const schedules = await MedicineSchedule.find(query)
      .populate('familyMemberId', 'name relationship')
      .sort({ createdAt: -1 });

    res.json({ success: true, count: schedules.length, data: schedules });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get medicine schedule by ID
// @route   GET /api/medicines/:id
// @access  Private
exports.getScheduleById = async (req, res) => {
  try {
    const schedule = await MedicineSchedule.findOne({ _id: req.params.id, userId: req.user._id });
    if (!schedule) {
      return res.status(404).json({ success: false, message: 'Medicine schedule not found' });
    }
    res.json({ success: true, data: schedule });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update medicine schedule
// @route   PUT /api/medicines/:id
// @access  Private
exports.updateSchedule = async (req, res) => {
  try {
    let schedule = await MedicineSchedule.findOne({ _id: req.params.id, userId: req.user._id });
    if (!schedule) {
      return res.status(404).json({ success: false, message: 'Medicine schedule not found' });
    }

    const updates = { ...req.body };
    if (req.file) {
      updates.imageUrl = `/uploads/${req.file.filename}`;
    }
    if (updates.specificDays && typeof updates.specificDays === 'string') {
      updates.specificDays = JSON.parse(updates.specificDays);
    }
    if (updates.times && typeof updates.times === 'string') {
      updates.times = JSON.parse(updates.times);
    }

    schedule = await MedicineSchedule.findByIdAndUpdate(req.params.id, updates, {
      new: true,
      runValidators: true
    });

    res.json({ success: true, data: schedule });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Soft-delete medicine schedule
// @route   DELETE /api/medicines/:id
// @access  Private
exports.deleteSchedule = async (req, res) => {
  try {
    const schedule = await MedicineSchedule.findOne({ _id: req.params.id, userId: req.user._id });
    if (!schedule) {
      return res.status(404).json({ success: false, message: 'Medicine schedule not found' });
    }

    schedule.isActive = false;
    await schedule.save();

    res.json({ success: true, message: 'Medicine schedule deactivated successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
