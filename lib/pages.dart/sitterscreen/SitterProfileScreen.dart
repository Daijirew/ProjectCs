import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSitterData();
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
              // TODO: Implement booking functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ระบบจองกำลังพัฒนา')),
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
