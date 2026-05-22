const DoseLog = require('../models/DoseLog');
const MedicineSchedule = require('../models/MedicineSchedule');

// Helper to check if a schedule should run on a given date
const shouldScheduleRunOnDate = (schedule, date) => {
  const start = new Date(schedule.startDate);
  start.setHours(0,0,0,0);
  const target = new Date(date);
  target.setHours(0,0,0,0);

  if (target < start) return false;
  if (schedule.endDate && target > new Date(schedule.endDate)) return false;

  if (schedule.frequency === 'daily') {
    return true;
  }

  if (schedule.frequency === 'weekly' || schedule.frequency === 'specific_days') {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const currentDayName = days[target.getDay()];
    return schedule.specificDays.includes(currentDayName);
  }

  if (schedule.frequency === 'interval') {
    const diffTime = Math.abs(target - start);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    return diffDays % schedule.interval === 0;
  }

  return false;
};

// @desc    Get checklist of doses for a specific date (defaults to today)
// @route   GET /api/doses/today
// @access  Private
exports.getTodayDoses = async (req, res) => {
  const targetDateStr = req.query.date || new Date().toISOString();
  const targetDate = new Date(targetDateStr);
  const startOfDay = new Date(targetDate);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(targetDate);
  endOfDay.setHours(23, 59, 59, 999);

  const { familyMemberId } = req.query;

  try {
    const query = { userId: req.user._id, isActive: true };
    if (familyMemberId) {
      query.familyMemberId = familyMemberId === 'null' ? null : familyMemberId;
    }

    // 1. Fetch active schedules
    const schedules = await MedicineSchedule.find(query);

    // 2. Identify schedules running today
    const runningSchedules = schedules.filter(s => shouldScheduleRunOnDate(s, targetDate));

    const finalDosesList = [];

    // 3. For each running schedule, verify and build dose log entries
    for (const schedule of runningSchedules) {
      for (const timeStr of schedule.times) {
        const [hours, minutes] = timeStr.split(':').map(Number);
        
        // Build the specific due time for today
        const dueTime = new Date(targetDate);
        dueTime.setHours(hours, minutes, 0, 0);

        // Try to find if a log already exists for this schedule + dueTime
        let log = await DoseLog.findOne({
          scheduleId: schedule._id,
          dueTime: dueTime
        });

        // If no log exists and the dueTime has passed, we initialize it as 'missed' in the DB.
        if (!log) {
          const now = new Date();
          const isPast = dueTime < now;
          
          log = new DoseLog({
            scheduleId: schedule._id,
            userId: req.user._id,
            familyMemberId: schedule.familyMemberId,
            dueTime: dueTime,
            status: isPast ? 'missed' : 'missed', // Will display as upcoming/missed based on frontend takenTime or backend status
            takenTime: null
          });
          
          // Save it so we persist compliance logs
          await log.save();
        }

        // Return a detailed log object that includes schedule details
        finalDosesList.push({
          _id: log._id,
          scheduleId: schedule._id,
          medicineName: schedule.name,
          dosage: schedule.dosage,
          instructions: schedule.instructions,
          imageUrl: schedule.imageUrl,
          dueTime: log.dueTime,
          takenTime: log.takenTime,
          status: log.status,
          familyMemberId: schedule.familyMemberId
        });
      }
    }

    // Sort by dueTime asc
    finalDosesList.sort((a, b) => new Date(a.dueTime) - new Date(b.dueTime));

    res.json({ success: true, count: finalDosesList.length, data: finalDosesList });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Log a dose (mark as taken, missed, or skipped)
// @route   POST /api/doses/log
// @access  Private
exports.logDose = async (req, res) => {
  const { doseLogId, status } = req.body;

  try {
    const log = await DoseLog.findOne({ _id: doseLogId, userId: req.user._id });
    if (!log) {
      return res.status(404).json({ success: false, message: 'Dose log not found' });
    }

    log.status = status; // 'taken', 'missed', 'skipped'
    log.takenTime = status === 'taken' ? new Date() : null;
    
    await log.save();

    // Populate schedule details to return
    const schedule = await MedicineSchedule.findById(log.scheduleId);

    res.json({
      success: true,
      data: {
        _id: log._id,
        scheduleId: log.scheduleId,
        medicineName: schedule ? schedule.name : 'Unknown',
        dosage: schedule ? schedule.dosage : '',
        dueTime: log.dueTime,
        takenTime: log.takenTime,
        status: log.status
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get historical compliance statistics for charts
// @route   GET /api/doses/stats
// @access  Private
exports.getComplianceStats = async (req, res) => {
  const { familyMemberId, days = 7 } = req.query;
  const daysLimit = parseInt(days);

  const startDate = new Date();
  startDate.setDate(startDate.getDate() - daysLimit);
  startDate.setHours(0,0,0,0);

  try {
    const query = {
      userId: req.user._id,
      dueTime: { $gte: startDate }
    };
    if (familyMemberId) {
      query.familyMemberId = familyMemberId === 'null' ? null : familyMemberId;
    }

    const logs = await DoseLog.find(query);

    const stats = {
      total: logs.length,
      taken: logs.filter(l => l.status === 'taken').length,
      missed: logs.filter(l => l.status === 'missed').length,
      skipped: logs.filter(l => l.status === 'skipped').length,
      adherenceRate: 0,
      dailyTrend: {} // date -> { taken, total }
    };

    if (stats.total > 0) {
      stats.adherenceRate = Math.round((stats.taken / stats.total) * 100);
    }

    // Populate daily trends
    for (let i = 0; i < daysLimit; i++) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      stats.dailyTrend[dateStr] = { taken: 0, total: 0 };
    }

    logs.forEach(log => {
      const dateStr = new Date(log.dueTime).toISOString().split('T')[0];
      if (stats.dailyTrend[dateStr]) {
        stats.dailyTrend[dateStr].total += 1;
        if (log.status === 'taken') {
          stats.dailyTrend[dateStr].taken += 1;
        }
      }
    });

    res.json({ success: true, data: stats });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
