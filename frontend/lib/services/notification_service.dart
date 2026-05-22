import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/medicine_schedule_model.dart';
import '../models/appointment_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    if (_isInitialized) return;

    // Initialize Timezone database
    tz.initializeTimeZones();
    
    // First try standard getLocalTimezone from FlutterTimezone
    String currentTimeZone = 'UTC';
    bool successfullySet = false;
    try {
      currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
      successfullySet = true;
      print('Timezone set successfully to: $currentTimeZone');
    } catch (e) {
      print('Could not set local timezone using FlutterTimezone: $e. Using dynamic offset-based matching.');
    }

    if (!successfullySet) {
      try {
        final Duration deviceOffset = DateTime.now().timeZoneOffset;
        tz.Location? matchedLocation;
        
        for (var location in tz.timeZoneDatabase.locations.values) {
          final tz.TZDateTime tzNow = tz.TZDateTime.now(location);
          if (tzNow.timeZoneOffset == deviceOffset) {
            if (!location.name.startsWith('Etc/')) {
              matchedLocation = location;
              break;
            }
            matchedLocation ??= location;
          }
        }
        
        if (matchedLocation != null) {
          tz.setLocalLocation(matchedLocation);
          print('Successfully matched device offset $deviceOffset to timezone: ${matchedLocation.name}');
          successfullySet = true;
        }
      } catch (ex) {
        print('Dynamic offset timezone matching failed: $ex');
      }
    }

    if (!successfullySet) {
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
        print('Defaulted timezone to UTC');
      } catch (e) {
        print('Fatal: Could not set timezone to UTC: $e');
      }
    }

    // Android Configuration
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/Darwin Configuration
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification clicked: ${response.payload}');
      },
    );

    // Request permissions for Android 13+
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      print('Notification permission request failed: $e');
    }

    // Request exact alarms permission for Android 12+ (if applicable)
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } catch (e) {
      print('Could not request exact alarms permission: $e');
    }

    _isInitialized = true;
    print('NotificationService initialized successfully.');
  }

  static Future<void> scheduleMedicineNotifications(MedicineScheduleModel schedule) async {
    if (kIsWeb) return;

    try {
      // First cancel any existing notifications for this schedule to avoid duplicates
      await cancelMedicineNotifications(schedule.id);

      if (!schedule.isActive) return;

      final int baseHash = schedule.id.hashCode;
      final DateTime now = DateTime.now();
      final DateTime start = schedule.startDate;
      final DateTime end = schedule.endDate ?? start.add(const Duration(days: 365));

      // If active schedule range has already completed, skip scheduling
      if (end.isBefore(now)) return;

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'medicine_reminder_channel',
        'Medicine Reminders',
        channelDescription: 'Recurring alarms for scheduled medicines',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      for (int i = 0; i < schedule.times.length; i++) {
        final String timeStr = schedule.times[i];
        final parts = timeStr.split(':');
        if (parts.length != 2) continue;
        final int hour = int.parse(parts[0]);
        final int minute = int.parse(parts[1]);

        final notificationId = baseHash + i;

        if (schedule.frequency == 'daily') {
          await _scheduleDaily(notificationId, schedule.name, schedule.dosage, hour, minute, platformDetails);
        } else if (schedule.frequency == 'specific_days') {
          await _scheduleSpecificDays(notificationId, schedule.name, schedule.dosage, hour, minute, schedule.specificDays, platformDetails);
        } else {
          await _scheduleDaily(notificationId, schedule.name, schedule.dosage, hour, minute, platformDetails);
        }
      }
    } catch (e) {
      print('Error in scheduleMedicineNotifications for schedule ${schedule.id}: $e');
    }
  }

  static Future<void> _scheduleDaily(
    int id,
    String name,
    String dosage,
    int hour,
    int minute,
    NotificationDetails details,
  ) async {
    final tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);

    try {
      await _localNotifications.zonedSchedule(
        id,
        'Time for your medicine! 💊',
        'Please take your dosage: $dosage of $name.',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print('Exact alarm scheduling failed: $e. Falling back to inexact scheduling.');
      await _localNotifications.zonedSchedule(
        id,
        'Time for your medicine! 💊',
        'Please take your dosage: $dosage of $name.',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static Future<void> _scheduleSpecificDays(
    int id,
    String name,
    String dosage,
    int hour,
    int minute,
    List<String> days,
    NotificationDetails details,
  ) async {
    final dayInts = days.map((d) => _dayOfWeekToInt(d)).where((day) => day != -1).toList();

    for (int day in dayInts) {
      final tz.TZDateTime scheduledDate = _nextInstanceOfDayAndTime(day, hour, minute);
      final int uniqueId = id + day * 1000;

      try {
        await _localNotifications.zonedSchedule(
          uniqueId,
          'Time for your medicine! 💊',
          'Please take your dosage: $dosage of $name.',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        print('Exact specific days alarm failed: $e. Falling back to inexact.');
        await _localNotifications.zonedSchedule(
          uniqueId,
          'Time for your medicine! 💊',
          'Please take your dosage: $dosage of $name.',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime(int day, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static int _dayOfWeekToInt(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
      case 'mon':
        return DateTime.monday;
      case 'tuesday':
      case 'tue':
        return DateTime.tuesday;
      case 'wednesday':
      case 'wed':
        return DateTime.wednesday;
      case 'thursday':
      case 'thu':
        return DateTime.thursday;
      case 'friday':
      case 'fri':
        return DateTime.friday;
      case 'saturday':
      case 'sat':
        return DateTime.saturday;
      case 'sunday':
      case 'sun':
        return DateTime.sunday;
      default:
        return -1;
    }
  }

  static Future<void> cancelMedicineNotifications(String scheduleId) async {
    if (kIsWeb) return;
    
    try {
      final int baseHash = scheduleId.hashCode;
      // Cancel the potential slots for this schedule
      for (int i = 0; i < 10; i++) {
        await _localNotifications.cancel(baseHash + i);
        // Cancel specific day schedules (baseHash + i + day*1000)
        for (int day = 1; day <= 7; day++) {
          await _localNotifications.cancel(baseHash + i + day * 1000);
        }
      }
    } catch (e) {
      print('Error in cancelMedicineNotifications: $e');
    }
  }

  static Future<void> scheduleAppointmentNotifications(AppointmentModel appointment) async {
    if (kIsWeb) return;

    try {
      // First cancel any existing notifications for this appointment to avoid duplicates
      await cancelAppointmentNotifications(appointment.id);

      final DateTime now = DateTime.now();
      // If the appointment time has already passed, skip scheduling
      if (appointment.dateTime.isBefore(now)) return;

      final int baseHash = appointment.id.hashCode;

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'appointment_reminder_channel',
        'Doctor Appointment Reminders',
        channelDescription: 'Alarms for scheduled doctor appointments',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // 1. Schedule notification at the exact appointment time
      final tz.TZDateTime scheduledExact = tz.TZDateTime.from(appointment.dateTime, tz.local);
      try {
        await _localNotifications.zonedSchedule(
          baseHash,
          'Doctor Appointment Now! 🩺',
          'Your appointment with Dr. ${appointment.doctorName} (${appointment.specialty}) is scheduled now at ${appointment.venue}.',
          scheduledExact,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        print('Exact appointment alarm failed: $e. Falling back to inexact.');
        await _localNotifications.zonedSchedule(
          baseHash,
          'Doctor Appointment Now! 🩺',
          'Your appointment with Dr. ${appointment.doctorName} (${appointment.specialty}) is scheduled now at ${appointment.venue}.',
          scheduledExact,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

      // 2. Schedule notification 1 hour before the appointment
      final DateTime oneHourBefore = appointment.dateTime.subtract(const Duration(hours: 1));
      if (oneHourBefore.isAfter(now)) {
        final tz.TZDateTime scheduledOneHourBefore = tz.TZDateTime.from(oneHourBefore, tz.local);
        try {
          await _localNotifications.zonedSchedule(
            baseHash + 1,
            'Upcoming Doctor Checkup 🩺',
            'Reminder: You have an appointment with Dr. ${appointment.doctorName} in 1 hour at ${appointment.venue}.',
            scheduledOneHourBefore,
            platformDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          print('Exact pre-appointment alarm failed: $e. Falling back to inexact.');
          await _localNotifications.zonedSchedule(
            baseHash + 1,
            'Upcoming Doctor Checkup 🩺',
            'Reminder: You have an appointment with Dr. ${appointment.doctorName} in 1 hour at ${appointment.venue}.',
            scheduledOneHourBefore,
            platformDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    } catch (e) {
      print('Error in scheduleAppointmentNotifications for appointment ${appointment.id}: $e');
    }
  }

  static Future<void> cancelAppointmentNotifications(String appointmentId) async {
    if (kIsWeb) return;
    try {
      final int baseHash = appointmentId.hashCode;
      await _localNotifications.cancel(baseHash);
      await _localNotifications.cancel(baseHash + 1);
    } catch (e) {
      print('Error in cancelAppointmentNotifications: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _localNotifications.cancelAll();
  }
}
