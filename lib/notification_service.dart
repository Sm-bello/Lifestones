import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {},
    );

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

  static Future<void> showClassReminder(String day) async {
    await _showLocal(
      title: '⛪ $day Class starts in 30 minutes',
      body: 'Lifestones discipleship class is about to begin. Get ready to join!',
    );
  }

  static Future<void> sendMeetingStarted(String starterName) async {
    await _showLocal(
      title: '🔴 Class Started!',
      body: '$starterName has started the class. Tap to join now!',
    );
  }

  static Future<void> sendNewMessage(String senderName, String preview) async {
    await _showLocal(
      title: '💬 $senderName',
      body: preview,
    );
  }
}
