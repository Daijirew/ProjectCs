import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:myproject/Admin/AdminNotificationsPage%20.dart';
import 'package:myproject/Admin/AdminSettingsPage.dart';
import 'package:myproject/Admin/ChecklistManagementPage.dart';
import 'package:myproject/Admin/DeletedBookingsPage.dart';
import 'package:myproject/Admin/ScheduledTasksManager.dart';
import 'package:myproject/Admin/ServiceFeeManagementPage.dart';
import 'package:myproject/Admin/SitterVerificationPage.dart';
import 'package:myproject/Admin/BookingManagementPage.dart';
import 'package:myproject/Admin/BookingDetailPage.dart';
import 'package:myproject/Admin/UserManagementPage.dart';
import 'package:myproject/Admin/SitterIncomeReport.dart';
import 'package:myproject/Admin/BatchBookingManagementPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myproject/pages.dart/login.dart';
import 'package:http/http.dart' as http;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalSitters = 0;
  int _pendingSitters = 0;
  int _totalBookings = 0;
  int _pendingBookings = 0;
  int _completedBookings = 0;
  double _totalRevenue = 0;
  List<DocumentSnapshot> _recentBookings = [];
  int _pendingNotifications = 0;
  // ข้อมูลเพิ่มเติมสำหรับแสดงในหน้า Dashboard
  double _thisWeekRevenue = 0;
  double _lastWeekRevenue = 0;
  int _thisWeekBookings = 0;
  int _lastWeekBookings = 0;
  String _adminName = "แอดมิน";
  String _adminEmail = "";
  String _adminPhoto = "";
  int _expiredBookingsCount = 0;
  String _lastTriggeredTime = "ไม่มีข้อมูล";
  int _processedBookingsCount = 0;

// แก้ไขฟังก์ชัน initState ในคลาส _AdminDashboardState
  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _ensureFirestoreTriggersExist(); // เพิ่มบรรทัดนี้
    _loadDashboardData();

    // เริ่มต้น scheduled tasks
    ScheduledTasksManager().startScheduledTasks();
  }

// เพิ่มการหยุด scheduled tasks เมื่อออกจากหน้าจอ
  @override
  void dispose() {
    ScheduledTasksManager().stopScheduledTasks();
    super.dispose();
  }

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
            _adminName = userData['name'] ?? "แอดมิน";
            _adminEmail = userData['email'] ?? "";
            _adminPhoto = userData['photo'] ?? "";
          });
        }
      }
    } catch (e) {
      print('Error loading admin info: $e');
    }
  }

  Future<void> _checkExpiredBookingsInApp() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // แสดงข้อความกำลังตรวจสอบ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กำลังตรวจสอบคำขอหมดเวลา กรุณารอสักครู่...')),
      );

      // ดึงคำขอที่มีสถานะ pending และหมดเวลาแล้ว
      final now = DateTime.now();
      final expiredBookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .where('expirationTime', isLessThan: Timestamp.fromDate(now))
          .get();

      print('พบคำขอที่หมดเวลา: ${expiredBookingsSnapshot.docs.length} รายการ');

      // อัพเดตสถานะคำขอที่หมดเวลา
      final batch = FirebaseFirestore.instance.batch();
      final List<String> expiredBookingIds = [];

      for (var doc in expiredBookingsSnapshot.docs) {
        final bookingId = doc.id;
        expiredBookingIds.add(bookingId);

        // อัพเดตสถานะเป็น expired
        batch.update(doc.reference, {
          'status': 'expired',
          'cancelReason': 'คำขอหมดเวลาอัตโนมัติหลังจาก 1 นาที',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // สร้างการแจ้งเตือนให้แอดมิน
        final adminNotifRef =
            FirebaseFirestore.instance.collection('admin_notifications').doc();

        batch.set(adminNotifRef, {
          'title': 'คำขอการจองหมดเวลา',
          'message':
              'คำขอการจอง $bookingId ได้หมดเวลาแล้วและถูกยกเลิกโดยอัตโนมัติ',
          'type': 'booking_expired',
          'bookingId': bookingId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        // เพิ่มการแจ้งเตือนให้กับผู้ใช้ด้วย
        final userData = doc.data();
        final userId = userData['userId'];
        if (userId != null) {
          final userNotifRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .doc();

          batch.set(userNotifRef, {
            'title': 'คำขอการจองหมดเวลา',
            'message':
                'คำขอการจองของคุณได้หมดเวลาแล้ว กรุณาทำรายการใหม่อีกครั้ง',
            'type': 'booking_expired',
            'bookingId': bookingId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }

      // ดำเนินการตามการเปลี่ยนแปลงทั้งหมด
      await batch.commit();

      // โหลดข้อมูลใหม่
      await _loadDashboardData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'ตรวจสอบและอัพเดตคำขอหมดเวลาสำเร็จ: ${expiredBookingIds.length} รายการ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error checking expired bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkExpiredBookingsManually() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // แสดงข้อความกำลังตรวจสอบ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กำลังตรวจสอบคำขอหมดเวลา กรุณารอสักครู่...')),
      );

      try {
        // กระตุ้น Cloud Function ผ่าน Firestore Trigger
        await FirebaseFirestore.instance
            .collection('triggers')
            .doc('checkExpiredBookings')
            .set({
          'lastTriggered': FieldValue.serverTimestamp(),
          'triggeredBy': 'admin',
          'manual': true
        });

        // รอให้ Cloud Function ทำงานเสร็จ
        await Future.delayed(Duration(seconds: 3));

        // ดึงข้อมูลผลลัพธ์การทำงานล่าสุด
        DocumentSnapshot triggerDoc = await FirebaseFirestore.instance
            .collection('triggers')
            .doc('checkExpiredBookings')
            .get();

        Map<String, dynamic>? data = triggerDoc.data() as Map<String, dynamic>?;

        if (data != null && data.containsKey('lastRun')) {
          Timestamp? lastRun = data['lastRun'] as Timestamp?;
          int processedCount = data['processedCount'] ?? 0;

          setState(() {
            _lastTriggeredTime = lastRun != null
                ? DateFormat('dd/MM/yyyy HH:mm:ss').format(lastRun.toDate())
                : "ไม่มีข้อมูล";
            _processedBookingsCount = processedCount;
          });
        }

        // โหลดข้อมูลใหม่
        await _loadDashboardData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'ตรวจสอบและอัพเดตคำขอหมดเวลาเรียบร้อยแล้ว: $_processedBookingsCount รายการ'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (firestoreError) {
        print('Error triggering function via Firestore: $firestoreError');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการส่งคำขอ: $firestoreError'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error checking expired bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // เพิ่มเข้าไปในคลาส _AdminDashboardState หลังฟังก์ชัน initState()
  Future<void> _ensureFirestoreTriggersExist() async {
    try {
      // ตรวจสอบว่าเอกสาร trigger มีอยู่แล้วหรือไม่
      DocumentSnapshot triggerDoc = await FirebaseFirestore.instance
          .collection('triggers')
          .doc('checkExpiredBookings')
          .get();

      if (!triggerDoc.exists) {
        // ถ้ายังไม่มีเอกสาร ให้สร้างใหม่
        await FirebaseFirestore.instance
            .collection('triggers')
            .doc('checkExpiredBookings')
            .set({
          'lastTriggered': null,
          'initialized': true,
          'createdAt': FieldValue.serverTimestamp()
        });
        print("สร้างเอกสาร trigger เริ่มต้นเรียบร้อยแล้ว");
      } else {
        print("มีเอกสาร trigger อยู่แล้ว - ไม่ต้องสร้างใหม่");
      }
    } catch (e) {
      print("เกิดข้อผิดพลาดในการสร้างเอกสาร trigger: $e");
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // โหลดข้อมูลผู้ใช้
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      // โหลดข้อมูลผู้รับเลี้ยงแมว
      final sittersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .get();

      // โหลดข้อมูลผู้รับเลี้ยงแมวที่รอการอนุมัติ
      final pendingSittersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .where('status', isEqualTo: 'pending')
          .get();

      // โหลดข้อมูลการจอง
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      // โหลดข้อมูลการจองที่รอดำเนินการ
      final pendingBookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .get();

      // โหลดข้อมูลการจองที่เสร็จสิ้น
      final completedBookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .get();

      // โหลดข้อมูลการแจ้งเตือนที่ยังไม่ได้อ่าน
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('admin_notifications')
          .where('isRead', isEqualTo: false)
          .get();

// เพิ่มโค้ดนี้ต่อจากข้างบน
      final expiredBookingsNotificationsSnapshot = await FirebaseFirestore
          .instance
          .collection('admin_notifications')
          .where('type', isEqualTo: 'booking_expired')
          .where('isRead', isEqualTo: false)
          .get();
      // คำนวณรายได้ทั้งหมด
      double totalRevenue = 0;
      for (var doc in completedBookingsSnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        if (data.containsKey('totalPrice')) {
          totalRevenue += (data['totalPrice'] is int)
              ? (data['totalPrice'] as int).toDouble()
              : (data['totalPrice'] as double);
        }
      }

      setState(() {
        _totalUsers = usersSnapshot.docs.length;
        _totalSitters = sittersSnapshot.docs.length;
        _pendingSitters = pendingSittersSnapshot.docs.length;
        _totalBookings = bookingsSnapshot.docs.length;
        _pendingBookings = pendingBookingsSnapshot.docs.length;
        _completedBookings = completedBookingsSnapshot.docs.length;
        _totalRevenue = totalRevenue;
        _recentBookings = bookingsSnapshot.docs;
        _pendingNotifications = notificationsSnapshot.docs.length;
        _expiredBookingsCount =
            expiredBookingsNotificationsSnapshot.docs.length;
      });

      // คำนวณรายได้และจำนวนการจองในสัปดาห์นี้และสัปดาห์ที่แล้ว
      DateTime now = DateTime.now();
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      DateTime startOfLastWeek = startOfWeek.subtract(Duration(days: 7));
      DateTime endOfLastWeek = startOfWeek.subtract(Duration(days: 1));

      Timestamp startOfWeekTimestamp = Timestamp.fromDate(startOfWeek);
      Timestamp startOfLastWeekTimestamp = Timestamp.fromDate(startOfLastWeek);
      Timestamp endOfLastWeekTimestamp = Timestamp.fromDate(endOfLastWeek);

      // จำนวนการจองในสัปดาห์นี้
      final thisWeekBookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('createdAt', isGreaterThanOrEqualTo: startOfWeekTimestamp)
          .get();

      // จำนวนการจองในสัปดาห์ที่แล้ว
      final lastWeekBookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('createdAt', isGreaterThanOrEqualTo: startOfLastWeekTimestamp)
          .where('createdAt', isLessThan: startOfWeekTimestamp)
          .get();

      // คำนวณรายได้
      double thisWeekRev = 0;
      double lastWeekRev = 0;

      for (var doc in thisWeekBookingsSnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        if (data.containsKey('totalPrice')) {
          thisWeekRev += (data['totalPrice'] is int)
              ? (data['totalPrice'] as int).toDouble()
              : (data['totalPrice'] as double);
        }
      }

      for (var doc in lastWeekBookingsSnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        if (data.containsKey('totalPrice')) {
          lastWeekRev += (data['totalPrice'] is int)
              ? (data['totalPrice'] as int).toDouble()
              : (data['totalPrice'] as double);
        }
      }

      setState(() {
        _thisWeekBookings = thisWeekBookingsSnapshot.docs.length;
        _lastWeekBookings = lastWeekBookingsSnapshot.docs.length;
        _thisWeekRevenue = thisWeekRev;
        _lastWeekRevenue = lastWeekRev;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
    }
  }

  // คำนวณเปอร์เซ็นต์การเปลี่ยนแปลง
  String _calculatePercentChange(double current, double previous) {
    if (previous == 0) {
      return current > 0 ? "+100%" : "0%";
    }
    double percentChange = ((current - previous) / previous) * 100;
    return '${percentChange >= 0 ? "+" : ""}${percentChange.toStringAsFixed(0)}%';
  }

  // ฟังก์ชันออกจากระบบ
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LogIn()),
        (route) => false,
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
        title: const Text('แดชบอร์ดผู้ดูแลระบบ'),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        actions: [
          if (_pendingNotifications > 0)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminNotificationsPage(),
                      ),
                    ).then((_) => _loadDashboardData());
                  },
                  tooltip: 'การแจ้งเตือน',
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _pendingNotifications.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            )
          else
            IconButton(
              icon: Icon(Icons.notifications_none),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminNotificationsPage(),
                  ),
                ).then((_) => _loadDashboardData());
              },
              tooltip: 'การแจ้งเตือน',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('ยืนยันการออกจากระบบ'),
                    content: Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('ยกเลิก'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _signOut();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: Text('ออกจากระบบ'),
                      ),
                    ],
                  ),
                );
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminSettingsPage()),
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('ตั้งค่า'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('ออกจากระบบ'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: Colors.deepOrange,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ส่วนบนของหน้าจอ - ข้อความต้อนรับ
                    _buildWelcomeCard(),
                    SizedBox(height: 24),

                    // แสดงคำขอรออนุมัติ (ถ้ามี)
                    if (_pendingSitters > 0) ...[
                      _buildPendingApprovalsCard(),
                      SizedBox(height: 24),
                    ],

                    // แสดงสรุปข้อมูลสำคัญ
                    _buildSummarySection(),
                    SizedBox(height: 24),

                    // แสดงส่วนเปรียบเทียบข้อมูล
                    _buildComparisonSection(),
                    SizedBox(height: 24),

                    // แสดงเมนูการจัดการระบบ
                    _buildManagementSection(),
                    SizedBox(height: 24),

                    // แสดงรายการจองล่าสุด (เรียกใช้เพียงครั้งเดียว)
                    _buildRecentBookingsSection(),
                    SizedBox(height: 24),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.settings_applications,
                                    color: Colors.blue.shade700),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'เครื่องมือจัดการระบบ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'ตรวจสอบและทำงานกับคำขอที่หมดเวลาโดยตรง',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _checkExpiredBookingsManually,
                            icon: Icon(Icons.refresh),
                            label: Text('ตรวจสอบคำขอหมดเวลาทันที'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // เพิ่ม padding ด้านล่างเพื่อป้องกัน overflow
                    SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            // สมมติว่า index 1 คือ "รายได้"
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SitterIncomeReport()),
            );
          } else if (index == 2) {
            // สมมติว่า index 2 คือ "ตั้งค่า"
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AdminSettingsPage()),
            );
          }
        },
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'แดชบอร์ด',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: 'รายได้',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'ตั้งค่า',
          ),
        ],
      ),
    );
  }

  // ส่วนข้อความต้อนรับ
  Widget _buildWelcomeCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.deepOrange.shade50,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.deepOrange.shade100,
              backgroundImage:
                  _adminPhoto.isNotEmpty && _adminPhoto != 'images/User.png'
                      ? NetworkImage(_adminPhoto)
                      : null,
              child: _adminPhoto.isEmpty || _adminPhoto == 'images/User.png'
                  ? Icon(
                      Icons.admin_panel_settings,
                      color: Colors.deepOrange,
                      size: 32,
                    )
                  : null,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ยินดีต้อนรับ, $_adminName',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange.shade800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy', 'th')
                        .format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.deepOrange.shade600,
                    ),
                  ),
                  if (_adminEmail.isNotEmpty)
                    Text(
                      _adminEmail,
                      style: TextStyle(
                        color: Colors.deepOrange.shade400,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ส่วนแสดงคำขอรออนุมัติ
  Widget _buildPendingApprovalsCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.amber.shade50,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber.shade800,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'คำขอที่รอการอนุมัติ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade800,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_pendingSitters รายการ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'มีคำขอเป็นพี่เลี้ยงแมวรออนุมัติ $_pendingSitters รายการ กรุณาตรวจสอบและดำเนินการโดยเร็ว',
              style: TextStyle(
                color: Colors.amber.shade800,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SitterVerificationPage()),
                  ).then((_) => _loadDashboardData());
                },
                icon: Icon(Icons.arrow_forward),
                label: Text('ไปที่หน้าตรวจสอบและอนุมัติ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ส่วนสรุปข้อมูลสำคัญ
  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ภาพรวมระบบ',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 12),
        Container(
          width: double.infinity,
          child: GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildSimpleStatCard(
                'ผู้ใช้ทั้งหมด',
                _totalUsers.toString(),
                Icons.people,
                Colors.blue,
              ),
              _buildSimpleStatCard(
                'พี่เลี้ยงแมว',
                _totalSitters.toString(),
                Icons.pets,
                Colors.deepOrange,
              ),
              _buildSimpleStatCard(
                'การจองทั้งหมด',
                _totalBookings.toString(),
                Icons.calendar_month,
                Colors.purple,
              ),
              _buildSimpleStatCard(
                'รายได้ทั้งหมด',
                '฿${NumberFormat('#,##0').format(_totalRevenue)}',
                Icons.monetization_on,
                Colors.green,
              ),
            ],
          ),
        ),
      ],
    );
  }

// เพิ่ม method ใหม่สำหรับแสดงการ์ดสถิติแบบง่าย
  Widget _buildSimpleStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
              ],
            ),
            Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ส่วนเปรียบเทียบข้อมูล
  Widget _buildComparisonSection() {
    // คำนวณเปอร์เซ็นต์การเปลี่ยนแปลง
    String bookingChangePercent = _calculatePercentChange(
        _thisWeekBookings.toDouble(), _lastWeekBookings.toDouble());
    String revenueChangePercent =
        _calculatePercentChange(_thisWeekRevenue, _lastWeekRevenue);

    // กำหนดสีตามค่าเปอร์เซ็นต์
    Color bookingChangeColor =
        bookingChangePercent.startsWith('+') ? Colors.green : Colors.red;
    Color revenueChangeColor =
        revenueChangePercent.startsWith('+') ? Colors.green : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'เปรียบเทียบกับสัปดาห์ที่แล้ว',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 12),
        // แก้ไขให้เป็น Row ที่มี Card 2 อันตรงๆ ไม่มีข้อความด้านข้าง
        Row(
          children: [
            // การ์ดแสดงจำนวนการจอง
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'การจอง (สัปดาห์นี้)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '${_thisWeekBookings} รายการ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            bookingChangePercent.startsWith('+')
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: bookingChangeColor,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            bookingChangePercent,
                            style: TextStyle(
                              color: bookingChangeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // การ์ดแสดงรายได้
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'รายได้ (สัปดาห์นี้)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '฿${NumberFormat('#,##0').format(_thisWeekRevenue)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            revenueChangePercent.startsWith('+')
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: revenueChangeColor,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            revenueChangePercent,
                            style: TextStyle(
                              color: revenueChangeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ส่วนการจัดการระบบ
  Widget _buildManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'การจัดการระบบ',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        // เพิ่มไว้ต่อจากเมนูที่มีอยู่เดิม
        SizedBox(height: 8),
        _buildManagementCard(
          'ประวัติการลบคำขอหมดเวลา',
          'ดูรายการคำขอที่ถูกลบเพราะหมดเวลา',
          Icons.delete_sweep,
          Colors.red.shade700,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DeletedBookingsPage()),
            );
          },
        ),
        SizedBox(height: 12),
        _buildManagementCard(
          'อนุมัติพี่เลี้ยงแมว',
          'ตรวจสอบและอนุมัติผู้ที่ขอเป็นพี่เลี้ยงแมว',
          Icons.verified_user,
          Colors.amber,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SitterVerificationPage()),
            ).then((_) => _loadDashboardData());
          },
          badgeCount: _pendingSitters,
        ),
        SizedBox(height: 8),
        _buildManagementCard(
          'จัดการการจอง',
          'ดูและจัดการรายการจองทั้งหมด',
          Icons.calendar_month,
          Colors.purple,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BookingManagementPage()),
            ).then((_) => _loadDashboardData());
          },
          badgeCount: _pendingBookings,
        ),
        SizedBox(height: 8),
        _buildManagementCard(
          'จัดการผู้ใช้',
          'ดูและจัดการข้อมูลผู้ใช้งานทั้งหมด',
          Icons.people,
          Colors.blue,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserManagementPage()),
            ).then((_) => _loadDashboardData());
          },
        ),
        SizedBox(height: 8),
        _buildManagementCard(
          'จัดการการจองแบบกลุ่ม',
          'ลบและจัดการการจองหลายรายการพร้อมกัน',
          Icons.delete_sweep,
          Colors.red,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => BatchBookingManagementPage()),
            ).then((_) => _loadDashboardData());
          },
        ),
        SizedBox(height: 8),
        _buildManagementCard(
          'รายงานรายได้',
          'ดูรายงานรายได้ของพี่เลี้ยงแมว',
          Icons.bar_chart,
          Colors.green,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SitterIncomeReport()),
            );
          },
        ),
        // เพิ่มต่อจากเมนูที่มีอยู่เดิม
        SizedBox(height: 8),
        _buildManagementCard(
          'จัดการค่าบริการ',
          'กำหนดอัตราค่าบริการและค่าธรรมเนียมต่างๆ',
          Icons.attach_money,
          Colors.teal,
          () {
            // ตำแหน่งที่มีการเรียกใช้ ServiceFeeManagementPage

            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ServiceFeeManagementPage()),
            ).then((value) {
              // เรียกใช้ _loadDashboardData หลังจากกลับมาจากหน้าจัดการค่าบริการ
              // เพื่อให้แน่ใจว่าข้อมูลถูกรีเฟรช
              _loadDashboardData();
            });
          },
        ),
        SizedBox(height: 8),
        _buildManagementCard(
          'คำขอที่หมดเวลา',
          'ตรวจสอบคำขอการจองที่หมดเวลาและถูกยกเลิกอัตโนมัติ',
          Icons.timer_off,
          Colors.grey,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AdminNotificationsPage()),
            ).then((_) => _loadDashboardData());
          },
          badgeCount: _expiredBookingsCount,
        ),

        // เพิ่มปุ่มตรวจสอบคำขอหมดเวลาทันที
        SizedBox(height: 20),
      ],
    );
  }

  // ส่วนรายการจองล่าสุด
  Widget _buildRecentBookingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'การจองล่าสุด',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => BookingManagementPage()),
                ).then((_) => _loadDashboardData());
              },
              icon: Icon(Icons.arrow_forward, size: 16),
              label: Text('ดูทั้งหมด'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepOrange,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        _recentBookings.isEmpty
            ? _buildEmptyRecentBookings()
            : Column(
                children: _recentBookings.map((booking) {
                  Map<String, dynamic> bookingData =
                      booking.data() as Map<String, dynamic>;
                  return _buildBookingCard(booking.id, bookingData);
                }).toList(),
              ),
      ],
    );
  }

  // การ์ดว่างเมื่อไม่มีการจองล่าสุด
  Widget _buildEmptyRecentBookings() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'ไม่มีการจองล่าสุด',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // การ์ดแสดงรายการจอง
  Widget _buildBookingCard(String bookingId, Map<String, dynamic> bookingData) {
    String status = bookingData['status'] ?? 'pending';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 1,
      margin: EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingDetailPage(
                bookingId: bookingId,
              ),
            ),
          ).then((_) => _loadDashboardData());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        _getStatusIcon(status),
                        color: _getStatusColor(status),
                        size: 24,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'รหัส: ${bookingId.substring(0, 8)}...',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
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
                          ],
                        ),
                        SizedBox(height: 8),
                        if (bookingData['createdAt'] != null)
                          Text(
                            'วันที่จอง: ${DateFormat('dd/MM/yyyy').format((bookingData['createdAt'] as Timestamp).toDate())}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        if (bookingData['totalPrice'] != null)
                          Text(
                            'ราคา: ฿${NumberFormat('#,##0').format(bookingData['totalPrice'])}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (status == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            _updateBookingStatus(bookingId, 'cancelled'),
                        child: Text('ยกเลิก'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            _updateBookingStatus(bookingId, 'confirmed'),
                        child: Text('ยืนยัน'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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

  // อัพเดทสถานะการจอง
  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // อัพเดทสถานะการจอง
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'adminMessage': 'อัพเดทโดยผู้ดูแลระบบ',
      });

      // โหลดข้อมูลใหม่
      _loadDashboardData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัพเดทสถานะการจองเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating booking status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการอัพเดทสถานะ: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // การ์ดแสดงสถิติ
  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      Widget destinationPage) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationPage),
        ).then((_) => _loadDashboardData());
      },
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                  ),
                ],
              ),
              Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: 4),
              // แก้ไขส่วนนี้โดยลบข้อความแสดงดูข้อมูลเพิ่มเติมออก
              // เนื่องจากที่ทำให้เกิดข้อความ BOTTOM OVERLAYED คือมีข้อความล้นออกมา
              Container(
                height: 8, // ใส่ container เปล่าแทนเพื่อให้มีระยะห่างด้านล่าง
              ),
            ],
          ),
        ),
      ),
    );
  }

  // การ์ดแสดงข้อมูลเปรียบเทียบ
  Widget _buildComparisonCard(String title, String value, String change,
      Color changeColor, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: changeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: changeColor,
                    size: 20,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  change.contains('-')
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: changeColor,
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  'เทียบกับสัปดาห์ที่แล้ว',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // การ์ดเมนูจัดการระบบ
  Widget _buildManagementCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap,
      {int badgeCount = 0}) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
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
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              else
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'confirmed':
        return Colors.blue;
      case 'in_progress':
        return Colors.indigo;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions;
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.pets;
      case 'completed':
        return Icons.task_alt;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'in_progress':
        return 'กำลังให้บริการ';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }
}
