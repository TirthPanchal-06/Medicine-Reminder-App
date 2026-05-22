const MedicineSchedule = require('../models/MedicineSchedule');
const DoseLog = require('../models/DoseLog');
const PushSubscription = require('../models/PushSubscription');
const { webpush } = require('../config/vapid');

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

// Get local time string HH:MM for a given Date and timezone offset string (e.g. '+05:30')
const getLocalTimeStrForOffset = (now, offsetStr) => {
  const sign = offsetStr[0] === '-' ? -1 : 1;
  const hours = parseInt(offsetStr.slice(1, 3));
  const minutes = parseInt(offsetStr.slice(4, 6));
  const offsetMs = sign * (hours * 60 + minutes) * 60 * 1000;
  
  const localTime = new Date(now.getTime() + offsetMs);
  
  const localHour = localTime.getUTCHours().toString().padStart(2, '0');
  const localMin = localTime.getUTCMinutes().toString().padStart(2, '0');
  return `${localHour}:${localMin}`;
};

// Frequency check logic matching controllers/doseController.js (timezone-aware)
const shouldScheduleRunOnDate = (schedule, targetDate) => {
  const timezone = schedule.timezone || '+05:30';
  
  const startStr = getLocalDateStrForOffset(new Date(schedule.startDate), timezone);
  const targetStr = getLocalDateStrForOffset(new Date(targetDate), timezone);
  
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

// Scheduler core runner
const checkAndDispatchReminders = async () => {
  try {
    const now = new Date();

    // 1. Fetch all active schedules
    const schedules = await MedicineSchedule.find({ isActive: true });
    
    for (const schedule of schedules) {
      // Check if it should run today relative to timezone
      if (!shouldScheduleRunOnDate(schedule, now)) continue;

      const timezone = schedule.timezone || '+05:30';
      const targetDatePart = getLocalDateStrForOffset(now, timezone);
      const currentTimeStr = getLocalTimeStrForOffset(now, timezone);

      for (const timeStr of schedule.times) {
        // Build specific due time for today in schedule's timezone
        const dueTime = new Date(`${targetDatePart}T${timeStr}:00${timezone}`);

        // 2. Ensure DoseLog entry is created in DB
        let log = await DoseLog.findOne({
          scheduleId: schedule._id,
          dueTime: dueTime
        });

        if (!log) {
          log = new DoseLog({
            scheduleId: schedule._id,
            userId: schedule.userId,
            familyMemberId: schedule.familyMemberId,
            dueTime: dueTime,
            status: 'missed', // default compliance state is missed until taken/skipped
            takenTime: null
          });
          await log.save();
          console.log(`[Scheduler] Generated compliance DoseLog for ${schedule.name} at ${timeStr} (${timezone})`);
        }

        // 3. If the scheduled time matches the current local time EXACTLY (minute-granularity), trigger notifications!
        if (timeStr === currentTimeStr) {
          console.log(`[Scheduler] Matches trigger! Dispatching reminder for "${schedule.name}" at ${timeStr} (Local: ${currentTimeStr}, Timezone: ${timezone})`);
          
          // Find subscriptions for the schedule's user
          const subscriptions = await PushSubscription.find({ userId: schedule.userId });
          
          if (subscriptions.length === 0) {
            console.log(`[Scheduler] No active push subscriptions found for User ID: ${schedule.userId}. Logging mock notification.`);
            continue;
          }

          const payload = JSON.stringify({
            title: `Time for your medicine! 💊`,
            body: `Please take your dosage: ${schedule.dosage} of ${schedule.name}. ${schedule.instructions ? '(' + schedule.instructions + ')' : ''}`,
            data: {
              scheduleId: schedule._id,
              doseLogId: log._id,
              medicineName: schedule.name,
              dosage: schedule.dosage
            }
          });

          // Dispatch to all registered client devices
          for (const sub of subscriptions) {
            try {
              const pushSubscription = {
                endpoint: sub.endpoint,
                keys: {
                  p256dh: sub.keys.p256dh,
                  auth: sub.keys.auth
                }
              };

              await webpush.sendNotification(pushSubscription, payload);
              console.log(`[Scheduler] Sent web push notification to endpoint: ${sub.endpoint.slice(0, 45)}...`);
            } catch (err) {
              console.error(`[Scheduler] Error sending web push:`, err.message);
              
              // Handle expired subscriptions (410 Gone / 404 Not Found)
              if (err.statusCode === 410 || err.statusCode === 404) {
                console.log(`[Scheduler] Subscription expired. Cleaning up subscription ID: ${sub._id}`);
                await PushSubscription.findByIdAndDelete(sub._id);
              }
            }
          }
        }
      }
    }
  } catch (error) {
    console.error('[Scheduler Critical Error]:', error.message);
  }
};

let schedulerInterval = null;

const startScheduler = () => {
  if (schedulerInterval) return;
  
  console.log('Background Medicine Reminder Scheduler initialized.');
  
  // Run checks once immediately on start
  checkAndDispatchReminders();

  // Run checks every 60 seconds
  schedulerInterval = setInterval(checkAndDispatchReminders, 60000);
};

const stopScheduler = () => {
  if (schedulerInterval) {
    clearInterval(schedulerInterval);
    schedulerInterval = null;
    console.log('Background Medicine Reminder Scheduler stopped.');
  }
};

module.exports = {
  startScheduler,
  stopScheduler
};
