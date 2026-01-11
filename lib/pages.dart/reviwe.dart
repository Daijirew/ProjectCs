import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Review {
  final String id;
  final String userId;
  final double rating;
  final String comment;
  final DateTime timestamp;

  Review({
    required this.id,
    required this.userId,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      userId: data['userId'] ?? '',
      rating: (data['rating'] as num).toDouble(),
      comment: data['comment'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'rating': rating,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

class ReviewConstants {
  static const String collectionName = 'reviews';
  static const int pageSize = 10;
  static const double minRating = 1.0;
  static const int maxCommentLength = 500;
}

class ReviewsPage extends StatefulWidget {
  final String itemId;
  String sitterId; // เปลี่ยนจาก final เป็นแค่ String ธรรมดา

  ReviewsPage({
    Key? key,
    required this.itemId,
    required this.sitterId,
  }) : super(key: key);

  @override
  _ReviewsPageState createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double _rating = 0;
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;
  List<Review> _reviews = [];
  double _averageRating = 0;
  String sitterName = '';

  @override
  void initState() {
    super.initState();
    _setHardcodedSitterId().then((_) {
      _initializeData();
      _setupScrollListener();
    });
  }

  // เพิ่มฟังก์ชันนี้ใน class _ReviewsPageState
  Future<void> _setHardcodedSitterId() async {
    // ระบุ sitterId ที่แน่นอนตรงนี้ - แทนที่ด้วย ID จริงของพี่เลี้ยงแมวที่คุณต้องการ
    final String hardcodedSitterId = "SE9htBfMnRbSnTUgA9bViITgH6M2";

    // อัปเดต sitterId ใน widget
    setState(() {
      // ในรูปแบบปกติจะไม่สามารถอัปเดต final ได้ แต่เราสามารถใช้ hack ดังนี้
      (widget as dynamic).sitterId = hardcodedSitterId;
    });

    // โหลดข้อมูลใหม่
    await _loadSitterData();

    // ตรวจสอบว่าโหลดสำเร็จไหม
    if (sitterName == 'Unknown') {
      _showErrorSnackBar('ยังคงไม่สามารถโหลดข้อมูลพี่เลี้ยงแมวได้');
    } else {
      _showSuccessSnackBar('โหลดข้อมูลพี่เลี้ยงแมวสำเร็จ: $sitterName');
    }
  }

  Future<void> _loadSitterData() async {
    try {
      final sitterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sitterId)
          .get();

      if (sitterDoc.exists) {
        setState(() {
          sitterName = sitterDoc.data()?['name'] ?? 'Unknown';
        });
      }
    } catch (e) {
      print('Error loading sitter data: $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMoreReviews();
      }
    });
  }

  Future<void> _initializeData() async {
    try {
      await Future.wait([
        _loadInitialReviews(),
        _calculateAverageRating(),
      ]);
    } catch (e) {
      _showErrorSnackBar('Error loading reviews: $e');
    }
  }

  Future<void> _loadInitialReviews() async {
    setState(() => _isLoading = true);
    try {
      // ดึง ID ของ user ปัจจุบัน
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(ReviewConstants.collectionName)
          .where('sitterId', isEqualTo: widget.sitterId)
          .where('userId', isEqualTo: currentUser.uid) // เพิ่มเงื่อนไขนี้
          .orderBy('timestamp', descending: true)
          .limit(ReviewConstants.pageSize)
          .get();

      _processQuerySnapshot(snapshot);
    } catch (e) {
      _showErrorSnackBar('Error loading reviews');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreReviews() async {
    if (_isLoading || _lastDocument == null) return;

    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(ReviewConstants.collectionName)
          .where('sitterId', isEqualTo: widget.sitterId)
          .where('userId', isEqualTo: currentUser.uid) // เพิ่มเงื่อนไขนี้
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(ReviewConstants.pageSize)
          .get();

      _processQuerySnapshot(snapshot);
    } catch (e) {
      _showErrorSnackBar('Error loading more reviews');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _processQuerySnapshot(QuerySnapshot snapshot) {
    final newReviews =
        snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();

    setState(() {
      _reviews.addAll(newReviews);
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
    });
  }

  Future<void> _calculateAverageRating() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(ReviewConstants.collectionName)
          .where('sitterId', isEqualTo: widget.sitterId)
          .where('userId', isEqualTo: currentUser.uid) // เพิ่มเงื่อนไขนี้
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => _averageRating = 0);
        return;
      }

      final totalRating = snapshot.docs
          .map((doc) => (doc.get('rating') as num).toDouble())
          .fold<double>(0, (sum, rating) => sum + rating);

      setState(() {
        _averageRating = totalRating / snapshot.docs.length;
      });
    } catch (e) {
      print('Error calculating average rating: $e');
    }
  }

  Future<void> _addReview() async {
    if (!_validateReview()) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar('Please login to add a review');
        return;
      }

      setState(() => _isLoading = true);

      final newReview = Review(
        id: '',
        userId: currentUser.uid,
        rating: _rating,
        comment: _commentController.text.trim(),
        timestamp: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection(ReviewConstants.collectionName)
          .add({
        ...newReview.toMap(),
        'itemId': widget.itemId,
        'sitterId': widget.sitterId,
      });

      _resetForm();
      await _initializeData();
      _showSuccessSnackBar('Review added successfully');
    } catch (e) {
      _showErrorSnackBar('Error adding review: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateReview() {
    if (_rating < ReviewConstants.minRating) {
      _showErrorSnackBar('Please provide a rating');
      return false;
    }

    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      _showErrorSnackBar('Please write a comment');
      return false;
    }

    if (comment.length > ReviewConstants.maxCommentLength) {
      _showErrorSnackBar('Comment is too long');
      return false;
    }

    return true;
  }

  void _resetForm() {
    setState(() {
      _rating = 0;
      _commentController.clear();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reviews',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _initializeData,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.teal.shade50, Colors.white],
            ),
          ),
          child: Column(
            children: [
              _buildSitterInfo(),
              _buildAverageRatingCard(),
              Expanded(
                child: _reviews.isEmpty && !_isLoading
                    ? _buildEmptyReviewsWidget()
                    : _buildReviewsList(),
              ),
              _buildAddReviewForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSitterInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.teal.shade100,
                  child: const Icon(Icons.person, size: 30, color: Colors.teal),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sitterName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cat Sitter',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      // แสดง sitterId สำหรับการดีบัก
                      Text(
                        'SitterId: ${widget.sitterId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                // เพิ่มปุ่มรีเฟรช
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _loadSitterData();
                    _initializeData();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyReviewsWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No reviews yet\nBe the first to review!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageRatingCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Average Rating',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 36,
                ),
              ],
            ),
            Text(
              '(${_reviews.length} reviews)',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _reviews.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _reviews.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final review = _reviews[index];
        return _buildReviewCard(review);
      },
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: const Icon(
                    Icons.person,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User ${review.userId.substring(0, 5)}...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      RatingBarIndicator(
                        rating: review.rating,
                        itemBuilder: (context, _) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        itemCount: 5,
                        itemSize: 20,
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(review.timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                review.comment,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddReviewForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Write a Review',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: RatingBar.builder(
              initialRating: _rating,
              minRating: ReviewConstants.minRating,
              direction: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'Share your experience...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal),
              ),
              counterText:
                  '${_commentController.text.length}/${ReviewConstants.maxCommentLength}',
            ),
            maxLines: 3,
            maxLength: ReviewConstants.maxCommentLength,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Submit Review',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
