import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Lagos'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _local.initialize(settings);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) {
      _showLocal(
        title: message.notification?.title ?? 'Lifestones',
        body: message.notification?.body ?? '',
      );
    });

    await _scheduleWeeklyReminders();
  }

  static Future<void> _showLocal({
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'lifestones_channel',
        'Lifestones Classes',
        channelDescription: 'Class reminders and announcements',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _local.show(0, title, body, details);
  }

  static Future<void> _scheduleWeeklyReminders() async {
    await _local.cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    final classDays = {
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };

    int id = 10;
    for (final entry in classDays.entries) {
      final scheduled = _nextWeekday(
        now,
        entry.key,
        hour: 17,
        minute: 30,
      );
      await _local.zonedSchedule(
        id++,
        '⛪ ${entry.value} Class starts in 30 minutes',
        'Lifestones discipleship class is about to begin. Get ready to join!',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'lifestones_channel',
            'Lifestones Classes',
            channelDescription: 'Class reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static tz.TZDateTime _nextWeekday(
    tz.TZDateTime from,
    int weekday, {
    required int hour,
    required int minute,
  }) {
    var scheduled = tz.TZDateTime(
      tz.local,
      from.year,
      from.month,
      from.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || scheduled.isBefore(from)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
