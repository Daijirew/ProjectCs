import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/pages.dart/booking.dart/BookingRequestCard.dart';

import 'package:myproject/services/BookingService.dart';

class PendingBookingsScreen extends StatefulWidget {
  final bool isSitter;

  const PendingBookingsScreen({
    Key? key,
    this.isSitter = false,
  }) : super(key: key);

  @override
  State<PendingBookingsScreen> createState() => _PendingBookingsScreenState();
}

class _PendingBookingsScreenState extends State<PendingBookingsScreen> {
  final BookingService _bookingService = BookingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    // เรียกฟังก์ชันตรวจสอบคำขอที่หมดเวลาทุกครั้งที่เข้าหน้านี้
    _bookingService.checkExpiredBookings();
  }

  Stream<QuerySnapshot> _getBookings() {
    final field = widget.isSitter ? 'sitterId' : 'userId';

    return _firestore
        .collection('bookings')
        .where(field, isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isSitter ? 'คำขอรับเลี้ยงแมว' : 'คำขอของฉัน',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
            );
          }

          final bookings = snapshot.data?.docs ?? [];

          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'ไม่มีคำขอรับเลี้ยงแมว',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index].data() as Map<String, dynamic>;
              final bookingId = bookings[index].id;

              return BookingRequestCard(
                booking: booking,
                bookingId: bookingId,
                isSitter: widget.isSitter,
                onUpdate: () => setState(() {}),
              );
            },
          );
        },
      ),
    );
  }
}
