import 'package:cloud_firestore/cloud_firestore.dart';

class BookingCleanupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> runCleanupTasks() async {
    try {
      print('Running booking cleanup tasks...');
      await _checkExpiredBookings();
    } catch (e) {
      print('Error in booking cleanup: $e');
    }
  }

  Future<void> _checkExpiredBookings() async {
    try {
      // ดึงเวลาปัจจุบัน
      final now = DateTime.now();
      print('Checking expired bookings at: ${now.toString()}');

      // ค้นหาคำขอที่มีสถานะ pending และหมดเวลาแล้ว
      final expiredBookingsSnapshot = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .where('expirationTime', isLessThan: Timestamp.fromDate(now))
          .get();

      print(
          'Found ${expiredBookingsSnapshot.docs.length} expired booking requests');

      // อัพเดตสถานะคำขอที่หมดเวลา
      final batch = _firestore.batch();
      final List<String> processedBookings = [];

      for (var doc in expiredBookingsSnapshot.docs) {
        final bookingId = doc.id;
        final data = doc.data();
        final userId = data['userId'];
        final sitterId = data['sitterId'];

        processedBookings.add(bookingId);
        print('Processing expired booking: $bookingId');

        // อัพเดตสถานะเป็น expired
        batch.update(doc.reference, {
          'status': 'expired',
          'cancelReason': 'คำขอหมดเวลาอัตโนมัติหลังจาก 15 นาที',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // สร้างการแจ้งเตือนให้แอดมิน
        final adminNotifRef =
            _firestore.collection('admin_notifications').doc();
        batch.set(adminNotifRef, {
          'title': 'คำขอการจองหมดเวลา',
          'message':
              'คำขอการจอง $bookingId ได้หมดเวลาแล้วและถูกยกเลิกโดยอัตโนมัติ',
          'type': 'booking_expired',
          'bookingId': bookingId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        // สร้างการแจ้งเตือนให้ผู้ใช้
        if (userId != null) {
          final userNotifRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .doc();

          batch.set(userNotifRef, {
            'title': 'คำขอการจองหมดเวลา',
            'message':
                'คำขอการจองของคุณได้หมดเวลาแล้ว กรุณาทำรายการใหม่อีกครั้ง',
            'type': 'booking_expired',
            'bookingId': bookingId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }

        // สร้างการแจ้งเตือนให้ผู้รับเลี้ยง
        if (sitterId != null) {
          final sitterNotifRef = _firestore
              .collection('users')
              .doc(sitterId)
              .collection('notifications')
              .doc();

          batch.set(sitterNotifRef, {
            'title': 'คำขอการจองหมดเวลา',
            'message': 'คำขอการจองได้หมดเวลาแล้ว',
            'type': 'booking_expired',
            'bookingId': bookingId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }

      // ประมวลผลการเปลี่ยนแปลงทั้งหมด
      await batch.commit();

      if (processedBookings.isNotEmpty) {
        print(
            'Successfully processed expired bookings: ${processedBookings.join(", ")}');
      } else {
        print('No expired bookings to process');
      }
    } catch (e) {
      print('Error checking expired bookings: $e');
    }
  }
}

// ต่อท้ายเมธอด runCleanupTasks ที่มีอยู่แล้ว
Future<void> _triggerFirebaseFunction() async {
  try {
    // สร้างหรืออัพเดตเอกสาร trigger ใน Firestore
    await FirebaseFirestore.instance
        .collection('triggers')
        .doc('checkExpiredBookings')
        .set({
      'lastTriggered': FieldValue.serverTimestamp(),
      'triggeredBy': 'app',
      'automatic': true
    });

    print('Triggered Firebase Function via Firestore document update');
  } catch (e) {
    print('Error triggering Firebase Function: $e');
  }
}
