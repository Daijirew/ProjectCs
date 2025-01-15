import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotifiationServices {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final AndroidInitializationSettings androidInitializationSettings =
      AndroidInitializationSettings('app_icon');

  void initialNotification() async {
    InitializationSettings initializationSettings =
        InitializationSettings(android: androidInitializationSettings);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void sendNotification() async {
    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('Channel ID', 'Channel title',
            priority: Priority.max, importance: Importance.max);
    NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(0, 'This is the title',
        'Hi there is some surprise for you.', notificationDetails);
  }

  void scheduleNotification() async {
    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('Channel ID', 'Channel title',
            priority: Priority.max, importance: Importance.max);
    NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.periodicallyShow(
        0,
        'This is the title',
        'Hi there is some surprise for you.',
        RepeatInterval.everyMinute,
        notificationDetails,
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle); // Add this line
  }

  void stopNoti() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
