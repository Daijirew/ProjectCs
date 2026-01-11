// lib/services/firebase_messaging_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

// ฟังก์ชันที่จะทำงานเมื่อได้รับข้อความในขณะที่แอปทำงานในพื้นหลัง
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");

  // ถ้าเป็นการแจ้งเตือนเกี่ยวกับการหมดเวลาของคำขอ
  if (message.data['type'] == 'booking_expired') {
    // ทำการแสดงการแจ้งเตือนหรือดำเนินการอื่นๆ
  }
}

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // ตั้งค่า handler สำหรับข้อความในพื้นหลัง
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // ขอสิทธิ์การแจ้งเตือน
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // ลงทะเบียนเพื่อรับข้อความ
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Got a message whilst in the foreground!");
      print("Message data: ${message.data}");

      if (message.notification != null) {
        print("Message also contained a notification: ${message.notification}");
      }
    });

    // บันทึก FCM token ในฐานข้อมูล
    String? token = await _firebaseMessaging.getToken();
    await _saveTokenToDatabase(token);

    // ฟังการเปลี่ยนแปลง token
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);
  }

  // บันทึก FCM token ลงในฐานข้อมูล Firestore
  Future<void> _saveTokenToDatabase(String? token) async {
    if (token == null) return;

    // บันทึก token ในโปรไฟล์ของผู้ใช้
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
      });
      print('FCM Token saved to database: $token');
    }
  }
}
