import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myproject/page2.dart/_CatSearchPageState.dart';
import 'package:myproject/page2.dart/booking/sitterBookingManagement.dart';
import 'package:myproject/page2.dart/location/location.dart';
import 'package:myproject/page2.dart/showreviwe.dart';
import 'package:myproject/page2.dart/workdate/workdate.dart';
import 'package:myproject/pages.dart/details.dart';
import 'package:myproject/pages.dart/matching/matching.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myproject/services/shared_pref.dart';

class Home2 extends StatefulWidget {
  const Home2({super.key});

  @override
  State<Home2> createState() => _Home2State();
}

class _Home2State extends State<Home2> {
  bool cat = false,
      paw = false,
      backpack = false,
      ball = false,
      booking = false;
  String? userName;
  int pendingBookingsCount = 0;
  double totalEarnings = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchPendingBookingsCount();
    _loadEarningsData(); // เพิ่มการเรียกฟังก์ชันนี้
  }

  Future<void> _loadUserInfo() async {
    try {
      userName = await SharedPreferenceHelper().getDisplayName();
      setState(() {});
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  Future<void> _fetchPendingBookingsCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('sitterId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        pendingBookingsCount = snapshot.docs.length;
      });
    } catch (e) {
      print('Error fetching pending bookings count: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAdoptedCats() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('cats')
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching adopted cats: $e');
      return [];
    }
  }

  Future<void> _loadEarningsData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // ดึงข้อมูลผู้ใช้จาก Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic>? userData = userDoc.data();
        if (userData != null && userData.containsKey('wallet')) {
          String walletStr = userData['wallet'] ?? "0";
          setState(() {
            totalEarnings = double.tryParse(walletStr) ?? 0;
          });
        }
      }
    } catch (e) {
      print('Error loading earnings data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Soft grey background
      appBar: AppBar(
        title: Text(
          'หน้าหลัก',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black38,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF6FDFDF), // Soft teal
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white),
                onPressed: () {},
              ),
              if (pendingBookingsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      pendingBookingsCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สวัสดี${userName != null ? ', $userName' : ''}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.teal[800],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'เลือกทำงานที่ต้องการ:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),

              // แถบเมนูการจัดการ
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade400, Colors.teal.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'จัดการการจอง',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pendingBookingsCount > 0
                                ? 'คุณมี $pendingBookingsCount การจองที่รอยืนยัน'
                                : 'ไม่มีการจองที่รอยืนยัน',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _updateTaskState(TaskType.booking);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const SitterBookingManagement(),
                          ),
                        ).then((_) => _fetchPendingBookingsCount());
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('จัดการ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _buildTaskSelector(),
              const SizedBox(height: 20),
              const Text(
                'แมวที่ฝากไว้:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchAdoptedCats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.teal[300]!),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading cats',
                        style: TextStyle(color: Colors.red[300]),
                      ),
                    );
                  } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return _buildCatCards(snapshot.data!);
                  } else {
                    return Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.pets,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ยังไม่มีแมวที่ฝากไว้',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTaskItem('images/cat.png', 'Cat', cat, () {
          _updateTaskState(TaskType.cat);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CatSearchPage()),
          );
        }, 'แมวที่รับฝาก'),
        _buildTaskItem('images/paw.png', 'Sitter', paw, () {
          _updateTaskState(TaskType.paw);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SitterReviewsPage()),
          );
        }, 'รีวิว'),
        _buildTaskItem('images/backpack.png', 'Travel', backpack, () {
          _updateTaskState(TaskType.backpack);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AvailableDatesPage(),
            ),
          );
        }, 'วันทำงาน'),
        _buildTaskItem('images/ball.png', 'Play', ball, () {
          _updateTaskState(TaskType.ball);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LocationMapPage(),
            ),
          );
        }, 'ตำแหน่ง'),
      ],
    );
  }

  void _updateTaskState(TaskType type) {
    setState(() {
      cat = type == TaskType.cat;
      paw = type == TaskType.paw;
      backpack = type == TaskType.backpack;
      ball = type == TaskType.ball;
      booking = type == TaskType.booking;
    });
  }

  Widget _buildTaskItem(String imagePath, String label, bool isSelected,
      VoidCallback onTap, String thaiLabel) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.teal[100] : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: isSelected ? Colors.teal : Colors.transparent,
                width: 2,
              ),
            ),
            child: Image.asset(
              imagePath,
              height: 50,
              width: 50,
              fit: BoxFit.contain,
              color: isSelected ? Colors.teal : Colors.black54,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            thaiLabel,
            style: TextStyle(
              color: isSelected ? Colors.teal : Colors.black54,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatCards(List<Map<String, dynamic>> catData) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: catData.length,
      itemBuilder: (context, index) {
        final cat = catData[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Details()),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.grey[50]!,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: cat['imagePath'] != null && cat['imagePath'].isNotEmpty
                      ? Image.network(
                          cat['imagePath'],
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          'images/cat.png',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(
                        cat['name'] ?? 'Unknown Cat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        cat['breed'] ?? 'Unknown Breed',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum TaskType { cat, paw, backpack, ball, booking }
