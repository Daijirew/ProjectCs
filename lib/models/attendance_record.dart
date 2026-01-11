import 'package:flutter/material.dart';

class AttendanceRecord {
  final String id;
  final DateTime date;
  final TimeOfDay checkInTime;
  final TimeOfDay? checkOutTime;
  final String? note;
  final String? imagePath;
  final bool isCompleted;

  AttendanceRecord({
    required this.id,
    required this.date,
    required this.checkInTime,
    this.checkOutTime,
    this.note,
    this.imagePath,
    this.isCompleted = false,
  });

  // แปลงข้อมูลเป็น Map เพื่อเก็บใน SharedPreferences หรือฐานข้อมูล
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'checkInTime': '${checkInTime.hour}:${checkInTime.minute}',
      'checkOutTime': checkOutTime != null
          ? '${checkOutTime!.hour}:${checkOutTime!.minute}'
          : null,
      'note': note,
      'imagePath': imagePath,
      'isCompleted': isCompleted,
    };
  }

  // สร้าง AttendanceRecord จาก Map
  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    // แปลงสตริงเวลาเป็น TimeOfDay
    TimeOfDay _parseTimeOfDay(String? timeString) {
      if (timeString == null) return TimeOfDay.now();
      final parts = timeString.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    // แปลง checkOutTime ถ้ามี
    TimeOfDay? checkOutTime;
    if (map['checkOutTime'] != null) {
      checkOutTime = _parseTimeOfDay(map['checkOutTime']);
    }

    return AttendanceRecord(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      checkInTime: _parseTimeOfDay(map['checkInTime']),
      checkOutTime: checkOutTime,
      note: map['note'],
      imagePath: map['imagePath'],
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}
