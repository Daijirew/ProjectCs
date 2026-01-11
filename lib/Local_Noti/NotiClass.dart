import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotifiationServices {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final AndroidInitializationSettings androidInitializationSettings =
      AndroidInitializationSettings('app_icon');

  void initialNotification() async {
    InitializationSettings initializationSettings =
        InitializationSettings(android: androidInitializationSettings);

    // เพิ่มการจัดการการคลิกที่การแจ้งเตือน
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // ทำตามการกระทำที่ต้องการเมื่อผู้ใช้คลิกที่การแจ้งเตือน
        print('Notification clicked: ${details.payload}');
      },
    );

    // ขออนุญาตบนระบบ iOS (ถ้าใช้)
    // flutterLocalNotificationsPlugin
    //     .resolvePlatformSpecificImplementation
    //         IOSFlutterLocalNotificationsPlugin>()
    //     ?.requestPermissions(
    //       alert: true,
    //       badge: true,
    //       sound: true,
    //     );
  }

  void sendNotification() async {
    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'booking_channel',
      'การจองแมว',
      channelDescription: 'แจ้งเตือนเกี่ยวกับการจองแมว',
      priority: Priority.max,
      importance: Importance.max,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
    );

    NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
        0, 'การแจ้งเตือน', 'มีการแจ้งเตือนใหม่', notificationDetails);
  }

  // เพิ่มฟังก์ชันใหม่เพื่อให้สามารถกำหนดข้อความได้
  Future<void> sendCustomNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'booking_channel',
      'การจองแมว',
      channelDescription: 'แจ้งเตือนเกี่ยวกับการจองแมว',
      priority: Priority.max,
      importance: Importance.max,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
    );

    NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now()
          .millisecond, // ใช้เวลาปัจจุบันเป็น ID เพื่อให้แน่ใจว่าไม่ซ้ำกัน
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // ฟังก์ชันเดิม...
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
  }

  void stopNoti() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
