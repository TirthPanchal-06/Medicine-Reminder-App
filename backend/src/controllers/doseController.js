const DoseLog = require('../models/DoseLog');
const MedicineSchedule = require('../models/MedicineSchedule');

// Get local date string YYYY-MM-DD for a given Date and timezone offset string (e.g. '+05:30')
const getLocalDateStrForOffset = (now, offsetStr) => {
  const sign = offsetStr[0] === '-' ? -1 : 1;
  const hours = parseInt(offsetStr.slice(1, 3));
  const minutes = parseInt(offsetStr.slice(4, 6));
  const offsetMs = sign * (hours * 60 + minutes) * 60 * 1000;
  
  const localTime = new Date(now.getTime() + offsetMs);
  
  const yyyy = localTime.getUTCFullYear();
  const mm = (localTime.getUTCMonth() + 1).toString().padStart(2, '0');
  const dd = localTime.getUTCDate().toString().padStart(2, '0');
  
  return `${yyyy}-${mm}-${dd}`;
};

// Helper to check if a schedule should run on a given date (timezone-aware)
const shouldScheduleRunOnDate = (schedule, date) => {
  const timezone = schedule.timezone || '+05:30';
  
  const startStr = getLocalDateStrForOffset(new Date(schedule.startDate), timezone);
  const targetStr = getLocalDateStrForOffset(new Date(date), timezone);
  
  const start = new Date(`${startStr}T00:00:00Z`);
  const target = new Date(`${targetStr}T00:00:00Z`);

  if (target < start) return false;
  
  if (schedule.endDate) {
    const endStr = getLocalDateStrForOffset(new Date(schedule.endDate), timezone);
    const end = new Date(`${endStr}T00:00:00Z`);
    if (target > end) return false;
  }

  if (schedule.frequency === 'daily') {
    return true;
  }

  if (schedule.frequency === 'weekly' || schedule.frequency === 'specific_days') {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const currentDayName = days[target.getUTCDay()];
    return schedule.specificDays.includes(currentDayName);
  }

  if (schedule.frequency === 'interval') {
    const diffTime = Math.abs(target - start);
    const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));
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
      const timezone = schedule.timezone || '+05:30';
      const targetDatePart = getLocalDateStrForOffset(targetDate, timezone);

      for (const timeStr of schedule.times) {
        // Build the specific due time for today in schedule's timezone
        const dueTime = new Date(`${targetDatePart}T${timeStr}:00${timezone}`);

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
            status: 'missed',
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

  // We want to calculate the start date relative to the user's timezone (defaulting to +05:30)
  const defaultTimezone = '+05:30';
  const todayStr = getLocalDateStrForOffset(new Date(), defaultTimezone);
  const localToday = new Date(`${todayStr}T00:00:00${defaultTimezone}`);
  
  const startDate = new Date(localToday);
  startDate.setDate(startDate.getDate() - daysLimit);

  try {
    const query = {
      userId: req.user._id,
      dueTime: { $gte: startDate }
    };
    if (familyMemberId) {
      query.familyMemberId = familyMemberId === 'null' ? null : familyMemberId;
    }

    const logs = await DoseLog.find(query);
    const schedules = await MedicineSchedule.find({ userId: req.user._id });

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

    // Populate daily trends relative to the local today date in local timezone
    for (let i = 0; i < daysLimit; i++) {
      const d = new Date(localToday);
      d.setDate(d.getDate() - i);
      const dateStr = getLocalDateStrForOffset(d, defaultTimezone);
      stats.dailyTrend[dateStr] = { taken: 0, total: 0 };
    }

    logs.forEach(log => {
      const schedule = schedules.find(s => s._id.toString() === log.scheduleId.toString());
      const timezone = schedule ? (schedule.timezone || defaultTimezone) : defaultTimezone;
      const dateStr = getLocalDateStrForOffset(new Date(log.dueTime), timezone);
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
