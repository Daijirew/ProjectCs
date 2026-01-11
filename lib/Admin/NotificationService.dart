import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:myproject/Local_Noti/NotiClass.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final NotifiationServices _localNotifications = NotifiationServices();

  // ส่งการแจ้งเตือนเมื่อสถานะการจองเปลี่ยนแปลง
  Future<void> sendBookingStatusNotification({
    required String userId,
    required String bookingId,
    required String status,
    required String message,
  }) async {
    try {
      // สร้างข้อมูลการแจ้งเตือน
      Map<String, dynamic> notificationData = {
        'userId': userId,
        'bookingId': bookingId,
        'status': status,
        'message': message,
        'isRead': false,
        'type': bookingId.isNotEmpty ? 'booking' : 'system',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // บันทึกลงใน Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add(notificationData);

      // ดึง FCM token สำหรับการส่งแจ้งเตือนแบบ push notification
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final fcmToken = userData['fcmToken'];

        if (fcmToken != null && fcmToken.toString().isNotEmpty) {
          await _sendPushNotification(
            token: fcmToken,
            title: _getNotificationTitle(status),
            body: message,
            data: {
              'type': bookingId.isNotEmpty ? 'booking' : 'system',
              'bookingId': bookingId,
              'status': status,
            },
          );
        }
      }

      // เพิ่มการแจ้งเตือนภายในแอปด้วย
      _localNotifications.sendCustomNotification(
        title: _getNotificationTitle(status),
        body: message,
        payload: bookingId,
      );

      print(
          'Notification sent successfully to user $userId about booking $bookingId');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // แก้ไขฟังก์ชัน _sendPushNotification ให้ใช้ FCM HTTP v1 API ซึ่งเป็นวิธีที่แนะนำในปัจจุบัน
  Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // ควรใช้ Cloud Function หรือเซิร์ฟเวอร์ของคุณเองเพื่อส่ง FCM
      // แต่เพื่อความเข้าใจง่าย เราจะแสดงวิธีใช้ HTTP API โดยตรง (ไม่แนะนำในโปรดักชัน)

      // หมายเหตุ: คุณต้องใช้ server key จาก Firebase Console > Project Settings > Cloud Messaging
      const serverKey = 'YOUR_SERVER_KEY'; // แทนที่ด้วย FCM server key ของคุณ

      final url = Uri.parse('https://fcm.googleapis.com/fcm/send');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      };

      final message = {
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
        },
        'data': data,
        'to': token,
        'priority': 'high',
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        print('FCM notification sent successfully');
      } else {
        print('Error sending FCM: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  // แปลงสถานะเป็นหัวข้อการแจ้งเตือน
  String _getNotificationTitle(String status) {
    switch (status) {
      case 'pending':
        return 'การจองใหม่';
      case 'confirmed':
        return 'การจองได้รับการยืนยัน';
      case 'in_progress':
        return 'การดูแลแมวเริ่มแล้ว';
      case 'completed':
        return 'การบริการเสร็จสิ้น';
      case 'cancelled':
        return 'การจองถูกยกเลิก';
      case 'auto_cancelled':
        return 'การจองถูกยกเลิกอัตโนมัติ';
      case 'deleted':
        return 'การจองถูกลบโดยแอดมิน';
      case 'approval':
        return 'คำขอเป็นพี่เลี้ยงได้รับการอนุมัติ';
      case 'rejection':
        return 'คำขอเป็นพี่เลี้ยงถูกปฏิเสธ';
      default:
        return 'การแจ้งเตือนใหม่';
    }
  }

  // ฟังก์ชันเดิม...
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markNotificationAsRead(
      String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }
}
