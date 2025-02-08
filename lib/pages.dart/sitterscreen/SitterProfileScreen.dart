import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:myproject/page2.dart/showreviwe.dart';
import 'package:myproject/pages.dart/reviwe.dart';
import 'package:myproject/pages.dart/sitterscreen/bookingService.dart';
import 'package:myproject/pages.dart/sitterscreen/bookscreen.dart';

class SitterProfileScreen extends StatefulWidget {
  final String sitterId;
  final List<DateTime> targetDates;

  const SitterProfileScreen({
    Key? key,
    required this.sitterId,
    required this.targetDates,
  }) : super(key: key);

  @override
  State<SitterProfileScreen> createState() => _SitterProfileScreenState();
}

class _SitterProfileScreenState extends State<SitterProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _sitterData;
  Map<String, dynamic>? _locationData;
  final Set<Marker> _markers = {};
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'th');
  List<Review> _reviews = [];
  double _averageRating = 0;
  bool _loadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadSitterData();
    _loadReviews();
  }

  Future<void> _loadSitterData() async {
    try {
      // Load sitter's basic information
      DocumentSnapshot sitterDoc =
          await _firestore.collection('users').doc(widget.sitterId).get();

      if (!sitterDoc.exists) {
        throw Exception('ไม่พบข้อมูลผู้รับเลี้ยง');
      }

      // Load sitter's location
      QuerySnapshot locationSnapshot = await _firestore
          .collection('users')
          .doc(widget.sitterId)
          .collection('locations')
          .get();

      setState(() {
        _sitterData = sitterDoc.data() as Map<String, dynamic>;
        if (locationSnapshot.docs.isNotEmpty) {
          _locationData =
              locationSnapshot.docs.first.data() as Map<String, dynamic>;
          _markers.add(
            Marker(
              markerId: MarkerId(widget.sitterId),
              position: LatLng(
                _locationData!['lat'],
                _locationData!['lng'],
              ),
              infoWindow: InfoWindow(
                title: _sitterData!['name'],
                snippet: _locationData!['description'],
              ),
            ),
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  Future<void> _loadReviews() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(ReviewConstants.collectionName)
          .where('sitterId', isEqualTo: widget.sitterId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      final reviews =
          snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();

      // Calculate average rating
      if (snapshot.docs.isNotEmpty) {
        final totalRating = snapshot.docs
            .map((doc) => (doc.get('rating') as num).toDouble())
            .fold<double>(0, (sum, rating) => sum + rating);

        setState(() {
          _reviews = reviews;
          _averageRating = totalRating / snapshot.docs.length;
          _loadingReviews = false;
        });
      } else {
        setState(() {
          _reviews = [];
          _averageRating = 0;
          _loadingReviews = false;
        });
      }
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() => _loadingReviews = false);
    }
  }

  Widget _buildReviewsSection() {
    if (_loadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รีวิวจากลูกค้า',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_reviews.length} รีวิว',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                if (_reviews.isNotEmpty)
                  Row(
                    children: [
                      Text(
                        _averageRating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, color: Colors.amber),
                    ],
                  ),
              ],
            ),
          ),
          if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('ยังไม่มีรีวิว'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reviews.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final review = _reviews[index];
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Row(
                    children: [
                      RatingBarIndicator(
                        rating: review.rating,
                        itemBuilder: (context, _) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        itemCount: 5,
                        itemSize: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(review.timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(review.comment),
                  ),
                );
              },
            ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SitterReviewsPage(),
                ),
              );
            },
            child: const Text('ดูรีวิวทั้งหมด'),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_sitterData == null) {
      return const Scaffold(
        body: Center(child: Text('ไม่พบข้อมูลผู้รับเลี้ยง')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                _sitterData!['photo'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.person, size: 100),
                  );
                },
              ),
              title: Text(_sitterData!['name']),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reviews Section
                  _buildReviewsSection(),
                  const SizedBox(height: 16),

                  // วันที่เลือก
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'วันที่เลือก',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ...widget.targetDates.map((date) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(_dateFormatter.format(date)),
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ข้อมูลการติดต่อ
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ข้อมูลการติดต่อ',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.email),
                            title: Text(_sitterData!['email']),
                          ),
                          if (_sitterData!['phone'] != null)
                            ListTile(
                              leading: const Icon(Icons.phone),
                              title: Text(_sitterData!['phone']),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // แผนที่
                  if (_locationData != null) ...[
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'ตำแหน่งที่อยู่',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          SizedBox(
                            height: 200,
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(
                                  _locationData!['lat'],
                                  _locationData!['lng'],
                                ),
                                zoom: 15,
                              ),
                              markers: _markers,
                              zoomControlsEnabled: false,
                              mapToolbarEnabled: false,
                              myLocationButtonEnabled: false,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(_locationData!['description'] ?? ''),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingScreen(
                    sitterId: widget.sitterId,
                    selectedDates: widget.targetDates,

                    pricePerDay: _sitterData!['pricePerDay'] ??
                        35.0, // Add default price or get from sitter data
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('จองบริการ'),
          ),
        ),
      ),
    );
  }
}
