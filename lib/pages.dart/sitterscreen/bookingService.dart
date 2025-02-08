import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new booking with proper availability checking
  Future<String> createBooking({
    required String sitterId,
    required List<DateTime> dates,
    required double totalPrice,
    String? notes,
  }) async {
    try {
      // Check authentication
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('กรุณาเข้าสู่ระบบก่อนทำการจอง');
      }

      // Run all checks in a transaction to ensure data consistency
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

        return bookingRef.id;
      });
    } catch (e) {
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
