// แก้ไขส่วนนำเข้าด้านบนของไฟล์ (ประมาณบรรทัด 1-10)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/page2.dart/BookingAcceptancePage.dart';
import 'package:myproject/page2.dart/ActiveBookingsPage.dart'; // นำเข้า ActiveBookingsPage จากไฟล์นี้เท่านั้น
import 'package:myproject/page2.dart/scheduleincomepage.dart'; // นำเข้า ScheduleIncomePage อย่างถูกต้อง
import 'package:myproject/page2.dart/sitter_checklist_page.dart';
import 'package:myproject/services/checklist_service.dart';
import 'package:myproject/widget/widget_support.dart';

class SitterBookingManagement extends StatefulWidget {
  const SitterBookingManagement({Key? key}) : super(key: key);

  @override
  State<SitterBookingManagement> createState() =>
      _SitterBookingManagementState();
}

class _SitterBookingManagementState extends State<SitterBookingManagement> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  int _pendingBookings = 0;
  int _acceptedBookings = 0;
  double _totalEarnings = 0;

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
  }

  Future<void> _loadSummaryData() async {
    setState(() => _isLoading = true);

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // ดึงจำนวนการจองที่รอการยืนยัน
      final pendingSnapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      // ดึงจำนวนการจองที่ยอมรับแล้ว
      final acceptedSnapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      // คำนวณรายได้ทั้งหมด
      double total = 0;
      for (var doc in acceptedSnapshot.docs) {
        final data = doc.data();
        total += (data['totalPrice'] ?? 0).toDouble();
      }

      setState(() {
        _pendingBookings = pendingSnapshot.docs.length;
        _acceptedBookings = acceptedSnapshot.docs.length;
        _totalEarnings = total;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading summary data: $e');
      setState(() => _isLoading = false);
    }
  }

// เมื่อการจองถูกยืนยัน
  Future<void> confirmBooking(String bookingId) async {
    try {
      // อัปเดตสถานะการจอง
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ดึงข้อมูลการจอง
      DocumentSnapshot bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (bookingDoc.exists) {
        Map<String, dynamic> bookingData =
            bookingDoc.data() as Map<String, dynamic>;

        // สร้างเช็คลิสต์
        ChecklistService checklistService = ChecklistService();
        await checklistService.createDefaultChecklist(
          bookingId,
          bookingData['userId'],
          bookingData['sitterId'],
          List<String>.from(bookingData['catIds']),
        );
      }

      // แสดงข้อความสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ยืนยันการจองเรียบร้อยและสร้างเช็คลิสต์แล้ว')),
      );
    } catch (e) {
      print('Error confirming booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'จัดการการจอง',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ส่วนสรุป
                    _buildSummarySection(),
                    const SizedBox(height: 24),

                    // เมนูการจัดการ
                    Text(
                      'จัดการงาน',
                      style: AppWidget.HeadlineTextFeildStyle(),
                    ),
                    const SizedBox(height: 16),
                    _buildManagementOptions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สรุปข้อมูลการจอง',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'รอยืนยัน',
                  _pendingBookings.toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'ยอมรับแล้ว',
                  _acceptedBookings.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'รายได้',
                  '${_totalEarnings.toStringAsFixed(0)} ฿',
                  Icons.attach_money,
                  Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementOptions() {
    return Column(
      children: [
        // ตรวจสอบการจอง (รักษาคาร์ดเดิมไว้)
        _buildOptionCard(
          'การจองที่รอยืนยัน',
          'ตรวจสอบและยอมรับการจองจากลูกค้า',
          Icons.assignment,
          Colors.orange,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BookingAcceptancePage(),
            ),
          ).then((_) => _loadSummaryData()),
          badge: _pendingBookings > 0 ? _pendingBookings.toString() : null,
        ),
        const SizedBox(height: 16),

        // เพิ่มการ์ดใหม่สำหรับงานที่กำลังดำเนินการ
        _buildOptionCard(
          'งานที่กำลังดำเนินการ',
          'จัดการงานที่กำลังดำเนินการและทำเครื่องหมายเสร็จสิ้น',
          Icons.work,
          Colors.green,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ActiveBookingsPage(),
            ),
          ).then((_) => _loadSummaryData()),
          badge: _acceptedBookings > 0 ? _acceptedBookings.toString() : null,
        ),
        const SizedBox(height: 16),

        // ตารางงานและรายได้ (รักษาคาร์ดเดิมไว้)
        _buildOptionCard(
          'ตารางงานและรายได้',
          'ดูตารางงานและรายได้ของคุณ',
          Icons.calendar_month,
          Colors.blue,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ScheduleIncomePage(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    String? badge,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
