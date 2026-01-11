import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:myproject/Catpage.dart/cat_history.dart';
import 'package:myproject/page2.dart/location/location.dart';
import 'package:myproject/pages.dart/BookingStatusScreen.dart';
import 'package:myproject/pages.dart/PrepareCatsForSittingPage.dart';
import 'package:myproject/pages.dart/details.dart';
import 'package:myproject/pages.dart/matching/matching.dart';
import 'package:myproject/pages.dart/reviwe.dart';
import 'package:myproject/test/TestNotification.dart';
import 'package:myproject/widget/widget_support.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<Home> {
  bool cat = false, paw = false, backpack = false, ball = false;
  bool isLoading = true;
  List<Map<String, dynamic>> activeBookings = [];
  String? userName;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadActiveBookings();
  }

  // โหลดข้อมูลผู้ใช้
  Future<void> _loadUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            userName = userDoc.data()?['name'] ?? 'ผู้ใช้งาน';
          });
        }
      }
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  // โหลดข้อมูลการจองที่กำลังดำเนินการอยู่
  Future<void> _loadActiveBookings() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // ดึงข้อมูลการจองจากทั้งสอง collection
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['confirmed', 'in_progress']).get();

      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('booking_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['confirmed', 'in_progress']).get();

      List<Map<String, dynamic>> tempBookings = [];

      // ประมวลผลข้อมูลจาก bookings
      for (var doc in bookingsSnapshot.docs) {
        await _processBookingData(doc, tempBookings);
      }

      // ประมวลผลข้อมูลจาก booking_requests
      for (var doc in requestsSnapshot.docs) {
        await _processBookingData(doc, tempBookings);
      }

      // เรียงลำดับตามวันที่ล่าสุด
      tempBookings.sort((a, b) {
        final DateTime dateA = a['endDate'] ?? DateTime.now();
        final DateTime dateB = b['endDate'] ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      setState(() {
        activeBookings = tempBookings;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading active bookings: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // ประมวลผลข้อมูลการจอง
  Future<void> _processBookingData(QueryDocumentSnapshot doc,
      List<Map<String, dynamic>> tempBookings) async {
    try {
      final bookingData = doc.data() as Map<String, dynamic>;
      final sitterId = bookingData['sitterId'];

      // เพิ่มการตรวจสอบว่า sitterId มีค่าและไม่เป็นค่าว่าง
      if (sitterId == null || sitterId.toString().isEmpty) {
        print('Warning: booking ${doc.id} has empty or null sitterId');

        // เพิ่มข้อมูลแม้ไม่พบผู้รับเลี้ยง แต่ใส่ป้ายกำกับ
        DateTime? startDate;
        DateTime? endDate;

        if (bookingData['dates'] != null) {
          List<Timestamp> timestamps =
              List<Timestamp>.from(bookingData['dates']);
          if (timestamps.isNotEmpty) {
            timestamps.sort((a, b) => a.compareTo(b));
            startDate = timestamps.first.toDate();
            endDate = timestamps.last.toDate();
          }
        }

        tempBookings.add({
          'id': doc.id,
          'sitterName': 'ไม่พบข้อมูลผู้รับเลี้ยง',
          'sitterPhoto': '',
          'status': bookingData['status'] ?? 'pending',
          'startDate': startDate,
          'endDate': endDate,
          'price': bookingData['totalPrice'],
          'cats': await _fetchCatData(bookingData['catIds']),
        });
        return;
      }

      try {
        // ดึงข้อมูลผู้รับเลี้ยง
        DocumentSnapshot sitterDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(sitterId)
            .get();

        // เพิ่มการตรวจสอบว่าเอกสารมีอยู่จริง
        if (!sitterDoc.exists) {
          print(
              'Warning: sitter with ID $sitterId not found for booking ${doc.id}');

          // ดึงข้อมูลวันที่ฝาก
          DateTime? startDate;
          DateTime? endDate;

          if (bookingData['dates'] != null) {
            List<Timestamp> timestamps =
                List<Timestamp>.from(bookingData['dates']);
            if (timestamps.isNotEmpty) {
              timestamps.sort((a, b) => a.compareTo(b));
              startDate = timestamps.first.toDate();
              endDate = timestamps.last.toDate();
            }
          }

          // ดึงข้อมูลแมวที่ฝากเลี้ยง
          List<Map<String, dynamic>> cats = [];
          if (bookingData['catIds'] != null) {
            cats = await _fetchCatData(bookingData['catIds']);
          }

          // เพิ่มข้อมูลการจองแม้ไม่พบผู้รับเลี้ยง
          tempBookings.add({
            'id': doc.id,
            'sitterName': 'ไม่พบข้อมูลผู้รับเลี้ยง',
            'sitterPhoto': '',
            'status': bookingData['status'] ?? 'pending',
            'startDate': startDate,
            'endDate': endDate,
            'price': bookingData['totalPrice'],
            'cats': cats,
          });
          return;
        }

        // ดึงข้อมูลวันที่ฝาก
        DateTime? startDate;
        DateTime? endDate;

        if (bookingData['dates'] != null) {
          List<Timestamp> timestamps =
              List<Timestamp>.from(bookingData['dates']);
          if (timestamps.isNotEmpty) {
            timestamps.sort((a, b) => a.compareTo(b));
            startDate = timestamps.first.toDate();
            endDate = timestamps.last.toDate();
          }
        }

        // ดึงข้อมูลแมวที่ฝากเลี้ยง
        List<Map<String, dynamic>> cats = [];
        if (bookingData['catIds'] != null) {
          final catIds = List<String>.from(bookingData['catIds']);
          if (catIds.isNotEmpty) {
            final user = FirebaseAuth.instance.currentUser;
            for (String catId in catIds) {
              try {
                final catDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .collection('cats')
                    .doc(catId)
                    .get();

                if (catDoc.exists) {
                  cats.add({
                    'id': catDoc.id,
                    'name': catDoc.data()?['name'] ?? 'ไม่ระบุชื่อ',
                    'imagePath': catDoc.data()?['imagePath'] ?? '',
                  });
                }
              } catch (e) {
                print('Error loading cat data: $e');
              }
            }
          }
        }

        // เพิ่มข้อมูลการจองที่สมบูรณ์
        tempBookings.add({
          'id': doc.id,
          'sitterName': (sitterDoc.data() as Map<String, dynamic>)['name'] ??
              'ไม่ระบุชื่อ',
          'sitterPhoto':
              (sitterDoc.data() as Map<String, dynamic>)['photo'] ?? '',
          'status': bookingData['status'] ?? 'pending',
          'startDate': startDate,
          'endDate': endDate,
          'price': bookingData['totalPrice'],
          'cats': cats,
        });
      } catch (e) {
        print('Error fetching sitter data: $e');

        // กรณีเกิดข้อผิดพลาดในการดึงข้อมูลผู้รับเลี้ยง แต่ยังต้องแสดงรายการการจอง
        DateTime? startDate;
        DateTime? endDate;

        if (bookingData['dates'] != null) {
          List<Timestamp> timestamps =
              List<Timestamp>.from(bookingData['dates']);
          if (timestamps.isNotEmpty) {
            timestamps.sort((a, b) => a.compareTo(b));
            startDate = timestamps.first.toDate();
            endDate = timestamps.last.toDate();
          }
        }

        tempBookings.add({
          'id': doc.id,
          'sitterName': 'ไม่พบข้อมูลผู้รับเลี้ยง',
          'sitterPhoto': '',
          'status': bookingData['status'] ?? 'pending',
          'startDate': startDate,
          'endDate': endDate,
          'price': bookingData['totalPrice'],
          'cats': await _fetchCatData(bookingData['catIds']),
        });
      }
    } catch (e) {
      print('Error processing booking: $e');
    }
  }

// เพิ่มฟังก์ชันสำหรับดึงข้อมูลแมว
  Future<List<Map<String, dynamic>>> _fetchCatData(
      List<dynamic>? catIds) async {
    List<Map<String, dynamic>> cats = [];
    if (catIds == null || catIds.isEmpty) return cats;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return cats;

    for (var catId in catIds) {
      try {
        if (catId == null || catId.toString().isEmpty) continue;

        final catDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cats')
            .doc(catId.toString())
            .get();

        if (catDoc.exists) {
          cats.add({
            'id': catDoc.id,
            'name': catDoc.data()?['name'] ?? 'ไม่ระบุชื่อ',
            'imagePath': catDoc.data()?['imagePath'] ?? '',
          });
        }
      } catch (e) {
        print('Error loading cat data: $e');
      }
    }

    return cats;
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'in_progress':
        return 'กำลังดูแล';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'รอการยืนยัน';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadActiveBookings();
        },
        child: SafeArea(
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.orange.shade50, Colors.white],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildWelcomeSection(),
                    const SizedBox(height: 20),
                    _buildQuickActions(),
                    const SizedBox(height: 30),
                    _buildActiveBookingsSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'หน้าหลัก',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]),
            child: const Icon(Icons.home, color: Colors.white),
          )
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                radius: 24,
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สวัสดี, ${userName ?? 'ผู้ใช้งาน'}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'ยินดีต้อนรับกลับมา',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PrepareCatsForSittingPage(),
                      ),
                    );
                  },
                  icon: Icon(Icons.pets, color: Colors.orange),
                  label: Text('ฝากเลี้ยงแมว'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange.shade700,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'บริการของเรา',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionItem('images/cat.png', cat, () {
              setState(() {
                cat = true;
                paw = backpack = ball = false;
              });
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CatHistoryPage()),
              );
            }, 'แมวของคุณ'),
            // ในไฟล์ lib/pages.dart/home.dart
// ปรับปรุงโค้ดในส่วนที่เรียกใช้หน้ารีวิว

            _buildActionItem('images/paw.png', paw, () async {
              setState(() {
                paw = true;
                cat = backpack = ball = false;
              });

              // แสดง loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text("กำลังโหลดข้อมูล...")
                        ],
                      ),
                    ),
                  );
                },
              );

              try {
                // ตรวจสอบการจองล่าสุดก่อนเปิดหน้ารีวิว
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final bookings = await FirebaseFirestore.instance
                      .collection('bookings')
                      .where('userId', isEqualTo: user.uid)
                      .where('status', isEqualTo: 'completed')
                      .orderBy('createdAt', descending: true)
                      .limit(1)
                      .get();

                  // ปิด loading dialog
                  Navigator.pop(context);

                  if (bookings.docs.isNotEmpty) {
                    final sitterId = bookings.docs.first.data()['sitterId'];
                    if (sitterId != null && sitterId.toString().isNotEmpty) {
                      // มีการจองและมี sitterId
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReviewsPage(
                            itemId: bookings.docs.first.id,
                            sitterId: sitterId,
                          ),
                        ),
                      );
                      return;
                    }
                  }

                  // ถ้าไม่พบข้อมูลการจองที่สมบูรณ์ เปิดหน้ารีวิวแบบไม่มีพารามิเตอร์
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReviewsPage(
                        itemId: 'booking_id',
                        sitterId: '/ sitters_id',
                      ),
                    ),
                  );
                } else {
                  // ปิด loading dialog
                  Navigator.pop(context);

                  // ถ้ายังไม่ได้ login
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนใช้งาน')),
                  );
                }
              } catch (e) {
                // ปิด loading dialog
                Navigator.pop(context);

                print('Error checking bookings: $e');
                // เปิดหน้ารีวิวแบบไม่มีพารามิเตอร์เมื่อเกิดข้อผิดพลาด
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReviewsPage(
                      itemId: 'booking_id',
                      sitterId: '/ sitters_id',
                    ),
                  ),
                );
              }
            }, 'รีวิว'),
            _buildActionItem('images/backpack.png', backpack, () {
              setState(() {
                backpack = true;
                cat = paw = ball = false;
              });
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrepareCatsForSittingPage(),
                ),
              );
            }, 'จองบริการ'),
            _buildActionItem('images/ball.png', ball, () {
              setState(() {
                ball = true;
                cat = paw = backpack = false;
              });
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LocationMapPage(),
                ),
              );
            }, 'ตำแหน่ง'),
          ],
        ),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingStatusScreen(),
                ),
              );
            },
            icon: const Icon(Icons.list_alt, color: Colors.white),
            label: const Text(
              'ดูสถานะการฝากเลี้ยงทั้งหมด',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem(
      String image, bool isSelected, VoidCallback onTap, String label) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.orange : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
              border: Border.all(
                color: isSelected ? Colors.orange : Colors.orange.shade100,
                width: 1.5,
              ),
            ),
            child: Image.asset(
              image,
              height: 45,
              width: 45,
              color: isSelected ? Colors.white : Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.orange.shade700 : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBookingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'การฝากเลี้ยงที่กำลังดำเนินการ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (activeBookings.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookingStatusScreen(),
                    ),
                  );
                },
                child: Text(
                  'ดูทั้งหมด',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 10),
        isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.orange))
            : activeBookings.isEmpty
                ? _buildEmptyBookings()
                : Column(
                    children: activeBookings
                        .map((booking) => _buildBookingCard(booking))
                        .toList(),
                  ),
      ],
    );
  }

  Widget _buildEmptyBookings() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets,
            size: 40,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'ไม่มีการฝากเลี้ยงที่กำลังดำเนินการ',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'คุณสามารถฝากเลี้ยงแมวได้โดยกดปุ่ม "จองบริการ"',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'pending';
    final sitterName = booking['sitterName'] ?? 'ไม่ระบุชื่อ';
    final sitterPhoto = booking['sitterPhoto'] ?? '';
    final startDate = booking['startDate'];
    final endDate = booking['endDate'];
    final price = booking['price'];
    final cats = booking['cats'] ?? [];

    String dateRange = 'ไม่ระบุวันที่';
    if (startDate != null && endDate != null) {
      final formatter = DateFormat('dd/MM/yyyy');
      dateRange =
          '${formatter.format(startDate)} - ${formatter.format(endDate)}';
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // รูปโปรไฟล์ผู้รับเลี้ยง
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      sitterPhoto.isNotEmpty ? NetworkImage(sitterPhoto) : null,
                  child: sitterPhoto.isEmpty
                      ? Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                SizedBox(width: 12),

                // ข้อมูลผู้รับเลี้ยง
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ผู้รับเลี้ยง: $sitterName',
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
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusText(status),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          if (price != null)
                            Text(
                              '฿${price.toString()}',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // วันที่ฝากเลี้ยง
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8),
                  Text(
                    dateRange,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // รายการแมวที่ฝากเลี้ยง
            if (cats.isNotEmpty) ...[
              Text(
                'แมวที่ฝากเลี้ยง:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  itemBuilder: (context, index) {
                    final cat = cats[index];
                    return Container(
                      margin: EdgeInsets.only(right: 10),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: cat['imagePath'].isNotEmpty
                                ? NetworkImage(cat['imagePath'])
                                : null,
                            child: cat['imagePath'].isEmpty
                                ? Icon(Icons.pets, color: Colors.grey)
                                : null,
                          ),
                          SizedBox(height: 4),
                          Text(
                            cat['name'] ?? 'แมว',
                            style: TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            // ปุ่มดูรายละเอียดเพิ่มเติม
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      // ไปยังหน้ารายละเอียดการจอง
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingStatusScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'ดูรายละเอียด',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                      ),
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
}
