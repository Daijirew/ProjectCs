import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SitterReviewsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Reviews'),
        ),
        body: const Center(
          child: Text('Please log in to see reviews.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reviews'),
        backgroundColor: Colors.purple,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('sitterId', isEqualTo: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No reviews found.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final reviews = snapshot.data!.docs;

          // คำนวณคะแนนเฉลี่ย
          double totalRating = reviews.fold<double>(
            0,
            (sum, review) => sum + (review['rating'] ?? 0),
          );
          double averageRating = totalRating / reviews.length;

          return Column(
            children: [
              SizedBox(height: 20),
              // ส่วนหัวคะแนนเฉลี่ย
              Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 16), // ปรับระยะขอบซ้ายขวาที่นี่
                padding: const EdgeInsets.symmetric(
                  vertical: 20, // ระยะขอบด้านบน-ล่าง
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  children: [
                    Text(
                      'Average Rating',
                      style: TextStyle(
                        fontSize: 22, // ลดขนาดฟอนต์
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 8), // ลดขนาดระยะห่าง
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star,
                            color: Colors.amberAccent,
                            size: 30.0), // ปรับขนาดไอคอน
                        const SizedBox(
                            width: 6), // ปรับระยะห่างระหว่างไอคอนกับตัวเลข
                        Text(
                          averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 30, // ขนาดฟอนต์ตัวเลข
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${reviews.length} reviews)',
                          style: TextStyle(
                            fontSize: 14, // ลดขนาดฟอนต์ของจำนวนรีวิว
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];

                    // ดึงข้อมูลชื่อผู้ใช้จาก Firestore
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(review['userId'])
                          .get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (!userSnapshot.hasData ||
                            !userSnapshot.data!.exists) {
                          return const ListTile(
                            title: Text('Error fetching user name'),
                          );
                        }

                        final userName =
                            userSnapshot.data!['name'] ?? 'Unknown';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          elevation: 10, // เพิ่มความชัดเจนของแรเงา
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(18), // ขอบโค้งสวยงาม
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amberAccent,
                                      size: 24.0,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      review['rating'].toString(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20, thickness: 1.0),
                                Text(
                                  review['comment'] ?? 'No comment',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Date: ${(review['timestamp'] as Timestamp).toDate()}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // แสดงชื่อผู้ใช้
                                Text(
                                  'Reviewed by: $userName',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
