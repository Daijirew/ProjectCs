// SitterBookingRequestsScreen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SitterBookingRequestsScreen extends StatefulWidget {
  @override
  State<SitterBookingRequestsScreen> createState() =>
      _SitterBookingRequestsScreenState();
}

class _SitterBookingRequestsScreenState
    extends State<SitterBookingRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('คำขอฝากเลี้ยง'),
        backgroundColor: Colors.teal,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'รอยืนยัน'),
            Tab(text: 'กำลังดูแล'),
            Tab(text: 'เสร็จสิ้น'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingList('pending'),
          _buildBookingList('in_progress'),
          _buildBookingList('completed'),
        ],
      ),
    );
  }

  Widget _buildBookingList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('booking_requests')
          .where('sitterId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('ไม่มีรายการ'),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          padding: EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final booking = snapshot.data!.docs[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(booking['userId'])
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return SizedBox();
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;

                return Card(
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(userData['photo']),
                    ),
                    title: Text(userData['name']),
                    subtitle: Text('วันที่: ${_formatDates(booking['dates'])}'),
                    children: [
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(booking['userId'])
                            .collection('cats')
                            .where('isForSitting', isEqualTo: true)
                            .get(),
                        builder: (context, catsSnapshot) {
                          if (!catsSnapshot.hasData) {
                            return SizedBox();
                          }

                          return Column(
                            children: [
                              ...catsSnapshot.data!.docs.map((cat) {
                                final catData =
                                    cat.data() as Map<String, dynamic>;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage:
                                        NetworkImage(catData['imagePath']),
                                  ),
                                  title: Text(catData['name']),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('พันธุ์: ${catData['breed']}'),
                                      Text(
                                          'วัคซีน: ${catData['vaccinations']}'),
                                    ],
                                  ),
                                );
                              }).toList(),
                              if (status == 'pending')
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () =>
                                            _rejectBooking(booking.id),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: Text('ปฏิเสธ'),
                                      ),
                                      SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () =>
                                            _acceptBooking(booking.id),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        child: Text('รับดูแล'),
                                      ),
                                    ],
                                  ),
                                ),
                              if (status == 'in_progress')
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _completeBooking(booking.id),
                                    child: Text('เสร็จสิ้นการดูแล'),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _acceptBooking(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('booking_requests')
          .doc(bookingId)
          .update({
        'status': 'in_progress',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error accepting booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการยอมรับคำขอ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ในฟังก์ชัน _completeBooking
  Future<void> _completeBooking(String bookingId) async {
    try {
      // แสดงกล่องยืนยันก่อนทำเครื่องหมายเสร็จสิ้น
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ยืนยันการเสร็จสิ้นงาน'),
          content:
              const Text('คุณต้องการยืนยันว่างานนี้เสร็จสิ้นแล้วใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await FirebaseFirestore.instance
            .collection('booking_requests')
            .doc(bookingId)
            .update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('การดูแลเสร็จสิ้นเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error completing booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการอัพเดทสถานะ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectBooking(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('booking_requests')
          .doc(bookingId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ปฏิเสธคำขอเรียบร้อยแล้ว'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Error rejecting booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการปฏิเสธคำขอ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDates(List<dynamic> dates) {
    if (dates.isEmpty) return 'ไม่มีวันที่ระบุ';

    // Convert timestamps to DateTime objects and sort them
    List<DateTime> sortedDates =
        dates.map((date) => (date as Timestamp).toDate()).toList()..sort();

    // Format the date range
    if (sortedDates.length == 1) {
      return DateFormat('d MMM yyyy').format(sortedDates[0]);
    } else {
      return '${DateFormat('d MMM yyyy').format(sortedDates.first)} - ${DateFormat('d MMM yyyy').format(sortedDates.last)}';
    }
  }
}
