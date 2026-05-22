import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/medicine_schedule_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    if (_isInitialized) return;

    // Initialize Timezone database
    tz.initializeTimeZones();
    try {
      final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
    } catch (e) {
      print('Could not set local timezone: $e. Falling back to UTC.');
      tz.setLocalLocation(tz.getLocation('UTC'));
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
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _isInitialized = true;
    print('NotificationService initialized successfully.');
  }

  static Future<void> scheduleMedicineNotifications(MedicineScheduleModel schedule) async {
    if (kIsWeb) return;

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
    
    final int baseHash = scheduleId.hashCode;
    // Cancel the potential slots for this schedule
    for (int i = 0; i < 10; i++) {
      await _localNotifications.cancel(baseHash + i);
      // Cancel specific day schedules (baseHash + i + day*1000)
      for (int day = 1; day <= 7; day++) {
        await _localNotifications.cancel(baseHash + i + day * 1000);
      }
    }
  }

  static Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _localNotifications.cancelAll();
  }
}
