import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:myproject/pages.dart/sitterscreen/bookingService.dart';

class BookingScreen extends StatefulWidget {
  final String sitterId;
  final List<DateTime> selectedDates;
  final double pricePerDay;

  const BookingScreen({
    Key? key,
    required this.sitterId,
    required this.selectedDates,
    required this.pricePerDay,
  }) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Add this line
  final TextEditingController _notesController = TextEditingController();
  final BookingService _bookingService = BookingService();
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ฟังก์ชันสำหรับการยืนยันการจอง
  Future<void> _confirmBooking() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Using the BookingService to handle the transaction
      final bookingId = await _bookingService.createBooking(
        sitterId: widget.sitterId,
        dates: widget.selectedDates,
        totalPrice: widget.pricePerDay * widget.selectedDates.length,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      // Show success message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('จองสำเร็จ')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ตรวจสอบว่าวันที่เลือกยังว่างอยู่
  Future<bool> _checkDateAvailability() async {
    try {
      final bookingSnapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: widget.sitterId)
          .where('status', whereIn: ['pending', 'confirmed']).get();

      // ตรวจสอบการซ้ำซ้อนของวันที่
      for (var booking in bookingSnapshot.docs) {
        List<Timestamp> bookedDates = List<Timestamp>.from(booking['dates']);
        for (var bookedDate in bookedDates) {
          if (widget.selectedDates
              .any((date) => isSameDay(date, bookedDate.toDate()))) {
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      print('Error checking availability: $e');
      return false;
    }
  }

  // เปรียบเทียบวันที่
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Details'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Dates:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            // Display selected dates
            ...widget.selectedDates.map(
              (date) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(DateFormat('yyyy-MM-dd').format(date)),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Price per Day: \$${widget.pricePerDay}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Additional Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _confirmBooking,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('Confirm Booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
