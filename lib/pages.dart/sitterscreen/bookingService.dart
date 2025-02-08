import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // สร้างการจองใหม่
  Future<String> createBooking({
    required String sitterId,
    required List<DateTime> dates,
    required double totalPrice,
    String? notes,
  }) async {
    try {
      // ตรวจสอบการยืนยันตัวตน
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('กรุณาเข้าสู่ระบบก่อนทำการจอง');
      }

      // ตรวจสอบว่าผู้รับเลี้ยงมีตัวตนอยู่จริง
      final sitterDoc =
          await _firestore.collection('users').doc(sitterId).get();
      if (!sitterDoc.exists) {
        throw Exception('ไม่พบผู้รับเลี้ยงที่เลือก');
      }

      // ตรวจสอบว่าผู้รับเลี้ยงว่างในวันที่เลือก
      final available = await _checkSitterAvailability(sitterId, dates);
      if (!available) {
        throw Exception('ผู้รับเลี้ยงไม่ว่างในวันที่เลือกแล้ว');
      }

      // สร้างเอกสารการจอง
      final bookingRef = await _firestore.collection('bookings').add({
        'userId': currentUser.uid,
        'sitterId': sitterId,
        'dates': dates.map((date) => Timestamp.fromDate(date)).toList(),
        'status': 'pending',
        'totalPrice': totalPrice,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return bookingRef.id;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
            'ไม่สามารถสร้างการจองได้: กรุณาตรวจสอบว่าคุณเข้าสู่ระบบแล้วและลองใหม่อีกครั้ง');
      }
      throw Exception('ไม่สามารถสร้างการจองได้: ${e.message}');
    } catch (e) {
      throw Exception('ไม่สามารถสร้างการจองได้: $e');
    }
  }

  // อัปเดตสถานะการจอง
  Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('ไม่สามารถอัปเดตสถานะการจองได้: $e');
    }
  }

  // ตรวจสอบวันว่างของผู้รับเลี้ยง
  Future<bool> _checkSitterAvailability(
      String sitterId, List<DateTime> dates) async {
    try {
      final sitterDoc =
          await _firestore.collection('users').doc(sitterId).get();
      if (!sitterDoc.exists) return false;

      final sitterData = sitterDoc.data();
      if (sitterData == null || !sitterData.containsKey('availableDates')) {
        return false;
      }

      List<Timestamp> availableDates =
          List<Timestamp>.from(sitterData['availableDates']);
      Set<String> availableDateStrings = availableDates
          .map((timestamp) => _formatDateForComparison(timestamp.toDate()))
          .toSet();

      return dates.every((date) =>
          availableDateStrings.contains(_formatDateForComparison(date)));
    } catch (e) {
      print('เกิดข้อผิดพลาดในการตรวจสอบวันว่าง: $e');
      return false;
    }
  }

  // ฟอร์แมตวันที่สำหรับเปรียบเทียบ
  String _formatDateForComparison(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ดึงการจองทั้งหมดของผู้ใช้
  Stream<QuerySnapshot> getUserBookings() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('กรุณาเข้าสู่ระบบก่อน');
    }

    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ดึงการจองทั้งหมดของผู้รับเลี้ยง
  Stream<QuerySnapshot> getSitterBookings() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('กรุณาเข้าสู่ระบบก่อน');
    }

    return _firestore
        .collection('bookings')
        .where('sitterId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
