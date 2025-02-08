import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class BookingScreen extends StatefulWidget {
  // พารามิเตอร์ที่จำเป็นสำหรับการจอง
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
  // ตัวควบคุมและตัวแปรสถานะ
  final TextEditingController _notesController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ฟังก์ชันสำหรับการยืนยันการจอง
  Future<void> _confirmBooking() async {
    // ตรวจสอบการล็อกอิน
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเข้าสู่ระบบก่อนทำการจอง'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ตรวจสอบว่าผู้รับเลี้ยงยังมีอยู่ในระบบ
      final sitterDoc =
          await _firestore.collection('users').doc(widget.sitterId).get();
      if (!sitterDoc.exists) {
        throw Exception('ไม่พบข้อมูลผู้รับเลี้ยง');
      }

      // ตรวจสอบว่าวันที่เลือกยังว่างอยู่
      final isAvailable = await _checkDateAvailability();
      if (!isAvailable) {
        throw Exception('วันที่เลือกไม่ว่างแล้ว กรุณาเลือกวันใหม่');
      }

      // สร้างการจองใหม่
      await _firestore.collection('bookings').add({
        'userId': _auth.currentUser!.uid,
        'sitterId': widget.sitterId,
        'dates': widget.selectedDates
            .map((date) => Timestamp.fromDate(date))
            .toList(),
        'totalPrice': widget.pricePerDay * widget.selectedDates.length,
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // แสดงการจองสำเร็จและกลับไปหน้าแรก
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('จองสำเร็จ')),
      );
    } catch (e) {
      if (!mounted) return;
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
        title: const Text('Confirm Booking'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ส่วนแสดงรายละเอียดการจอง
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Booking Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Sitter:', widget.sitterId),
                    _buildDetailRow(
                      'Selected Dates:',
                      DateFormat('dd MMM yyyy').format(widget.selectedDates[0]),
                    ),
                    _buildDetailRow(
                      'Number of Days:',
                      '${widget.selectedDates.length} days',
                    ),
                    _buildDetailRow(
                      'Price per Day:',
                      '${widget.pricePerDay.toStringAsFixed(0)} Baht',
                    ),
                    const Divider(height: 32),
                    _buildDetailRow(
                      'Total Price:',
                      '${(widget.pricePerDay * widget.selectedDates.length).toStringAsFixed(0)} Baht',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ส่วนหมายเหตุถึงผู้รับเลี้ยง
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Note to Sitter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'Add additional information or special care instructions for your cat',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _confirmBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Confirm Booking'),
          ),
        ),
      ),
    );
  }

  // สร้างแถวแสดงรายละเอียด
  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
