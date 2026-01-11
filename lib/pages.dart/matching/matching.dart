// lib/pages.dart/matching/matching.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:myproject/Admin/NotificationService.dart';
import 'package:myproject/Local_Noti/NotiClass.dart';
import 'package:myproject/models/booking_model.dart';
import 'dart:math';

import 'package:myproject/pages.dart/sitterscreen/SitterProfileScreen.dart';
import 'package:myproject/services/shared_pref.dart';

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
  // เปลี่ยนจาก DateTime? เป็น List<DateTime> เพื่อรองรับหลายวัน
  final List<DateTime> _selectedDates = [];
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
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && !_selectedDates.contains(picked)) {
      setState(() {
        _selectedDates.add(picked);
        // เรียงลำดับวันที่
        _selectedDates.sort();
      });
    }
  }

  void _removeDate(DateTime date) {
    setState(() {
      _selectedDates.remove(date);
    });
  }

  void _confirmDate() async {
    if (_selectedDates.isNotEmpty) {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเข้าสู่ระบบ')),
        );
        return;
      }

      // Fetch cats marked for sitting
      final catsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cats')
          .where('isForSitting', isEqualTo: true)
          .get();

      List<String> catIds = catsSnapshot.docs.map((doc) => doc.id).toList();

      if (catIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกแมวที่ต้องการฝากเลี้ยง')),
        );
        return;
      }

      widget.onDateSelected(_selectedDates);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchSittersScreen(
            targetDates: _selectedDates,
            catIds: catIds, // Add the required parameter
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'เลือกวันที่ต้องการจ้าง',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade100, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เลือกวันที่ต้องการ',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'คุณสามารถเลือกได้หลายวัน',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: Colors.teal.shade700),
                          const SizedBox(width: 12),
                          Text(
                            'เพิ่มวันที่',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _selectedDates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ยังไม่ได้เลือกวันที่',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _selectedDates.length,
                      itemBuilder: (context, index) {
                        final date = _selectedDates[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.event,
                                color: Colors.teal.shade700,
                              ),
                            ),
                            title: Text(
                              _dateFormatter.format(date),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red.shade400,
                              ),
                              onPressed: () => _removeDate(date),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: _selectedDates.isEmpty ? 0 : 100,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: _selectedDates.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: _confirmDate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'ค้นหาผู้รับเลี้ยง (${_selectedDates.length} วัน)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
  final List<String> catIds;
  final String? bookingRef; // เพิ่ม parameter นี้

  const SearchSittersScreen({
    Key? key,
    required this.targetDates,
    required this.catIds,
    this.bookingRef, // เพิ่ม optional parameter
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

  Future<void> _proceedToSitterSearch() async {
    if (widget.catIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกแมวอย่างน้อย 1 ตัว')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);

      // เก็บ ID ของแมวทั้งหมดที่ถูกเลือก
      final List<String> catIds = widget.catIds;

      // ตรวจสอบว่ามีผู้รับเลี้ยงที่ว่างหรือไม่
      final availableSitters = await _sitterService.findNearestSitters(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        dates: widget.targetDates,
      );

      if (availableSitters.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบผู้รับเลี้ยงที่ว่างในระยะ 5 กม.')),
        );
        return;
      }

      // คำนวณเวลาหมดอายุ 15 นาทีจากเวลาปัจจุบัน
      final DateTime expirationTime = DateTime.now().add(Duration(minutes: 1));

      // สร้างข้อมูลการจอง
      final bookingRequest = {
        'userId': user.uid,
        'catIds': catIds,
        'dates':
            widget.targetDates.map((date) => Timestamp.fromDate(date)).toList(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expirationTime':
            Timestamp.fromDate(expirationTime), // เพิ่มเวลาหมดอายุ 15 นาที
        'sitterId': availableSitters.first['id'], // เลือกผู้รับเลี้ยงคนแรกที่พบ
      };

      // บันทึกข้อมูลลงใน Firestore
      DocumentReference bookingRef = await FirebaseFirestore.instance
          .collection('bookings')
          .add(bookingRequest);

      // แจ้งเตือนผู้รับเลี้ยงว่ามีคำขอใหม่
      NotificationService notificationService = NotificationService();
      await notificationService.sendBookingStatusNotification(
        userId: availableSitters.first['id'], // sitterId
        bookingId: bookingRef.id,
        status: 'pending',
        message: 'คุณมีคำขอรับเลี้ยงแมวใหม่ กรุณาตอบรับภายใน 15 นาที',
      );

      // แจ้งเตือนในแอป (local notification) สำหรับผู้ใช้ปัจจุบัน
      // ค้นหาบริเวณส่งการแจ้งเตือนในแอป
      NotifiationServices().sendCustomNotification(
        title: 'สร้างคำขอสำเร็จ',
        body:
            'คำขอของคุณจะหมดอายุใน 1 นาที (${DateFormat('HH:mm').format(expirationTime)})',
      );

      setState(() => _isLoading = false);

      // แสดงข้อความคำขอจะหมดอายุในอีก 15 นาที
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'คำขอนี้จะหมดอายุในเวลา ${DateFormat('HH:mm').format(expirationTime)}'),
          duration: Duration(seconds: 5),
        ),
      );

      // นำทางไปยังหน้าค้นหาผู้รับเลี้ยง
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchSittersScreen(
            targetDates: widget.targetDates,
            catIds: widget.catIds,
            bookingRef: bookingRef.id, // ส่ง ID ของ booking request ไปด้วย
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
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
        // ต่อจากโค้ดก่อนหน้า...

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

// ตัวอย่างโค้ดในไฟล์ที่สร้างการจอง
  Future<String> createBooking(BookingModel booking) async {
    try {
      // ตั้งเวลาหมดอายุเป็น 15 นาทีจากปัจจุบัน
      DateTime expirationTime = DateTime.now().add(Duration(minutes: 1));

      // เพิ่มบรรทัดนี้เพื่อตรวจสอบว่ามีการตั้งเวลาหมดอายุจริง
      print('การจองนี้จะหมดอายุเมื่อ: $expirationTime');

      final bookingData = {
        ...booking.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        // เพิ่มบรรทัดนี้ให้แน่ใจว่ามีการตั้ง expirationTime
        'expirationTime': Timestamp.fromDate(expirationTime),
      };

      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('bookings')
          .add(bookingData);

      return docRef.id;
    } catch (e) {
      print('Error creating booking: $e');
      throw e;
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ผู้รับเลี้ยงที่ว่าง',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              _getDateRangeText(),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade100, Colors.white],
          ),
        ),
        child: _locationError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _locationError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.refresh),
                        label: const Text('ลองใหม่'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                    ),
                  )
                : _availableSitters.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'ไม่พบผู้รับเลี้ยงที่ว่างในระยะ 5 กม.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _availableSitters.length,
                        itemBuilder: (context, index) {
                          final sitter = _availableSitters[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: InkWell(
                              onTap: () {
                                // พิมพ์ค่า ID ของผู้รับเลี้ยงที่เลือก
                                print('Selected Sitter ID: ${sitter['id']}');

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SitterProfileScreen(
                                      sitterId: sitter['id'],
                                      targetDates: widget.targetDates,
                                      catIds: widget.catIds,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(15),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          sitter['photo'],
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.person,
                                                size: 40,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sitter['name'],
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 16,
                                                color: Colors.red.shade400,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${sitter['distance']} กม.',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (sitter['location'] != null &&
                                              sitter['location']['name'] !=
                                                  null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Text(
                                                sitter['location']['name'],
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
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
                        },
                      ),
      ),
    );
  }
}
