import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:myproject/Admin/NotificationService.dart';

class BatchBookingManagementPage extends StatefulWidget {
  const BatchBookingManagementPage({Key? key}) : super(key: key);

  @override
  _BatchBookingManagementPageState createState() =>
      _BatchBookingManagementPageState();
}

class _BatchBookingManagementPageState
    extends State<BatchBookingManagementPage> {
  bool _isLoading = false;
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedStatus = 'all';
  List<String> _selectedBookings = [];
  List<DocumentSnapshot> _bookings = [];
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // สร้างคิวรี่พื้นฐาน
      Query query = FirebaseFirestore.instance.collection('bookings');

      // กรองตามสถานะถ้าไม่ใช่ 'all'
      if (_selectedStatus != 'all') {
        query = query.where('status', isEqualTo: _selectedStatus);
      }

      // กรองตามช่วงเวลา
      Timestamp startTimestamp = Timestamp.fromDate(_startDate);
      Timestamp endTimestamp =
          Timestamp.fromDate(_endDate.add(Duration(days: 1)));
      query = query
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThan: endTimestamp);

      // เรียงลำดับ
      query = query.orderBy('createdAt', descending: true);

      // ดึงข้อมูล
      QuerySnapshot snapshot = await query.get();

      setState(() {
        _bookings = snapshot.docs;
        // รีเซ็ตรายการที่เลือก
        _selectedBookings = [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepOrange,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadBookings();
    }
  }

  Future<void> _deleteSelectedBookings() async {
    if (_selectedBookings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณาเลือกอย่างน้อย 1 รายการ')),
      );
      return;
    }

    // แสดงหน้าต่างยืนยันการลบ
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการลบ'),
        content: Text(
            'คุณต้องการลบการจองที่เลือกจำนวน ${_selectedBookings.length} รายการหรือไม่? การดำเนินการนี้ไม่สามารถยกเลิกได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('ลบรายการที่เลือก'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ใช้ batch เพื่อประสิทธิภาพในการลบหลายรายการ
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // เก็บข้อมูลสำหรับส่งการแจ้งเตือน
      List<Map<String, dynamic>> notificationsToSend = [];

      // สร้าง batch operations
      for (String bookingId in _selectedBookings) {
        // ค้นหา document ของการจอง
        DocumentSnapshot bookingDoc = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .get();

        if (bookingDoc.exists) {
          Map<String, dynamic> bookingData =
              bookingDoc.data() as Map<String, dynamic>;

          // เก็บข้อมูลสำหรับส่งการแจ้งเตือน
          if (bookingData.containsKey('userId')) {
            notificationsToSend.add({
              'userId': bookingData['userId'],
              'bookingId': bookingId,
            });
          }

          // เพิ่มคำสั่งลบลงใน batch
          batch.delete(
              FirebaseFirestore.instance.collection('bookings').doc(bookingId));
        }
      }

      // ดำเนินการ batch
      await batch.commit();

      // ส่งการแจ้งเตือนหลังจากลบ
      for (var notificationData in notificationsToSend) {
        await _notificationService.sendBookingStatusNotification(
          userId: notificationData['userId'],
          bookingId: notificationData['bookingId'],
          status: 'deleted',
          message: 'การจองของคุณถูกลบโดยผู้ดูแลระบบ',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'ลบรายการที่เลือกเรียบร้อยแล้ว (${_selectedBookings.length} รายการ)'),
          backgroundColor: Colors.green,
        ),
      );

      // โหลดข้อมูลใหม่
      _loadBookings();
    } catch (e) {
      print('Error deleting bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการลบ: $e'),
          backgroundColor: Colors.red,
        ),
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
        title: Text('จัดการการจองแบบกลุ่ม'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
            tooltip: 'เลือกช่วงเวลา',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadBookings,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      floatingActionButton: _selectedBookings.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _deleteSelectedBookings,
              icon: Icon(Icons.delete),
              label: Text('ลบที่เลือก (${_selectedBookings.length})'),
              backgroundColor: Colors.red,
            )
          : null,
      body: Column(
        children: [
          // แสดงช่วงเวลาที่เลือก
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepOrange.shade50,
            child: Row(
              children: [
                const Icon(Icons.date_range, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Text(
                  'ช่วงเวลา: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('เปลี่ยน'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // ตัวเลือกสถานะ
          Container(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildStatusTab('all', 'ทั้งหมด', Icons.all_inclusive),
                _buildStatusTab('pending', 'รอยืนยัน', Icons.hourglass_empty),
                _buildStatusTab('confirmed', 'ยืนยันแล้ว', Icons.check_circle),
                _buildStatusTab('in_progress', 'กำลังดูแล', Icons.pets),
                _buildStatusTab('completed', 'เสร็จสิ้น', Icons.done_all),
                _buildStatusTab('cancelled', 'ยกเลิก', Icons.cancel),
              ],
            ),
          ),

          // ส่วนหัวของตาราง
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Checkbox(
                    value: _selectedBookings.length == _bookings.length &&
                        _bookings.isNotEmpty,
                    onChanged: (value) {
                      if (value == true) {
                        // เลือกทั้งหมด
                        setState(() {
                          _selectedBookings =
                              _bookings.map((doc) => doc.id).toList();
                        });
                      } else {
                        // ยกเลิกการเลือกทั้งหมด
                        setState(() {
                          _selectedBookings = [];
                        });
                      }
                    },
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    'รหัสการจอง',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'วันที่จอง',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'สถานะ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'ราคา',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // รายการการจอง
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _bookings.isEmpty
                    ? Center(
                        child: Text('ไม่พบข้อมูลการจอง'),
                      )
                    : ListView.builder(
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          final bookingData =
                              booking.data() as Map<String, dynamic>;
                          final status = bookingData['status'] ?? 'pending';

                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300),
                              ),
                              color: _selectedBookings.contains(booking.id)
                                  ? Colors.amber.shade50
                                  : Colors.white,
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: Checkbox(
                                      value: _selectedBookings
                                          .contains(booking.id),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedBookings.add(booking.id);
                                          } else {
                                            _selectedBookings
                                                .remove(booking.id);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                        booking.id.substring(0, 8) + '...'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      bookingData['createdAt'] != null
                                          ? DateFormat('dd/MM/yyyy').format(
                                              (bookingData['createdAt']
                                                      as Timestamp)
                                                  .toDate())
                                          : 'ไม่ระบุ',
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status)
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getStatusText(status),
                                        style: TextStyle(
                                          color: _getStatusColor(status),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '฿${bookingData['totalPrice'] ?? 0}',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String status, String label, IconData icon) {
    bool isSelected = _selectedStatus == status;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStatus = status;
          });
          _loadBookings();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepOrange : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'in_progress':
        return 'กำลังดูแล';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ไม่ทราบ';
    }
  }
}
