import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/Admin/ChecklistManagementPage.dart';
import 'package:myproject/Admin/NotificationService.dart';
import 'package:myproject/Admin/ServiceFeeManagementPage.dart';
import 'package:myproject/Admin/SitterApprovalPage.dart';
import 'package:myproject/pages.dart/login.dart';
import 'package:intl/intl.dart';
import 'package:myproject/Admin/BookingCleanupService.dart';
import 'package:myproject/Admin/BatchBookingManagementPage.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({Key? key}) : super(key: key);

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  // State variables
  int _pendingSittersCount = 0;
  int _approvedSittersCount = 0;
  int _totalUsersCount = 0;
  int _totalBookingsCount = 0;
  bool _isLoading = true; // Keep only one declaration
  String _adminName = "ผู้ดูแลระบบ";
  String _adminEmail = "";
  Map<String, dynamic> _summaryData = {};

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _loadDashboardData();
  }

  Future<void> _runBookingCleanup() async {
    try {
      setState(() {
        _isLoading = true;
      });

      BookingCleanupService cleanupService = BookingCleanupService();
      await cleanupService.runCleanupTasks();

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ทำความสะอาดคิวการจองเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );

      // โหลดข้อมูลใหม่
      _loadDashboardData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error running booking cleanup: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // โหลดข้อมูลผู้ดูแลระบบ
  Future<void> _loadAdminInfo() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          setState(() {
            _adminName = userData['name'] ?? "ผู้ดูแลระบบ";
            _adminEmail = userData['email'] ?? "";
          });
        }
      }
    } catch (e) {
      print('Error loading admin info: $e');
    }
  }

  // โหลดข้อมูลสำหรับแสดงผลบน Dashboard
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // จำนวนผู้รับเลี้ยงแมวที่รอการอนุมัติ
      final pendingSittersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .where('status', isEqualTo: 'pending')
          .get();

      // จำนวนผู้รับเลี้ยงแมวทั้งหมดที่อนุมัติแล้ว
      final approvedSittersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .where('status', isEqualTo: 'approved')
          .get();

      // จำนวนผู้ใช้ทั้งหมด
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      // จำนวนการจองทั้งหมด
      final bookingsSnapshot =
          await FirebaseFirestore.instance.collection('bookings').get();

      setState(() {
        _pendingSittersCount = pendingSittersSnapshot.docs.length;
        _approvedSittersCount = approvedSittersSnapshot.docs.length;
        _totalUsersCount = usersSnapshot.docs.length;
        _totalBookingsCount = bookingsSnapshot.docs.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ฟังก์ชันออกจากระบบ
  Future<void> _signOut() async {
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.orange),
              SizedBox(width: 10),
              Text('ออกจากระบบ'),
            ],
          ),
          content: Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LogIn()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: Text('ออกจากระบบ'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error signing out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการออกจากระบบ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ผู้ดูแลระบบ'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.orange))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.orange.shade50, Colors.white],
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // เพิ่มปุ่มนี้ในส่วนของเมนูการจัดการระบบ
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: _runBookingCleanup,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.cleaning_services,
                                  color: Colors.teal.shade700,
                                  size: 30,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ทำความสะอาดคิว',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'ลบคิวที่ไม่ได้รับการยืนยันเกิน 30 นาที',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // ส่วนข้อมูลผู้ดูแลระบบ
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.orange.shade200,
                              child: Icon(
                                Icons.admin_panel_settings,
                                size: 40,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ยินดีต้อนรับ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    _adminName,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                  if (_adminEmail.isNotEmpty)
                                    Text(
                                      _adminEmail,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

// เพิ่มเมนูจัดการการจองแบบกลุ่ม
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    BatchBookingManagementPage()),
                          ).then((_) => _loadDashboardData());
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.delete_sweep,
                                  color: Colors.red.shade700,
                                  size: 30,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ลบการจองแบบกลุ่ม',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'จัดการและลบการจองหลายรายการพร้อมกัน',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // สรุปข้อมูลทั่วไป
                    Text(
                      'ภาพรวมระบบ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 10),

                    // แสดงข้อมูลสรุป
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        _buildStatCard(
                          'ผู้รับเลี้ยงแมวรออนุมัติ',
                          _pendingSittersCount.toString(),
                          Icons.pending_actions,
                          Colors.orange,
                          _pendingSittersCount > 0,
                        ),
                        _buildStatCard(
                          'ผู้รับเลี้ยงแมวทั้งหมด',
                          _approvedSittersCount.toString(),
                          Icons.check_circle,
                          Colors.green,
                          false,
                        ),
                        _buildStatCard(
                          'ผู้ใช้ทั้งหมด',
                          _totalUsersCount.toString(),
                          Icons.people,
                          Colors.blue,
                          false,
                        ),
                        _buildStatCard(
                          'การจองทั้งหมด',
                          _totalBookingsCount.toString(),
                          Icons.calendar_month,
                          Colors.purple,
                          false,
                        ),
                      ],
                    ),

                    SizedBox(height: 30),

                    // เมนูการจัดการระบบ
                    Text(
                      'การจัดการระบบ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 10),

                    // เมนูการอนุมัติผู้รับเลี้ยงแมว
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SitterApprovalPage(),
                            ),
                          ).then((_) => _loadDashboardData());
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.person_add,
                                  color: Colors.orange.shade700,
                                  size: 30,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'อนุมัติผู้รับเลี้ยงแมว',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'จัดการคำขอสมัครเป็นผู้รับเลี้ยงแมว',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _pendingSittersCount > 0
                                      ? Colors.red
                                      : Colors.grey,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$_pendingSittersCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
// เพิ่มปุ่มตรวจสอบเช็คลิสต์
                    _buildOptionCard(
                      'ตรวจสอบเช็คลิสต์',
                      'ดูรายละเอียดการดูแลแมวจากเช็คลิสต์',
                      Icons.checklist,
                      Colors.teal,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChecklistManagementPage(),
                        ),
                      ).then((_) => _loadSummaryData()),
                    ),
                    const SizedBox(height: 16),
                    // จัดการผู้ใช้ทั้งหมด
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          // สร้างหน้าจัดการผู้ใช้แบบง่ายๆ
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => _buildUserManagementPage(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.people,
                                  color: Colors.blue.shade700,
                                  size: 30,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'จัดการผู้ใช้',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'ดูและจัดการข้อมูลผู้ใช้ทั้งหมด',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$_totalUsersCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),

                    // จัดการการจอง
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          // สร้างหน้าจัดการการจองแบบง่ายๆ
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  _buildBookingManagementPage(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.calendar_month,
                                  color: Colors.purple.shade700,
                                  size: 30,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'จัดการการจอง',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'ดูและจัดการข้อมูลการจองทั้งหมด',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$_totalBookingsCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 40),

                    // ข้อความเกี่ยวกับระบบ
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info,
                                color: Colors.blue,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'ข้อมูลระบบ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'ระบบรับเลี้ยงแมวนี้ช่วยให้ผู้ดูแลระบบสามารถจัดการผู้รับเลี้ยงแมวได้อย่างมีประสิทธิภาพ เพื่อให้ระบบมีความน่าเชื่อถือและปลอดภัยสำหรับผู้ใช้งาน',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // เพิ่มฟังก์ชันใหม่ในคลาส _AdminPanelState
  Widget _buildUserManagementPage() {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการผู้ใช้งาน'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text('ไม่พบข้อมูลผู้ใช้งาน'));
            }

            return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                padding: EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final userData = doc.data() as Map<String, dynamic>;

                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: userData['photo'] != null &&
                                userData['photo'] != 'images/User.png'
                            ? NetworkImage(userData['photo'])
                            : null,
                        child: userData['photo'] == 'images/User.png'
                            ? Icon(Icons.person)
                            : null,
                      ),
                      title: Text(userData['name'] ?? 'ไม่ระบุชื่อ'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userData['email'] ?? 'ไม่ระบุอีเมล'),
                          Text('บทบาท: ${userData['role'] ?? 'user'}'),
                        ],
                      ),
                      trailing: userData['role'] == 'admin'
                          ? Chip(
                              label: Text('แอดมิน'),
                              backgroundColor: Colors.orange.shade100)
                          : userData['role'] == 'sitter'
                              ? Chip(
                                  label: Text('พี่เลี้ยง'),
                                  backgroundColor: Colors.blue.shade100)
                              : Chip(
                                  label: Text('ผู้ใช้'),
                                  backgroundColor: Colors.green.shade100),
                    ),
                  );
                });
          }),
    );
  }

  // เพิ่มฟังก์ชันใหม่ในคลาส _AdminPanelState
  Widget _buildBookingManagementPage() {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการการจอง'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text('ไม่พบข้อมูลการจอง'));
            }

            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              padding: EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final bookingData = doc.data() as Map<String, dynamic>;
                final status = bookingData['status'] ?? 'pending';

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'รหัสการจอง: ${doc.id.substring(0, 8)}...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status)
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _getStatusText(status),
                                          style: TextStyle(
                                            color: _getStatusColor(status),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      if (bookingData['totalPrice'] != null)
                                        Text(
                                          '฿${bookingData['totalPrice']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (status == 'pending')
                              TextButton(
                                onPressed: () {
                                  _updateBookingStatus(doc.id, 'confirmed');
                                },
                                child: Text(
                                  'ยืนยัน',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                          ],
                        ),
                        Divider(),

                        // ข้อมูลผู้จองและพี่เลี้ยง
                        if (bookingData['userId'] != null)
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(bookingData['userId'])
                                .get(),
                            builder: (context, userSnapshot) {
                              String userName = 'กำลังโหลด...';
                              if (userSnapshot.hasData &&
                                  userSnapshot.data!.exists) {
                                final userData = userSnapshot.data!.data()
                                    as Map<String, dynamic>;
                                userName = userData['name'] ?? 'ไม่ระบุชื่อ';
                              }

                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.person,
                                          size: 16, color: Colors.blue),
                                      SizedBox(width: 4),
                                      Text(
                                        'ผู้จอง: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(userName),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                ],
                              );
                            },
                          ),

                        if (bookingData['sitterId'] != null)
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(bookingData['sitterId'])
                                .get(),
                            builder: (context, sitterSnapshot) {
                              String sitterName = 'กำลังโหลด...';
                              if (sitterSnapshot.hasData) {
                                if (sitterSnapshot.data!.exists) {
                                  final sitterData = sitterSnapshot.data!.data()
                                      as Map<String, dynamic>;
                                  sitterName =
                                      sitterData['name'] ?? 'ไม่ระบุชื่อ';
                                } else {
                                  sitterName = 'ไม่พบข้อมูลผู้รับเลี้ยง';
                                }
                              }

                              return Row(
                                children: [
                                  Icon(Icons.pets,
                                      size: 16, color: Colors.orange),
                                  SizedBox(width: 4),
                                  Text(
                                    'ผู้รับเลี้ยง: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(sitterName),
                                ],
                              );
                            },
                          ),

                        if (bookingData['dates'] != null &&
                            bookingData['dates'] is List)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.date_range,
                                    size: 16, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'วันที่: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(_formatDates(bookingData['dates'])),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
    );
  }

// เพิ่มฟังก์ชันเสริมสำหรับแปลงสถานะและสี
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

  // Widget สำหรับสร้างการ์ดแสดงข้อมูลสถิติ
  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, bool highlight) {
    return Card(
      elevation: highlight ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlight ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ServiceFeeManagementPage()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.attach_money,
                          color: Colors.teal.shade700,
                          size: 30,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'จัดการค่าบริการ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'กำหนดค่าบริการและค่าธรรมเนียมต่างๆ ในระบบ',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: highlight ? color : Colors.grey[800],
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    try {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // Get booking reference
      final bookingRef =
          FirebaseFirestore.instance.collection('bookings').doc(bookingId);

      // Get current booking data
      final bookingDoc = await bookingRef.get();
      if (!bookingDoc.exists) {
        throw 'Booking not found';
      }

      final bookingData = bookingDoc.data() as Map<String, dynamic>;

      // Update booking status
      await bookingRef.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to user
      final notificationService = NotificationService();
      await notificationService.sendBookingStatusNotification(
        userId: bookingData['userId'],
        bookingId: bookingId,
        status: newStatus,
        message: 'การจองของคุณได้รับการ${_getStatusText(newStatus)}แล้ว',
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัพเดทสถานะเรียบร้อย')),
      );
    } catch (e) {
      print('Error updating booking status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDates(List<dynamic> dates) {
    try {
      // Convert timestamps to DateTime objects and sort them
      List<DateTime> sortedDates =
          dates.map((date) => (date as Timestamp).toDate()).toList()..sort();

      if (sortedDates.isEmpty) {
        return 'ไม่ระบุวันที่';
      }

      // Format each date using intl package's DateFormat
      final DateFormat formatter = DateFormat('dd/MM/yyyy');
      if (sortedDates.length == 1) {
        return formatter.format(sortedDates[0]);
      }

      // If multiple dates, show range
      return '${formatter.format(sortedDates.first)} - ${formatter.format(sortedDates.last)}';
    } catch (e) {
      print('Error formatting dates: $e');
      return 'รูปแบบวันที่ไม่ถูกต้อง';
    }
  }

  Widget _buildOptionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
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
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadSummaryData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get Firestore instance
      final firestore = FirebaseFirestore.instance;

      // Get total bookings count
      final bookingsCount = await firestore
          .collection('bookings')
          .count()
          .get()
          .then((value) => value.count);

      // Get completed checklists count
      final completedChecklistsCount = await firestore
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .count()
          .get()
          .then((value) => value.count);

      // Get pending reviews count
      final pendingReviewsCount = await firestore
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .where('hasReview', isEqualTo: false)
          .count()
          .get()
          .then((value) => value.count);

      setState(() {
        _summaryData = {
          'totalBookings': bookingsCount,
          'completedChecklists': completedChecklistsCount,
          'pendingReviews': pendingReviewsCount,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading summary data: $e');
      setState(() {
        _isLoading = false;
      });

      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class BookingCleanupService {
  Future<void> runCleanupTasks() async {
    try {
      // Clean up expired bookings
      await _cleanExpiredBookings();

      // Clean up abandoned bookings (e.g., unpaid after X hours)
      await _cleanAbandonedBookings();

      // Update booking statuses
      await _updateBookingStatuses();
    } catch (e) {
      print('Error during cleanup: $e');
      throw e;
    }
  }

  Future<void> _cleanExpiredBookings() async {
    // TODO: Implement expired bookings cleanup logic
  }

  Future<void> _cleanAbandonedBookings() async {
    // TODO: Implement abandoned bookings cleanup logic
  }

  Future<void> _updateBookingStatuses() async {
    // TODO: Implement status update logic
  }
}
