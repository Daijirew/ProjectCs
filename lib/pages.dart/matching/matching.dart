import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math';

class SelectTargetDateScreen extends StatefulWidget {
  final Function(List<DateTime>) onDateSelected;

  const SelectTargetDateScreen({
    Key? key,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<SelectTargetDateScreen> createState() => _SelectTargetDateScreenState();
}

class _SelectTargetDateScreenState extends State<SelectTargetDateScreen> {
  final List<DateTime> _selectedDate = [];
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'th');

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: const Locale('th', 'TH'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && !_selectedDate.contains(picked)) {
      setState(() {
        _selectedDate.add(picked);
        _selectedDate.sort();
      });
    }
  }

  void _removeDate(DateTime date) {
    setState(() {
      _selectedDate.remove(date);
    });
  }

  void _confirmDate() {
    if (_selectedDate.isNotEmpty) {
      // If you need just one date, send the first selected date
      widget.onDateSelected(_selectedDate);

      // OR if the parent widget expects a list of dates
      // widget.onDateSelected(_selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกวันที่ต้องการจ้าง'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'วันที่ต้องการจ้าง',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'เลือกวันที่',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedDate.isNotEmpty) ...[
              Text(
                'วันที่เลือก:',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _selectedDate.length,
                  itemBuilder: (context, index) {
                    final date = _selectedDate[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(_dateFormatter.format(date)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          color: Colors.red,
                          onPressed: () => _removeDate(date),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _confirmDate();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchSittersScreen(
                        targetDates: _selectedDate,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('ค้นหาผู้รับเลี้ยงที่ว่าง'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SitterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> findNearestSitters({
    required double latitude,
    required double longitude,
    required List<DateTime> dates,
    double radiusInKm = 5,
  }) async {
    try {
      QuerySnapshot sitterSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .get();

      List<Map<String, dynamic>> nearestSitters = [];

      for (var doc in sitterSnapshot.docs) {
        // Check if sitter is available for all selected dates
        bool isAvailableForAllDates = true;
        for (var date in dates) {
          bool isAvailable = await _checkAvailability(doc.id, date);
          if (!isAvailable) {
            isAvailableForAllDates = false;
            break;
          }
        }

        if (!isAvailableForAllDates) continue;

        var locationData = await _getLocationData(doc.id);
        if (locationData != null) {
          double sitterLat = locationData['lat'];
          double sitterLng = locationData['lng'];

          double distance = _calculateDistance(
            latitude,
            longitude,
            sitterLat,
            sitterLng,
          );

          if (distance <= radiusInKm) {
            nearestSitters.add({
              'id': doc.id,
              'name': doc['name'],
              'email': doc['email'],
              'photo': doc['photo'],
              'username': doc['username'],
              'location': locationData,
              'distance': distance.toStringAsFixed(1),
            });
          }
        }
      }

      nearestSitters.sort((a, b) =>
          double.parse(a['distance']).compareTo(double.parse(b['distance'])));

      return nearestSitters;
    } catch (e) {
      throw Exception('ไม่สามารถดึงข้อมูลผู้รับเลี้ยงแมวได้: $e');
    }
  }

  Future<bool> _checkAvailability(String sitterId, DateTime date) async {
    try {
      DateTime dateOnly = DateTime(date.year, date.month, date.day);
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(sitterId).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        if (userData.containsKey('availableDates')) {
          List<dynamic> availableDates = userData['availableDates'];

          for (var availableDate in availableDates) {
            if (availableDate is Timestamp) {
              DateTime available = availableDate.toDate();
              if (available.year == dateOnly.year &&
                  available.month == dateOnly.month &&
                  available.day == dateOnly.day) {
                return true;
              }
            }
          }
        }
      }
      return false;
    } catch (e) {
      print('Error checking availability: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _getLocationData(String userId) async {
    try {
      QuerySnapshot locationSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('locations')
          .get();

      if (locationSnapshot.docs.isNotEmpty) {
        var locationDoc = locationSnapshot.docs.first;
        return {
          'description': locationDoc['description'],
          'lat': locationDoc['lat'],
          'lng': locationDoc['lng'],
          'name': locationDoc['name'],
        };
      }
      return null;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }
}

class SearchSittersScreen extends StatefulWidget {
  final List<DateTime> targetDates;

  const SearchSittersScreen({
    Key? key,
    required this.targetDates,
  }) : super(key: key);

  @override
  State<SearchSittersScreen> createState() => _SearchSittersScreenState();
}

class _SearchSittersScreenState extends State<SearchSittersScreen> {
  final SitterService _sitterService = SitterService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableSitters = [];
  Position? _currentPosition;
  String? _locationError;
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'th');

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled.';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permissions are denied';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permissions are permanently denied.';
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _locationError = null;
      });

      await _searchAvailableSitters();
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchAvailableSitters() async {
    if (_currentPosition == null) return;

    try {
      setState(() => _isLoading = true);

      _availableSitters = await _sitterService.findNearestSitters(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        dates: widget.targetDates,
      );

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  String _getDateRangeText() {
    if (widget.targetDates.length == 1) {
      return 'วันที่ ${_dateFormatter.format(widget.targetDates.first)}';
    } else {
      return '${_dateFormatter.format(widget.targetDates.first)} - ${_dateFormatter.format(widget.targetDates.last)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ผู้รับเลี้ยงที่ว่าง'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _getDateRangeText(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
      body: _locationError != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_locationError!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _getCurrentLocation,
                    child: const Text('ลองใหม่'),
                  ),
                ],
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _availableSitters.isEmpty
                  ? const Center(
                      child: Text('ไม่พบผู้รับเลี้ยงที่ว่างในระยะ 5 กม.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _availableSitters.length,
                      itemBuilder: (context, index) {
                        final sitter = _availableSitters[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(sitter['photo']),
                              onBackgroundImageError: (e, s) {
                                print('Error loading image: $e');
                              },
                              child: const Icon(Icons.person),
                            ),
                            title: Text(sitter['name']),
                            subtitle: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text('${sitter['distance']} กม.'),
                              ],
                            ),
                            onTap: () {
                              // TODO: Navigate to sitter detail screen
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
