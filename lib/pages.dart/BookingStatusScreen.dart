import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';


class BookingStatusScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('สถานะการฝากเลี้ยง'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('booking_requests')
            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data!.docs;

          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'ไม่มีรายการฝากเลี้ยง',
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
            padding: EdgeInsets.all(8),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index].data() as Map<String, dynamic>;
              final bookingId = bookings[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(booking['sitterId'])
                    .get(),
                builder: (context, sitterSnapshot) {
                  if (!sitterSnapshot.hasData) {
                    return Card(
                      child: ListTile(
                        title: Text('กำลังโหลดข้อมูล...'),
                      ),
                    );
                  }

                  final sitterData =
                      sitterSnapshot.data!.data() as Map<String, dynamic>;

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Image.network(
                                  sitterData['photo'] ?? '',
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(Icons.person, size: 50),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sitterData['name'] ?? 'ไม่ระบุชื่อ',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _getStatusText(
                                          booking['status'] ?? 'pending'),
                                      style: TextStyle(
                                        color: _getStatusColor(
                                            booking['status'] ?? 'pending'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          if (booking['dates'] != null)
                            Text(
                              'วันที่ฝาก: ${_formatDates(booking['dates'])}',
                              style: TextStyle(fontSize: 16),
                            ),
                          FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .collection('cats')
                                .where('isForSitting', isEqualTo: true)
                                .get(),
                            builder: (context, catsSnapshot) {
                              if (!catsSnapshot.hasData) {
                                return SizedBox();
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 8),
                                  Text(
                                    'แมวที่ฝาก:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  ...catsSnapshot.data!.docs.map((catDoc) {
                                    final catData =
                                        catDoc.data() as Map<String, dynamic>;
                                    return ListTile(
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.network(
                                          catData['imagePath'] ?? '',
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Icon(Icons.pets, size: 40),
                                        ),
                                      ),
                                      title: Text(
                                          catData['name'] ?? 'ไม่ระบุชื่อแมว'),
                                      subtitle: Text(catData['breed'] ??
                                          'ไม่ระบุสายพันธุ์'),
                                    );
                                  }).toList(),
                                ],
                              );
                            },
                          ),
                          if (booking['status'] == 'pending')
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () =>
                                    _cancelBooking(context, bookingId),
                                icon: Icon(Icons.cancel, color: Colors.red),
                                label: Text(
                                  'ยกเลิกการจอง',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'in_progress':
        return 'กำลังดูแล';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDates(List<dynamic> dates) {
    if (dates == null || dates.isEmpty) return 'ไม่ระบุวันที่';

    final formatter = DateFormat('dd/MM/yyyy');
    final List<DateTime> dateTimes =
        dates.map((date) => (date as Timestamp).toDate()).toList();

    dateTimes.sort();

    if (dateTimes.length > 1) {
      return '${formatter.format(dateTimes.first)} - ${formatter.format(dateTimes.last)}';
    }
    return formatter.format(dateTimes.first);
  }

  Future<void> _cancelBooking(BuildContext context, String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('booking_requests')
          .doc(bookingId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final catsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cats')
            .where('isForSitting', isEqualTo: true)
            .get();

        for (var doc in catsSnapshot.docs) {
          await doc.reference.update({
            'isForSitting': false,
            'sittingStatus': null,
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ยกเลิกการจองเรียบร้อย')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการยกเลิก: $e')),
      );
    }
  }
}
