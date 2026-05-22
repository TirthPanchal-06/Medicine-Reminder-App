const MedicineSchedule = require('../models/MedicineSchedule');
const DoseLog = require('../models/DoseLog');
const PushSubscription = require('../models/PushSubscription');
const { webpush } = require('../config/vapid');

// Frequency check logic matching controllers/doseController.js
const shouldScheduleRunOnDate = (schedule, targetDate) => {
  const start = new Date(schedule.startDate);
  start.setHours(0, 0, 0, 0);
  const target = new Date(targetDate);
  target.setHours(0, 0, 0, 0);

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

// Scheduler core runner
const checkAndDispatchReminders = async () => {
  try {
    const now = new Date();
    const currentHour = now.getHours().toString().padLeft ? now.getHours().toString().padStart(2, '0') : now.getHours().toString();
    const currentMin = now.getMinutes().toString().padLeft ? now.getMinutes().toString().padStart(2, '0') : now.getMinutes().toString();
    const currentTimeStr = `${currentHour}:${currentMin}`; // e.g. "08:30"

    // 1. Fetch all active schedules
    const schedules = await MedicineSchedule.find({ isActive: true });
    
    for (const schedule of schedules) {
      // Check if it should run today
      if (!shouldScheduleRunOnDate(schedule, now)) continue;

      for (const timeStr of schedule.times) {
        const [hours, minutes] = timeStr.split(':').map(Number);
        
        // Build specific due time for today
        const dueTime = new Date(now);
        dueTime.setHours(hours, minutes, 0, 0);

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
          console.log(`[Scheduler] Generated compliance DoseLog for ${schedule.name} at ${timeStr}`);
        }

        // 3. If the scheduled time matches the current system time EXACTLY (minute-granularity), trigger notifications!
        if (timeStr === currentTimeStr) {
          console.log(`[Scheduler] Matches trigger! Dispatching reminder for "${schedule.name}" at ${timeStr}`);
          
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
