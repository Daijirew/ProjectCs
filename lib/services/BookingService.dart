import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myproject/Admin/NotificationService.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // ฟังก์ชันตรวจสอบคำขอที่หมดเวลา (เรียกใช้จาก background task หรือ Cloud Function)
  // ฟังก์ชัน checkExpiredBookings() ประมาณบรรทัด 10-25
// ปรับแต่งส่วนที่ตรวจสอบการหมดเวลาและส่งการแจ้งเตือน
  Future<void> checkExpiredBookings() async {
    try {
      final pendingBookings = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .get();

      final now = DateTime.now();

      for (var booking in pendingBookings.docs) {
        final data = booking.data();

        if (!data.containsKey('expirationTime')) continue;

        final expirationTime = data['expirationTime'] as Timestamp;
        final bookingId = booking.id;

        if (now.isAfter(expirationTime.toDate())) {
          // อัพเดทสถานะเป็น 'expired'
          await booking.reference.update({
            'status': 'expired',
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelReason': 'คำขอหมดเวลา (1 นาที)'
          });

          // เพิ่มการแจ้งเตือน
          await _firestore.collection('notifications').add({
            'title': 'คำขอหมดอายุ',
            'message': bookingId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false
          });
        }
      }
    } catch (e) {
      print('Error checking expired bookings: $e');
    }
  }

// เพิ่มฟังก์ชันใหม่สำหรับส่งการแจ้งเตือนไปยัง admin
  Future<void> _sendAdminNotification(String bookingId) async {
    try {
      // สร้างการแจ้งเตือนในคอลเล็กชัน admin_notifications
      await _firestore.collection('admin_notifications').add({
        'title': 'คำขอการจองหมดเวลา',
        'message':
            'คำขอการจอง $bookingId ได้หมดเวลาแล้วและถูกยกเลิกโดยอัตโนมัติ',
        'type': 'booking_expired',
        'bookingId': bookingId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Error sending admin notification: $e');
    }
  }

  // ฟังก์ชันสำหรับ admin หรือ sitter ในการยกเลิกคำขอ
  Future<void> cancelBooking({
    required String bookingId,
    required String cancelledBy,
    required String reason,
  }) async {
    try {
      DocumentSnapshot bookingSnapshot =
          await _firestore.collection('bookings').doc(bookingId).get();

      if (!bookingSnapshot.exists) {
        throw Exception('ไม่พบข้อมูลการจอง');
      }

      Map<String, dynamic> bookingData =
          bookingSnapshot.data() as Map<String, dynamic>;

      // อัพเดทสถานะเป็น 'cancelled'
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': cancelledBy,
        'cancelReason': reason
      });

      // แจ้งเตือนเจ้าของแมว
      await _notificationService.sendBookingStatusNotification(
        userId: bookingData['userId'],
        bookingId: bookingId,
        status: 'cancelled',
        message: 'การจองของคุณถูกยกเลิก: $reason',
      );

      // แจ้งเตือน sitter ถ้าผู้ยกเลิกไม่ใช่ sitter เอง
      if (cancelledBy != bookingData['sitterId']) {
        await _notificationService.sendBookingStatusNotification(
          userId: bookingData['sitterId'],
          bookingId: bookingId,
          status: 'cancelled',
          message: 'การจองถูกยกเลิก: $reason',
        );
      }
    } catch (e) {
      print('Error cancelling booking: $e');
      throw Exception('ไม่สามารถยกเลิกการจองได้: $e');
    }
  }

  // ฟังก์ชันสำหรับรับฟังการเปลี่ยนแปลงของการจองที่ใกล้หมดเวลา
  Stream<QuerySnapshot> getNearExpiringBookings() {
    final now = DateTime.now();
    final inFiveMinutes = now.add(Duration(minutes: 5));

    return _firestore
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .where('expirationTime', isGreaterThan: Timestamp.fromDate(now))
        .where('expirationTime', isLessThan: Timestamp.fromDate(inFiveMinutes))
        .snapshots();
  }
}
