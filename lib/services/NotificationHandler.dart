import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:myproject/Local_Noti/NotiClass.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationHandler {
  static final NotificationHandler _instance = NotificationHandler._internal();
  final NotifiationServices _localNotifications = NotifiationServices();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory NotificationHandler() {
    return _instance;
  }

  NotificationHandler._internal();

  Future<void> initialize(BuildContext context) async {
    // เริ่มต้นการแจ้งเตือนในแอป
    _localNotifications.initialNotification();

    // ขอสิทธิ์การแจ้งเตือน
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // กำหนดการจัดการการแจ้งเตือนเมื่อแอปอยู่ในสถานะต่างๆ
    _setupForegroundNotificationHandler();
    _setupBackgroundNotificationHandler();

    // บันทึก FCM token
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print('FCM Token: $token');
      _saveTokenToFirestore(token);
    }

    // ตั้งค่าเพื่อรับ token ใหม่เมื่อมีการเปลี่ยนแปลง
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print('FCM Token refreshed: $newToken');
      _saveTokenToFirestore(newToken);
    });

    // ตรวจสอบการเปิดแอปจากการแจ้งเตือน
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage, context);
    }
  }

  void _setupForegroundNotificationHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message in foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Notification title: ${message.notification!.title}');
        print('Notification body: ${message.notification!.body}');

        // แสดงการแจ้งเตือนในแอป
        _localNotifications.sendCustomNotification(
          title: message.notification!.title ?? 'แจ้งเตือน',
          body: message.notification!.body ?? '',
          payload: message.data['bookingId'],
        );
      }
    });
  }

  void _setupBackgroundNotificationHandler() {
    // การจัดการเมื่อคลิกที่การแจ้งเตือนขณะแอปเปิดอยู่แต่ไม่ได้ใช้งาน
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked in background state!');
      // นำทางไปยังหน้าที่เกี่ยวข้องกับการแจ้งเตือน
    });
  }

  void _saveTokenToFirestore(String token) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({'fcmToken': token})
          .then((_) => print('Token updated in Firestore'))
          .catchError((error) => print('Error updating token: $error'));
    }
  }

  void _handleNotificationClick(RemoteMessage message, BuildContext context) {
    // จัดการเมื่อผู้ใช้คลิกที่การแจ้งเตือน
    // ตัวอย่าง: นำทางไปยังหน้ารายละเอียดการจอง
    if (message.data.containsKey('bookingId')) {
      final bookingId = message.data['bookingId'];
      // นำทางไปยังหน้ารายละเอียดการจอง
      // Navigator.pushNamed(context, '/booking-details', arguments: bookingId);
    }
  }

  // เพิ่มฟังก์ชันสำหรับส่งการแจ้งเตือนในแอปโดยตรง
  void showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) {
    _localNotifications.sendCustomNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }
}
