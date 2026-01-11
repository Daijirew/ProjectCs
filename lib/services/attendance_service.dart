import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/attendance_record.dart';

class AttendanceService {
  static const String STORAGE_KEY = 'attendance_records';
  final uuid = Uuid();

  // บันทึกการเช็คอิน
  Future<AttendanceRecord> saveCheckIn(
      TimeOfDay checkInTime, String? note, String? imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    final recordId = uuid.v4();

    final record = AttendanceRecord(
      id: recordId,
      date: DateTime.now(),
      checkInTime: checkInTime,
      note: note,
      imagePath: imagePath,
    );

    // อ่านข้อมูลเดิม
    List<AttendanceRecord> records = await getAttendanceRecords();

    // เพิ่มข้อมูลใหม่
    records.add(record);

    // บันทึกลง SharedPreferences
    await _saveRecords(records);

    return record;
  }

  // อัปเดตการเช็คเอาท์
  Future<AttendanceRecord?> saveCheckOut(
      String recordId, TimeOfDay checkOutTime, String? note) async {
    // อ่านข้อมูลทั้งหมด
    List<AttendanceRecord> records = await getAttendanceRecords();

    // หาข้อมูลที่ต้องการอัปเดต
    int index = records.indexWhere((record) => record.id == recordId);
    if (index == -1) return null;

    // สร้างข้อมูลใหม่ที่อัปเดตแล้ว
    final oldRecord = records[index];
    final updatedRecord = AttendanceRecord(
      id: oldRecord.id,
      date: oldRecord.date,
      checkInTime: oldRecord.checkInTime,
      checkOutTime: checkOutTime,
      note: note ?? oldRecord.note,
      imagePath: oldRecord.imagePath,
      isCompleted: true,
    );

    // อัปเดตข้อมูล
    records[index] = updatedRecord;

    // บันทึกลง SharedPreferences
    await _saveRecords(records);

    return updatedRecord;
  }

  // ดึงข้อมูลทั้งหมด
  Future<List<AttendanceRecord>> getAttendanceRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsString = prefs.getString(STORAGE_KEY);

    if (recordsString == null) return [];

    final List<dynamic> decodedRecords = jsonDecode(recordsString);
    return decodedRecords
        .map((record) => AttendanceRecord.fromMap(record))
        .toList();
  }

  // บันทึกข้อมูลทั้งหมด
  Future<void> _saveRecords(List<AttendanceRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedRecords = jsonEncode(
      records.map((record) => record.toMap()).toList(),
    );
    await prefs.setString(STORAGE_KEY, encodedRecords);
  }

  // แก้ไขฟังก์ชัน ดึงข้อมูลประวัติของวันนี้
  Future<AttendanceRecord?> getTodayRecord() async {
    final records = await getAttendanceRecords();
    final now = DateTime.now();

    // ถ้าไม่มีข้อมูล
    if (records.isEmpty) return null;

    // ตรวจสอบว่าเป็นวันนี้จริงๆ
    try {
      final todayRecords = records.where((record) {
        final recordDate = DateTime(
          record.date.year,
          record.date.month,
          record.date.day,
        );
        final today = DateTime(now.year, now.month, now.day);

        // เปรียบเทียบวันที่แบบไม่รวมเวลา
        return recordDate.isAtSameMomentAs(today);
      }).toList();

      // ถ้ามีข้อมูลของวันนี้
      if (todayRecords.isNotEmpty) {
        return todayRecords.last; // เอาข้อมูลล่าสุดของวันนี้
      } else {
        return null; // ไม่พบข้อมูลของวันนี้
      }
    } catch (e) {
      print("เกิดข้อผิดพลาดในการโหลดข้อมูลวันนี้: $e");
      return null;
    }
  }

  // เพิ่มฟังก์ชันตรวจสอบว่าวันนี้มีการเช็คอินหรือไม่
  Future<bool> isCheckedInToday() async {
    final todayRecord = await getTodayRecord();
    return todayRecord != null;
  }

  // เพิ่มฟังก์ชันลบประวัติ
  Future<bool> deleteRecord(String recordId) async {
    try {
      // อ่านข้อมูลทั้งหมด
      List<AttendanceRecord> records = await getAttendanceRecords();

      // เก็บจำนวนรายการเดิม
      int initialLength = records.length;

      // ลบข้อมูลตาม id
      records.removeWhere((record) => record.id == recordId);

      // ตรวจสอบว่าได้ลบข้อมูลจริงหรือไม่
      if (initialLength == records.length) {
        print('ไม่พบรายการที่ต้องการลบ ID: $recordId');
        return false;
      }

      // บันทึกข้อมูลที่เหลือกลับไป
      await _saveRecords(records);

      print('ลบรายการ ID: $recordId สำเร็จ');
      return true;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการลบประวัติ: $e');
      return false;
    }
  }

  // เพิ่มฟังก์ชันลบประวัติทั้งหมด
  Future<bool> deleteAllRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool success = await prefs.remove(STORAGE_KEY);
      print('ลบประวัติทั้งหมด: $success');
      return success;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการลบประวัติทั้งหมด: $e');
      return false;
    }
  }
}
