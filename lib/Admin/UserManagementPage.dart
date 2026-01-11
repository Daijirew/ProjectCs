import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // สำหรับเก็บข้อมูลผู้ใช้ทั้งหมด (แทนการดึงข้อมูลซ้ำๆ)
  List<DocumentSnapshot> _users = [];
  List<DocumentSnapshot> _sitters = [];
  List<DocumentSnapshot> _admins = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // ล้างการค้นหาเมื่อเปลี่ยนแท็บ
      setState(() {
        _searchController.clear();
        _searchQuery = '';
      });
    });

    // โหลดข้อมูลเมื่อเริ่มแอพ
    _loadAllUsers();
  }

// เพิ่มฟังก์ชันนี้ในคลาส _UserManagementPageState
  Future<Map<String, dynamic>> _getUserFinancialData(String userId) async {
    try {
      // ข้อมูลการเงินจากคอลเลกชัน wallets หรือ finances
      DocumentSnapshot walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(userId)
          .get();

      // ถ้าไม่พบข้อมูลในคอลเลกชัน wallets ให้ดูในคอลเลกชัน finances (ถ้ามี)
      if (!walletDoc.exists) {
        walletDoc = await FirebaseFirestore.instance
            .collection('finances')
            .doc(userId)
            .get();
      }

      // ถ้ามีข้อมูลการเงิน
      if (walletDoc.exists) {
        return walletDoc.data() as Map<String, dynamic>;
      }

      // ข้อมูลการจองที่เสร็จสิ้นสำหรับผู้รับเลี้ยง (เฉพาะสถานะ completed)
      if (userId != null) {
        double totalEarnings = 0;
        int completedBookings = 0;

        // สำหรับผู้รับเลี้ยง (sitter) - ดึงข้อมูลการจองที่เสร็จสิ้น
        QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance
            .collection('bookings')
            .where('sitterId', isEqualTo: userId)
            .where('status', isEqualTo: 'completed')
            .get();

        for (var doc in bookingsSnapshot.docs) {
          Map<String, dynamic> bookingData = doc.data() as Map<String, dynamic>;
          if (bookingData['totalPrice'] != null) {
            double price = bookingData['totalPrice'] is int
                ? (bookingData['totalPrice'] as int).toDouble()
                : (bookingData['totalPrice'] as double);
            totalEarnings += price;
            completedBookings++;
          }
        }

        // สำหรับผู้ใช้ทั่วไป (user) - ดึงข้อมูลการใช้จ่าย
        QuerySnapshot userBookingsSnapshot = await FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: userId)
            .get();

        double totalSpending = 0;
        int totalBookings = userBookingsSnapshot.size;

        for (var doc in userBookingsSnapshot.docs) {
          Map<String, dynamic> bookingData = doc.data() as Map<String, dynamic>;
          if (bookingData['totalPrice'] != null) {
            double price = bookingData['totalPrice'] is int
                ? (bookingData['totalPrice'] as int).toDouble()
                : (bookingData['totalPrice'] as double);
            totalSpending += price;
          }
        }

        return {
          'balance': 0, // ไม่พบยอดเงินคงเหลือโดยตรง
          'totalEarnings': totalEarnings,
          'totalSpending': totalSpending,
          'completedBookings': completedBookings,
          'totalBookings': totalBookings,
          'calculated': true // บอกว่าเป็นข้อมูลที่คำนวณได้ ไม่ใช่ข้อมูลโดยตรง
        };
      }

      // ถ้าไม่พบข้อมูลการเงินใดๆ
      return {
        'balance': 0,
        'totalEarnings': 0,
        'totalSpending': 0,
        'completedBookings': 0,
        'totalBookings': 0,
        'notFound': true
      };
    } catch (e) {
      print('Error fetching financial data: $e');
      return {
        'error': e.toString(),
        'balance': 0,
        'totalEarnings': 0,
        'totalSpending': 0
      };
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      // แสดงหน้าต่างยืนยันการลบ
      bool confirmDelete = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('ยืนยันการลบผู้ใช้'),
          content: Text(
              'คุณต้องการลบผู้ใช้นี้หรือไม่? การดำเนินการนี้ไม่สามารถยกเลิกได้'),
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
              child: Text('ลบผู้ใช้'),
            ),
          ],
        ),
      );

      if (confirmDelete != true) return;

      // เริ่มการลบ
      setState(() {
        _isLoading = true;
      });

      // 1. ลบการจองทั้งหมดของผู้ใช้
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in bookingsSnapshot.docs) {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(doc.id)
            .delete();
      }

      // 2. ลบแมวทั้งหมดของผู้ใช้
      final catsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cats')
          .get();

      for (var doc in catsSnapshot.docs) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('cats')
            .doc(doc.id)
            .delete();
      }

      // 3. ลบการแจ้งเตือนทั้งหมดของผู้ใช้
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      for (var doc in notificationsSnapshot.docs) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(doc.id)
            .delete();
      }

      // 4. ลบข้อมูลผู้ใช้
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      // 5. ลบบัญชีผู้ใช้จาก Authentication (ต้องใช้ Admin SDK หรือ Cloud Functions)
      // สำหรับการลบผู้ใช้จาก Authentication จำเป็นต้องใช้ Firebase Admin SDK
      // ซึ่งต้องทำผ่าน Cloud Functions หรือ Backend

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบผู้ใช้เรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );

      // โหลดข้อมูลใหม่
      _loadAllUsers();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error deleting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการลบผู้ใช้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadAllUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // โหลดข้อมูลผู้ใช้ทั่วไป
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .get();

      // โหลดข้อมูลพี่เลี้ยง
      final sittersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .get();

      // โหลดข้อมูลแอดมิน
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      setState(() {
        _users = usersSnapshot.docs;
        _sitters = sittersSnapshot.docs;
        _admins = adminsSnapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // เปิดแอปโทรศัพท์เพื่อโทรหาผู้ใช้
  Future<void> _callUser(String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่พบหมายเลขโทรศัพท์')),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถโทรออกได้')),
      );
    }
  }

  // เปิดแอปอีเมลเพื่อส่งอีเมลถึงผู้ใช้
  Future<void> _emailUser(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่พบอีเมล')),
      );
      return;
    }

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'แจ้งข้อมูลจากแอปพลิเคชันรับเลี้ยงแมว'},
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถเปิดแอปอีเมลได้')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการผู้ใช้งาน'),
        backgroundColor: Colors.deepOrange,
        actions: [
          // ปุ่มรีเฟรชข้อมูล
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllUsers,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'ผู้ใช้ทั่วไป'),
            Tab(text: 'พี่เลี้ยงแมว'),
            Tab(text: 'แอดมิน'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ช่องค้นหา
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาจากชื่อ อีเมล หรือเบอร์โทร',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.deepOrange, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),

                // แสดงรายการผู้ใช้งาน
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // แท็บผู้ใช้ทั่วไป
                      _buildUsersListView(_users, 'user'),

                      // แท็บพี่เลี้ยงแมว
                      _buildUsersListView(_sitters, 'sitter'),

                      // แท็บแอดมิน
                      _buildUsersListView(_admins, 'admin'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUsersListView(List<DocumentSnapshot> docs, String role) {
    // กรองข้อมูลตามคำค้นหา
    var filteredDocs = docs;
    if (_searchQuery.isNotEmpty) {
      filteredDocs = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final phone = (data['phone'] ?? '').toString().toLowerCase();

        return name.contains(_searchQuery.toLowerCase()) ||
            email.contains(_searchQuery.toLowerCase()) ||
            phone.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (filteredDocs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'ไม่พบข้อมูลผู้ใช้งาน'
                  : 'ไม่พบข้อมูลที่ตรงกับการค้นหา',
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
      itemCount: filteredDocs.length,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final doc = filteredDocs[index];
        final userData = doc.data() as Map<String, dynamic>;

        return Card(
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => _buildUserDetailDialog(userData, doc.id),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // รูปโปรไฟล์
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: userData['photo'] != null &&
                            userData['photo'].toString().isNotEmpty &&
                            userData['photo'] != 'images/User.png'
                        ? NetworkImage(userData['photo'])
                        : null,
                    child: (userData['photo'] == null ||
                            userData['photo'].toString().isEmpty ||
                            userData['photo'] == 'images/User.png')
                        ? Icon(Icons.person, size: 30)
                        : null,
                  ),
                  SizedBox(width: 16),

                  // ข้อมูลผู้ใช้
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData['name'] ?? 'ไม่ระบุชื่อ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        if (userData['email'] != null)
                          Text(
                            userData['email'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        if (userData['phone'] != null)
                          Text(
                            'โทร: ${userData['phone']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        SizedBox(height: 4),

                        // แสดงสถานะสำหรับพี่เลี้ยง
                        if (role == 'sitter' && userData['status'] != null)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(userData['status'])
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusText(userData['status']),
                              style: TextStyle(
                                color: _getStatusColor(userData['status']),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ปุ่มโทรและส่งอีเมล
                  Column(
                    children: [
                      if (userData['phone'] != null &&
                          userData['phone'].toString().isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.call, color: Colors.green),
                          onPressed: () => _callUser(userData['phone']),
                          tooltip: 'โทรหาผู้ใช้',
                        ),
                      if (userData['email'] != null &&
                          userData['email'].toString().isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.email, color: Colors.blue),
                          onPressed: () => _emailUser(userData['email']),
                          tooltip: 'ส่งอีเมลถึงผู้ใช้',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'รอการอนุมัติ';
      case 'approved':
        return 'อนุมัติแล้ว';
      case 'rejected':
        return 'ถูกปฏิเสธ';
      default:
        return 'ไม่ระบุสถานะ';
    }
  }

// เพิ่มฟังก์ชันในคลาส _UserManagementPageState
  Widget _buildFinancialItem(
      String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // แก้ไขฟังก์ชัน _buildUserDetailDialog
  Widget _buildUserDetailDialog(Map<String, dynamic> userData, String userId) {
    return AlertDialog(
      title: const Text('ข้อมูลผู้ใช้งาน'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: userData['photo'] != null &&
                        userData['photo'].toString().isNotEmpty &&
                        userData['photo'] != 'images/User.png'
                    ? NetworkImage(userData['photo'])
                    : null,
                child: (userData['photo'] == null ||
                        userData['photo'].toString().isEmpty ||
                        userData['photo'] == 'images/User.png')
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
            ),
            SizedBox(height: 16),

            // ข้อมูลทั่วไป
            _buildDetailItem('ชื่อ', userData['name'] ?? 'ไม่ระบุ'),
            _buildDetailItem('อีเมล', userData['email'] ?? 'ไม่ระบุ'),
            _buildDetailItem('เบอร์โทร', userData['phone'] ?? 'ไม่ระบุ'),
            _buildDetailItem('บทบาท', _getRoleText(userData['role'])),

            // ข้อมูลเฉพาะสำหรับพี่เลี้ยง
            if (userData['role'] == 'sitter')
              _buildDetailItem('สถานะ', _getStatusText(userData['status'])),

            if (userData['role'] == 'sitter' && userData['address'] != null)
              _buildDetailItem('ที่อยู่', userData['address']),

            if (userData['createdAt'] != null)
              _buildDetailItem(
                'สมัครเมื่อ',
                DateFormat('dd/MM/yyyy HH:mm')
                    .format((userData['createdAt'] as Timestamp).toDate()),
              ),

            if (userData['role'] == 'sitter' &&
                userData['rejectionReason'] != null)
              _buildDetailItem(
                  'เหตุผลที่ถูกปฏิเสธ', userData['rejectionReason']),

            // เพิ่มส่วนแสดงข้อมูลการเงิน
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),

            // หัวข้อข้อมูลการเงิน
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'ข้อมูลการเงิน',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // แสดงข้อมูลการเงินโดยใช้ FutureBuilder
            FutureBuilder<Map<String, dynamic>>(
              future: _getUserFinancialData(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'เกิดข้อผิดพลาดในการโหลดข้อมูลการเงิน: ${snapshot.error}',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.hasData) {
                  final financialData = snapshot.data!;

                  // ถ้าไม่พบข้อมูลการเงิน
                  if (financialData['notFound'] == true) {
                    return Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ไม่พบข้อมูลการเงินสำหรับผู้ใช้นี้',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    );
                  }

                  // แสดงข้อมูลการเงิน
                  return Column(
                    children: [
                      // ข้อมูลยอดเงินและรายได้
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            if (userData['role'] == 'sitter') ...[
                              _buildFinancialItem(
                                'รายได้ทั้งหมด',
                                '฿${NumberFormat('#,##0.00').format(financialData['totalEarnings'] ?? 0)}',
                                Icons.monetization_on,
                                Colors.green,
                              ),
                              SizedBox(height: 8),
                              _buildFinancialItem(
                                'งานที่เสร็จสมบูรณ์',
                                '${financialData['completedBookings'] ?? 0} งาน',
                                Icons.check_circle,
                                Colors.blue,
                              ),
                            ],
                            if (userData['role'] == 'user') ...[
                              _buildFinancialItem(
                                'ค่าใช้จ่ายทั้งหมด',
                                '฿${NumberFormat('#,##0.00').format(financialData['totalSpending'] ?? 0)}',
                                Icons.shopping_cart,
                                Colors.orange,
                              ),
                              SizedBox(height: 8),
                              _buildFinancialItem(
                                'จำนวนการจองทั้งหมด',
                                '${financialData['totalBookings'] ?? 0} ครั้ง',
                                Icons.calendar_today,
                                Colors.purple,
                              ),
                            ],
                            if (userData['role'] == 'admin' ||
                                financialData['balance'] != null) ...[
                              SizedBox(height: 8),
                              _buildFinancialItem(
                                'ยอดเงินคงเหลือ',
                                '฿${NumberFormat('#,##0.00').format(financialData['balance'] ?? 0)}',
                                Icons.account_balance_wallet,
                                Colors.indigo,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // ข้อมูลระบบธุรกรรม (ถ้ามี)
                      if (financialData['transactions'] != null) ...[
                        SizedBox(height: 16),
                        Text(
                          'ประวัติธุรกรรมล่าสุด',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 8),
                        // แสดงรายการธุรกรรม...
                        // สามารถเพิ่มส่วนแสดงรายการธุรกรรมได้ตามต้องการ
                      ],
                    ],
                  );
                }

                return Text('ไม่พบข้อมูล');
              },
            ),

            // ข้อมูลเพิ่มเติม
            if (userData['additionalInfo'] != null &&
                userData['additionalInfo'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'ข้อมูลเพิ่มเติม',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(userData['additionalInfo']),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
        // เพิ่มปุ่มลบผู้ใช้
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _deleteUser(userId);
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text('ลบผู้ใช้'),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleText(String? role) {
    switch (role) {
      case 'user':
        return 'ผู้ใช้ทั่วไป';
      case 'sitter':
        return 'พี่เลี้ยงแมว';
      case 'admin':
        return 'ผู้ดูแลระบบ';
      default:
        return 'ไม่ระบุบทบาท';
    }
  }
}
