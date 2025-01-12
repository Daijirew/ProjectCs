import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewsPage extends StatefulWidget {
  final String itemId; // ไอดีของไอเทมที่ต้องการแสดงรีวิว
  const ReviewsPage({Key? key, required this.itemId}) : super(key: key);

  @override
  _ReviewsPageState createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final TextEditingController _commentController = TextEditingController();
  double _rating = 0;
  String? _sitterId;

  // ฟังก์ชันเพิ่มรีวิวใหม่
  Future<void> _addReview() async {
    if (_rating == 0 || _commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating and comment!')),
      );
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in!')),
        );
        return;
      }

      // เพิ่มข้อมูลรีวิวใน Firestore
      await FirebaseFirestore.instance.collection('reviews').add({
        'itemId': widget.itemId,
        'sitterId':
            _sitterId ?? 'qMiu4Jh11Mbj5vzV3YEi23qp0Kv1', // ใช้ sitterId ถ้ามี
        'userId': currentUser.uid,
        'rating': _rating,
        'comment': _commentController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      setState(() {
        _rating = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding review: $e')),
      );
    }
  }

  // ฟังก์ชันคำนวณคะแนนเฉลี่ย
  Future<double> _getAverageRating() async {
    try {
      final reviews = await FirebaseFirestore.instance
          .collection('reviews')
          .where('itemId', isEqualTo: widget.itemId)
          .get();

      if (reviews.docs.isEmpty) return 0.0;

      final totalRating = reviews.docs
          .map((doc) => (doc['rating'] as num).toDouble())
          .fold(0.0, (a, b) => a + b);

      return totalRating / reviews.docs.length;
    } catch (e) {
      print('Error fetching average rating: $e');
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          // คะแนนเฉลี่ย
          FutureBuilder<double>(
            future: _getAverageRating(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Average Rating: ${snapshot.data?.toStringAsFixed(1) ?? '0.0'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('itemId', isEqualTo: widget.itemId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No reviews yet.'));
                }

                final reviews = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                RatingBarIndicator(
                                  rating: (review['rating'] as num).toDouble(),
                                  itemBuilder: (context, _) => const Icon(
                                      Icons.star,
                                      color: Colors.amber),
                                  itemCount: 5,
                                  itemSize: 24.0,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Rating: ${(review['rating'] as num).toDouble()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              review['comment'] ?? '',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'By: ${review['userId']}',
                              style: const TextStyle(color: Colors.grey),
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
          // แบบฟอร์มเพิ่มรีวิวใหม่
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add a Review: ',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                RatingBar.builder(
                  initialRating: 0,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: false,
                  itemCount: 5,
                  itemBuilder: (context, _) =>
                      const Icon(Icons.star, color: Colors.amber),
                  onRatingUpdate: (rating) {
                    setState(() {
                      _rating = rating;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    labelText: 'Write your review...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5, // เพิ่ม maxLines เพื่อให้ช่องเขียนใหญ่ขึ้น
                  minLines: 5, // กำหนด minLines ให้อยู่ที่ 5 บรรทัด
                  style:
                      const TextStyle(fontSize: 18), // ปรับขนาดฟอนต์ให้ใหญ่ขึ้น
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _addReview,
                  child: const Text('Submit Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    textStyle: const TextStyle(fontSize: 16),
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
    );
  }
}
