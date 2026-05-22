const HealthRecord = require('../models/HealthRecord');

// @desc    Add a new health record (vitals)
// @route   POST /api/health-records
// @access  Private
exports.createRecord = async (req, res) => {
  const { type, value, familyMemberId, timestamp } = req.body;

  try {
    const record = await HealthRecord.create({
      userId: req.user._id,
      familyMemberId: familyMemberId || null,
      type,
      value, // Flexible object: e.g. { systolic: 120, diastolic: 80 }
      timestamp: timestamp || new Date()
    });

    res.status(201).json({ success: true, data: record });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get health records by type for charts/history
// @route   GET /api/health-records
// @access  Private
exports.getRecords = async (req, res) => {
  const { type, familyMemberId, limit = 50 } = req.query;

  try {
    const query = { userId: req.user._id };
    if (type) query.type = type;
    if (familyMemberId) {
      query.familyMemberId = familyMemberId === 'null' ? null : familyMemberId;
    }

    const records = await HealthRecord.find(query)
      .sort({ timestamp: -1 })
      .limit(parseInt(limit));

    // Return in chronological order for easier chart plotting
    res.json({ success: true, count: records.length, data: records.reverse() });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get dynamic summary / averages of latest vitals
// @route   GET /api/health-records/summary
// @access  Private
exports.getVitalsSummary = async (req, res) => {
  const { familyMemberId } = req.query;

  try {
    const query = { userId: req.user._id };
    if (familyMemberId) {
      query.familyMemberId = familyMemberId === 'null' ? null : familyMemberId;
    }

    const summary = {};
    const types = ['blood_pressure', 'blood_sugar', 'weight', 'heart_rate'];

    for (const type of types) {
      const latest = await HealthRecord.findOne({ ...query, type }).sort({ timestamp: -1 });
      summary[type] = latest || null;
    }

    res.json({ success: true, data: summary });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
