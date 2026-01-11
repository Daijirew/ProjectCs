import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduledTasksManager {
  // Singleton pattern เพื่อให้มีเพียงอินสแตนซ์เดียวทั่วทั้งแอป
  static final ScheduledTasksManager _instance =
      ScheduledTasksManager._internal();
  factory ScheduledTasksManager() => _instance;
  ScheduledTasksManager._internal();

  // ตัวจับเวลาสำหรับตรวจสอบคำขอที่หมดอายุ
  Timer? _expiredBookingsTimer;

  // สถานะการทำงาน
  bool _isRunning = false;

  // เริ่มการทำงานของตัวจับเวลา
  // เพิ่มการตรวจสอบทันทีเมื่อเริ่มต้นแอป (ตรวจสอบเวลา startup)
  void startScheduledTasks() {
    if (!_isRunning) {
      _isRunning = true;

      // เพิ่มบรรทัดนี้ - ตรวจสอบทันทีเมื่อเริ่มแอป
      _checkExpiredBookings();

      // ลดเวลาตรวจสอบเป็นทุกๆ 1 นาที
      _expiredBookingsTimer = Timer.periodic(Duration(seconds: 20), (timer) {
        _checkExpiredBookings();
      });

      print('ScheduledTasksManager: เริ่มการทำงานของตัวตรวจสอบแล้ว');
    }
  }

  // หยุดการทำงานของตัวจับเวลา
  void stopScheduledTasks() {
    if (_isRunning) {
      _expiredBookingsTimer?.cancel();
      _isRunning = false;
      print('ScheduledTasksManager: หยุดการทำงานของตัวตรวจสอบแล้ว');
    }
  }

  // ตรวจสอบคำขอที่หมดอายุ
  Future<void> _checkExpiredBookings() async {
    try {
      print('ScheduledTasksManager: กำลังตรวจสอบคำขอที่หมดอายุ...');

      // เรียกใช้ Cloud Function โดยการอัพเดทเอกสาร trigger
      await FirebaseFirestore.instance
          .collection('triggers')
          .doc('checkExpiredBookings')
          .set({
        'lastTriggered': FieldValue.serverTimestamp(),
        'triggeredBy': 'scheduled_task',
        'timestamp': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      print('ScheduledTasksManager: ส่งคำขอตรวจสอบคำขอที่หมดอายุเรียบร้อยแล้ว');
    } catch (e) {
      print('ScheduledTasksManager: เกิดข้อผิดพลาด - $e');
    }
  }

  // เรียกใช้ฟังก์ชันตรวจสอบคำขอที่หมดอายุโดยตรง
  Future<void> checkExpiredBookingsManually() async {
    return _checkExpiredBookings();
  }
}
