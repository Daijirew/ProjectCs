import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myproject/Local_Noti/NotiClass.dart';
import 'package:myproject/Admin/NotificationService.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TestNotificationScreen extends StatelessWidget {
  final NotifiationServices _localNoti = NotifiationServices();
  final NotificationService _firebaseNoti = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ทดสอบการแจ้งเตือน'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                _localNoti.sendCustomNotification(
                  title: 'ทดสอบการแจ้งเตือนในแอป',
                  body: 'นี่คือการทดสอบการแจ้งเตือนภายในแอป',
                );
              },
              child: Text('ทดสอบการแจ้งเตือนในแอป'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  // เพิ่มการแจ้งเตือนใน admin_notifications
                  await FirebaseFirestore.instance
                      .collection('admin_notifications')
                      .add({
                    'title': 'ทดสอบการแจ้งเตือน',
                    'message': 'นี่คือการทดสอบการแจ้งเตือนสำหรับ Admin',
                    'type': 'booking_expired',
                    'timestamp': FieldValue.serverTimestamp(),
                    'isRead': false,
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('ส่งการแจ้งเตือนไปยัง Admin สำเร็จ')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                  );
                }
              },
              child: Text('ทดสอบการแจ้งเตือน Admin'),
            ),
          ],
        ),
      ),
    );
  }
}
