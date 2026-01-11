import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:myproject/services/BookingService.dart';

class BookingRequestCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String bookingId;
  final bool isSitter;
  final Function onUpdate;

  const BookingRequestCard({
    Key? key,
    required this.booking,
    required this.bookingId,
    required this.isSitter,
    required this.onUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat('dd MMM yyyy', 'th');
    final dates = (booking['dates'] as List).map((date) {
      if (date is Timestamp) {
        return dateFormat.format(date.toDate());
      }
      return '';
    }).join(', ');

    final status = booking['status'];
    final expirationTime = booking['expirationTime'] as Timestamp;
    final BookingService bookingService = BookingService();

    bool isPending = status == 'pending';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'คำขอรับเลี้ยงแมว',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isPending)
                  ExpirationCountdown(
                    expirationTime: expirationTime.toDate(),
                    onExpired: () => onUpdate(),
                  ),
              ],
            ),
            Divider(height: 24),
            Text('วันที่ต้องการจ้าง: $dates'),
            SizedBox(height: 8),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(isSitter ? booking['userId'] : booking['sitterId'])
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Text('กำลังโหลดข้อมูล...');
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return Text('ไม่สามารถโหลดข้อมูลได้');
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final name = userData['name'] ?? 'ไม่ระบุชื่อ';

                return Text(
                  isSitter ? 'จาก: $name' : 'ผู้รับเลี้ยง: $name',
                  style: TextStyle(fontWeight: FontWeight.w500),
                );
              },
            ),
            SizedBox(height: 16),
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) =>
                              _buildCancelDialog(context, bookingService),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                      ),
                      child: Text('ยกเลิกคำขอ'),
                    ),
                  ),
                  if (isSitter) ...[
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // โค้ดสำหรับยืนยันการรับงาน
                          // ไม่ได้เขียนใส่ในที่นี้เพราะอยู่นอกขอบเขตของคำขอ
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('รับงาน'),
                      ),
                    ),
                  ],
                ],
              ),
            if (!isPending)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelDialog(
      BuildContext context, BookingService bookingService) {
    String reason = 'ไม่สะดวกรับงาน';

    return AlertDialog(
      title: Text('ยกเลิกคำขอ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('โปรดระบุเหตุผลในการยกเลิก:'),
          SizedBox(height: 12),
          TextField(
            onChanged: (value) {
              reason = value;
            },
            decoration: InputDecoration(
              hintText: 'เหตุผลในการยกเลิก',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await bookingService.cancelBooking(
                bookingId: bookingId,
                cancelledBy: isSitter ? booking['sitterId'] : booking['userId'],
                reason: reason.isNotEmpty ? reason : 'ไม่ระบุเหตุผล',
              );
              onUpdate();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('ยกเลิกคำขอสำเร็จ')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: Text('ยืนยันการยกเลิก'),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'auto_cancelled':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'cancelled':
        return 'ถูกยกเลิก';
      case 'auto_cancelled':
        return 'หมดเวลาอัตโนมัติ';
      case 'completed':
        return 'เสร็จสิ้น';
      default:
        return 'ไม่ระบุสถานะ';
    }
  }
}

class ExpirationCountdown extends StatefulWidget {
  final DateTime expirationTime;
  final VoidCallback onExpired;

  const ExpirationCountdown({
    Key? key,
    required this.expirationTime,
    required this.onExpired,
  }) : super(key: key);

  @override
  State<ExpirationCountdown> createState() => _ExpirationCountdownState();
}

class _ExpirationCountdownState extends State<ExpirationCountdown> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _startTimer();
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    if (widget.expirationTime.isAfter(now)) {
      setState(() {
        _timeLeft = widget.expirationTime.difference(now);
      });
    } else {
      widget.onExpired();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _calculateTimeLeft();
      if (_timeLeft.inSeconds <= 0) {
        timer.cancel();
        widget.onExpired();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft.inSeconds <= 0) {
      return Text(
        'หมดเวลา',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Text(
      'เหลือเวลา: ${_timeLeft.inHours}:${(_timeLeft.inMinutes % 60).toString().padLeft(2, '0')}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}',
      style: TextStyle(
        color: _timeLeft.inMinutes < 30 ? Colors.red : Colors.orange,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
