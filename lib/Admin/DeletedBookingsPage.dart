import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DeletedBookingsPage extends StatefulWidget {
  @override
  _DeletedBookingsPageState createState() => _DeletedBookingsPageState();
}

class _DeletedBookingsPageState extends State<DeletedBookingsPage> {
  bool _isLoading = true;
  List<DocumentSnapshot> _deletedBookings = [];

  @override
  void initState() {
    super.initState();
    _loadDeletedBookings();
  }

  Future<void> _loadDeletedBookings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('deleted_bookings')
          .orderBy('deletedAt', descending: true)
          .get();

      setState(() {
        _deletedBookings = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading deleted bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ประวัติการลบคำขอหมดเวลา'),
        backgroundColor: Colors.deepOrange,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _deletedBookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'ไม่พบประวัติการลบคำขอหมดเวลา',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _deletedBookings.length,
                  itemBuilder: (context, index) {
                    final booking = _deletedBookings[index];
                    final data = booking.data() as Map<String, dynamic>;
                    final bookingId = booking.id;
                    final userId = data['userId'] ?? 'ไม่พบข้อมูล';
                    final sitterId = data['sitterId'] ?? 'ไม่พบข้อมูล';
                    final totalPrice = data['totalPrice'] ?? 0;
                    final deletedAt = data['deletedAt'] as Timestamp?;
                    final deletedDate = deletedAt != null
                        ? DateFormat('dd/MM/yyyy HH:mm')
                            .format(deletedAt.toDate())
                        : 'ไม่ทราบเวลา';
                    final reason = data['reason'] ?? 'ไม่ระบุเหตุผล';

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'รหัสการจอง: $bookingId',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Divider(),
                            Text('เวลาที่ลบ: $deletedDate'),
                            Text('เหตุผล: $reason'),
                            Text('รหัสผู้ใช้: $userId'),
                            Text('รหัสผู้รับเลี้ยง: $sitterId'),
                            Text(
                                'ราคารวม: ${NumberFormat('#,##0').format(totalPrice)} บาท'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadDeletedBookings,
        child: Icon(Icons.refresh),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }
}
