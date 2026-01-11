import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:myproject/pages.dart/reviwe.dart';

import 'package:myproject/pages.dart/user_checklist_page.dart'; // เพิ่ม import นี้

class BookingStatusScreen extends StatefulWidget {
  @override
  _BookingStatusScreenState createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen> {
  bool _isLoading = true;
  List<DocumentSnapshot> _bookingsList = [];

  @override
  void initState() {
    super.initState();
  }

  // เพิ่มฟังก์ชันสำหรับกรองและเรียงลำดับข้อมูล
  void _processBookings(List<DocumentSnapshot> bookings) {
    // เรียงลำดับตามเวลา
    bookings.sort((a, b) {
      Timestamp? timeA = (a.data() as Map<String, dynamic>)?['createdAt'];
      Timestamp? timeB = (b.data() as Map<String, dynamic>)?['createdAt'];
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      return timeB.compareTo(timeA);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('สถานะการฝากเลี้ยง'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings') // เปลี่ยนจาก booking_requests เป็น bookings
            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // ถ้าไม่พบข้อมูลใน collection 'bookings' ให้ตรวจสอบ 'booking_requests'
            return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('booking_requests')
                    .where('userId',
                        isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, requestsSnapshot) {
                  if (requestsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!requestsSnapshot.hasData ||
                      requestsSnapshot.data!.docs.isEmpty) {
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

                  _bookingsList = requestsSnapshot.data!.docs;
                  _processBookings(_bookingsList);

                  return _buildBookingsList();
                });
          }

          _bookingsList = snapshot.data!.docs;
          _processBookings(_bookingsList);

          return _buildBookingsList();
        },
      ),
    );
  }

  Widget _buildBookingsList() {
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: _bookingsList.length,
      itemBuilder: (context, index) {
        final bookingData = _bookingsList[index].data() as Map<String, dynamic>;
        final bookingId = _bookingsList[index].id;
        final sitterId = bookingData['sitterId'];

        // เพิ่มการตรวจสอบและล็อกสถานะ
        print('Processing booking: $bookingId with sitterId: $sitterId');

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(sitterId)
              .get(),
          builder: (context, sitterSnapshot) {
            // เพิ่มการล็อกสถานะ snapshot
            print(
                'Sitter snapshot: exists=${sitterSnapshot.hasData ? sitterSnapshot.data!.exists : false}');

            if (sitterId == null || sitterId.toString().isEmpty) {
              return Card(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: ListTile(
                  title: Text('กำลังโหลดข้อมูล...'),
                ),
              );
            }

            final sitterData = sitterSnapshot.data!.exists
                ? sitterSnapshot.data!.data() as Map<String, dynamic>
                : {'name': 'ไม่พบข้อมูลผู้รับเลี้ยง', 'photo': ''};

            // เพิ่มการล็อกข้อมูลผู้รับเลี้ยง
            print('Sitter data: $sitterData');

            return Card(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 50),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ข้อมูลไม่สมบูรณ์',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'ไม่พบข้อมูลผู้รับเลี้ยง',
                                style: TextStyle(
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // ส่วนแสดงข้อมูลการจองอื่นๆ
                    SizedBox(height: 16),
                    if (bookingData['dates'] != null)
                      Text(
                        'วันที่ฝาก: ${_formatDates(bookingData['dates'])}',
                        style: TextStyle(fontSize: 16),
                      ),
                    if (bookingData['totalPrice'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'ราคา: ฿${bookingData['totalPrice']}',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    SizedBox(height: 16),
                    if (bookingData['catIds'] != null)
                      FutureBuilder<QuerySnapshot>(
                        future: _fetchSelectedCats(bookingData['catIds']),
                        builder: (context, catsSnapshot) {
                          if (!catsSnapshot.hasData) {
                            return Text('กำลังโหลดข้อมูลแมว...');
                          }

                          if (catsSnapshot.data!.docs.isEmpty) {
                            return Text('ไม่พบข้อมูลแมวที่ฝาก');
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'แมวที่ฝาก:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              ...catsSnapshot.data!.docs.map((catDoc) {
                                final catData =
                                    catDoc.data() as Map<String, dynamic>;
                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: catData['imagePath'] != null &&
                                            catData['imagePath']
                                                .toString()
                                                .isNotEmpty
                                        ? Image.network(
                                            catData['imagePath'],
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Icon(Icons.pets, size: 40),
                                          )
                                        : Icon(Icons.pets, size: 40),
                                  ),
                                  title:
                                      Text(catData['name'] ?? 'ไม่ระบุชื่อแมว'),
                                  subtitle: Text(
                                      catData['breed'] ?? 'ไม่ระบุสายพันธุ์'),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                );
                              }).toList(),
                            ],
                          );
                        },
                      ),
                    // เพิ่มปุ่มดูรายงานเช็คลิสต์
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (bookingData['status'] == 'in_progress' ||
                            bookingData['status'] == 'completed')
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserChecklistPage(
                                    bookingId:
                                        bookingId, // แก้จาก doc.id เป็น bookingId
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.assignment, color: Colors.green),
                            label: Text(
                              'ดูรายงานการดูแล',
                              style: TextStyle(color: Colors.green),
                            ),
                          ),
                        if (bookingData['status'] == 'pending')
                          TextButton.icon(
                            onPressed: () => _cancelBooking(context, bookingId),
                            icon: Icon(Icons.cancel, color: Colors.red),
                            label: Text(
                              'ยกเลิกการจอง',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // เพิ่มฟังก์ชันสำหรับดึงข้อมูลแมวตาม ID
  Future<QuerySnapshot> _fetchSelectedCats(List<dynamic> catIds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc('dummy')
          .collection('cats')
          .limit(0)
          .get();
    }

    // ถ้ามี catIds ให้ใช้ คือเราควรจะมีรายการ ID ของแมวที่ถูกเลือก
    if (catIds.isNotEmpty) {
      // ใช้ where in สำหรับดึงเฉพาะแมวที่ตรงกับ ID ที่เรามี
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cats')
          .where(FieldPath.documentId, whereIn: catIds.cast<String>())
          .get();
    } else {
      // Fallback ดึงแมวที่มีสถานะ isForSitting เป็น true
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cats')
          .where('isForSitting', isEqualTo: true)
          .get();
    }
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
      case 'expired': // เพิ่มสถานะใหม่
        return 'หมดเวลา';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      case 'expired': // เพิ่มสถานะใหม่
        return Colors.grey; // หรือสีที่คุณต้องการ
      default:
        return Colors.grey;
    }
  }

  String _formatDates(List<dynamic> dates) {
    if (dates.isEmpty) return 'ไม่ระบุวันที่';

    final formatter = DateFormat('dd/MM/yyyy');
    final List<DateTime> dateTimes = dates
        .map((date) => date is Timestamp ? date.toDate() : DateTime.now())
        .toList();

    dateTimes.sort();

    if (dateTimes.length > 1) {
      return '${formatter.format(dateTimes.first)} - ${formatter.format(dateTimes.last)}';
    }
    return formatter.format(dateTimes.first);
  }

  Future<void> _cancelBooking(BuildContext context, String bookingId) async {
    try {
      // ตรวจสอบว่า document อยู่ใน collection ไหน
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (bookingDoc.exists) {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance
            .collection('booking_requests')
            .doc(bookingId)
            .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }

      // อัพเดตสถานะแมว
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
