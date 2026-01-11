import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createBooking({
    required String sitterId,
    required List<DateTime> dates,
    required double totalPrice,
    String? notes,
    List<String>? catIds,
    required double currentWallet,
    required double newWallet,
  }) async {
    try {
      // Check authentication
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('กรุณาเข้าสู่ระบบก่อนทำการจอง');
      }

      // เพิ่มการตรวจสอบว่า sitterId ไม่เป็นค่าว่าง
      if (sitterId.isEmpty) {
        throw Exception('ไม่พบข้อมูล Sitter ID');
      }

      // เพิ่มการตรวจสอบว่า sitterId มีอยู่จริงในฐานข้อมูล
      DocumentSnapshot sitterCheck =
          await _firestore.collection('users').doc(sitterId).get();
      if (!sitterCheck.exists) {
        throw Exception('ไม่พบข้อมูลผู้รับเลี้ยง');
      }

      // ถ้าไม่มี catIds ให้ดึงจาก Firestore
      List<String> selectedCatIds = catIds ?? [];
      if (selectedCatIds.isEmpty) {
        // ดึงข้อมูลแมวที่มีสถานะ isForSitting เป็น true
        final catsSnapshot = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('cats')
            .where('isForSitting', isEqualTo: true)
            .get();

        selectedCatIds = catsSnapshot.docs.map((doc) => doc.id).toList();
      }

      // ใช้ค่า currentWallet และ newWallet ที่ส่งมาแทนการตรวจสอบใหม่
      String newWalletStr = newWallet.toStringAsFixed(0);

      // สร้างการจองและหักเงินในคราวเดียวกันโดยใช้ Transaction
      return await _firestore.runTransaction<String>((transaction) async {
        // Check if sitter exists
        final sitterDoc =
            await transaction.get(_firestore.collection('users').doc(sitterId));

        if (!sitterDoc.exists) {
          throw Exception('ไม่พบผู้รับเลี้ยงที่เลือก');
        }

        // Check sitter's availability for selected dates
        final available = await _checkSitterAvailability(
          transaction,
          sitterId,
          dates,
        );

        if (!available) {
          throw Exception('วันที่เลือกไม่ว่างแล้ว กรุณาเลือกใหม่');
        }

        // Create the booking document
        final bookingRef = _firestore.collection('bookings').doc();

        transaction.set(bookingRef, {
          'userId': currentUser.uid,
          'sitterId': sitterId,
          'dates': dates.map((date) => Timestamp.fromDate(date)).toList(),
          'status': 'pending',
          'totalPrice': totalPrice,
          'notes': notes,
          'catIds': selectedCatIds,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update sitter's availability
        final availableDates =
            (sitterDoc.data()?['availableDates'] ?? []) as List<dynamic>;
        final updatedDates = availableDates.where((timestamp) {
          final date = (timestamp as Timestamp).toDate();
          return !dates.any((selectedDate) => _isSameDay(date, selectedDate));
        }).toList();

        transaction
            .update(sitterDoc.reference, {'availableDates': updatedDates});

        // หักเงินจากกระเป๋าเงินของผู้ใช้
        transaction.update(_firestore.collection('users').doc(currentUser.uid),
            {'wallet': newWalletStr});

        // บันทึกประวัติธุรกรรม
        DocumentReference transactionRef = _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('transactions')
            .doc();

        transaction.set(transactionRef, {
          'amount': totalPrice,
          'type': 'payment',
          'description': 'ชำระค่าบริการรับเลี้ยงแมว',
          'status': 'completed',
          'timestamp': FieldValue.serverTimestamp(),
          'bookingId': bookingRef.id,
          'sitterId': sitterId // เพิ่ม sitterId ในประวัติธุรกรรม
        });

        return bookingRef.id;
      });
    } catch (e) {
      print('Error in createBooking: $e');
      throw Exception(e.toString());
    }
  }

  // Enhanced availability checking within transaction
  Future<bool> _checkSitterAvailability(
    Transaction transaction,
    String sitterId,
    List<DateTime> dates,
  ) async {
    // Get existing bookings for these dates
    final existingBookings = await _firestore
        .collection('bookings')
        .where('sitterId', isEqualTo: sitterId)
        .where('status', whereIn: ['pending', 'confirmed']).get();

    // Check for date conflicts
    for (var booking in existingBookings.docs) {
      List<Timestamp> bookedDates = List<Timestamp>.from(booking['dates']);
      for (var bookedDate in bookedDates) {
        if (dates.any((date) => _isSameDay(date, bookedDate.toDate()))) {
          return false;
        }
      }
    }

    // Get sitter's available dates
    final sitterDoc = await _firestore.collection('users').doc(sitterId).get();
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
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatDateForComparison(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
