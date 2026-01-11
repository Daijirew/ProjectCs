import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart'; // เพิ่ม import สำหรับ Geolocator

class Location {
  final String id;
  final double lat;
  final double lng;
  final String name;
  final String? description;

  Location({
    required this.id,
    required this.lat,
    required this.lng,
    required this.name,
    this.description,
  });

  factory Location.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Location(
      id: doc.id,
      lat: data['lat'],
      lng: data['lng'],
      name: data['name'],
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'name': name,
      'description': description,
    };
  }
}

class LocationMapPage extends StatefulWidget {
  @override
  _LocationMapPageState createState() => _LocationMapPageState();
}

class _LocationMapPageState extends State<LocationMapPage> {
  late GoogleMapController _mapController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Location> _locations = [];
  Set<Marker> _markers = {};
  bool _isSearching = false;
  bool _isLoadingLocation = false; // เพิ่มตัวแปรเพื่อติดตามสถานะการโหลดตำแหน่ง
  Position? _currentPosition; // เพิ่มตัวแปรเก็บตำแหน่งปัจจุบัน

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _getCurrentLocation(); // เรียกฟังก์ชันดึงตำแหน่งปัจจุบันเมื่อเริ่มต้น
  }

  // เพิ่มฟังก์ชันสำหรับดึงตำแหน่งปัจจุบัน
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // ตรวจสอบว่าเปิดใช้งาน Location Service หรือไม่
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('กรุณาเปิดใช้งานบริการระบุตำแหน่ง')),
        );
        return;
      }

      // ตรวจสอบสิทธิ์การเข้าถึงตำแหน่ง
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'ไม่สามารถเข้าถึงตำแหน่งได้ กรุณาเปิดสิทธิ์ในการตั้งค่า')),
        );
        return;
      }

      // ดึงตำแหน่งปัจจุบัน
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      // เลื่อนแผนที่ไปยังตำแหน่งปัจจุบัน
      if (_mapController != null && _currentPosition != null) {
        _moveToCurrentPosition();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการดึงตำแหน่ง: $e')),
      );
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  // เพิ่มฟังก์ชันสำหรับการเลื่อนแผนที่ไปยังตำแหน่งปัจจุบัน
  void _moveToCurrentPosition() {
    if (_currentPosition != null) {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _fetchLocations() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('locations')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _locations =
            snapshot.docs.map((doc) => Location.fromFirestore(doc)).toList();
        _markers = _locations
            .map((loc) => Marker(
                  markerId: MarkerId(loc.id),
                  position: LatLng(loc.lat, loc.lng),
                  infoWindow: InfoWindow(
                    title: loc.name,
                    snippet: loc.description,
                  ),
                ))
            .toSet();
      });
    });
  }

  Future<void> _searchLocation() async {
    String searchQuery = _searchController.text.trim();
    if (searchQuery.isEmpty) return;

    try {
      setState(() => _isSearching = true);

      // ค้นหาพิกัดจากที่อยู่
      List<Location> locations = [];
      List<Location> foundLocations =
          await locationFromAddress(searchQuery).then((locations) => locations
              .map((location) => Location(
                    id: '',
                    name: searchQuery,
                    description: searchQuery,
                    lat: location.latitude,
                    lng: location.longitude,
                  ))
              .toList());

      locations.addAll(foundLocations);

      if (locations.isNotEmpty) {
        Location firstLocation = locations.first;

        // เลื่อนแผนที่ไปยังตำแหน่งที่พบ
        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(firstLocation.lat, firstLocation.lng),
            15,
          ),
        );

        // แสดงกล่องถามว่าต้องการบันทึกหรือไม่
        bool? shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Location Found'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: $searchQuery'),
                Text('Latitude: ${firstLocation.lat}'),
                Text('Longitude: ${firstLocation.lng}'),
                Text('Would you like to save this location?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Yes'),
              ),
            ],
          ),
        );

        if (shouldSave == true) {
          _nameController.text = searchQuery;
          _descController.text = searchQuery;
          _addOrUpdateLocation(
            LatLng(firstLocation.lat, firstLocation.lng),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No locations found for "$searchQuery"')),
        );
      }
    } catch (e) {
      print('Search error: $e'); // เพิ่ม log เพื่อดู error ที่เกิดขึ้น
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching location: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _addOrUpdateLocation(LatLng position) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add/Update Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Location Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                hintText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _nameController.clear();
              _descController.clear();
              Navigator.pop(context);
            },
            child: Text('Cancel'),
          ),
          TextButton(
            child: Text('Save'),
            onPressed: () async {
              String locationName = _nameController.text.trim();
              if (locationName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a location name')));
                return;
              }

              try {
                QuerySnapshot existingDocs = await _firestore
                    .collection('users')
                    .doc(currentUser.uid)
                    .collection('locations')
                    .where('name', isEqualTo: locationName)
                    .get();

                Map<String, dynamic> locationData = {
                  'lat': position.latitude,
                  'lng': position.longitude,
                  'name': locationName,
                  'description': _descController.text.trim(),
                };

                if (existingDocs.docs.isNotEmpty) {
                  await _firestore
                      .collection('users')
                      .doc(currentUser.uid)
                      .collection('locations')
                      .doc(existingDocs.docs.first.id)
                      .update(locationData);

                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Location updated successfully')));
                } else {
                  await _firestore
                      .collection('users')
                      .doc(currentUser.uid)
                      .collection('locations')
                      .add(locationData);

                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Location added successfully')));
                }

                _nameController.clear();
                _descController.clear();
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error saving location: ${e.toString()}')));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLocation(Location location) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Location'),
        content: Text('Are you sure you want to delete "${location.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('locations')
            .doc(location.id)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location deleted successfully')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error deleting location: ${e.toString()}')));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Location Mapper'),
        elevation: 2,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: LatLng(13.7563, 100.5018), // Bangkok
              zoom: 10,
            ),
            markers: _markers,
            onTap: _addOrUpdateLocation,
            myLocationEnabled: true, // เปิดใช้งานปุ่มแสดงตำแหน่งปัจจุบัน
            myLocationButtonEnabled:
                false, // ปิดปุ่มดีฟอลต์เพื่อใช้ปุ่มที่เราสร้างเอง
            mapToolbarEnabled: true,
            zoomControlsEnabled: true,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search location...',
                          border: InputBorder.none,
                          icon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _searchLocation(),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      icon: _isSearching
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.search),
                      onPressed: _isSearching ? null : _searchLocation,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // เพิ่มปุ่มสำหรับไปยังตำแหน่งปัจจุบัน
          Positioned(
            right: 16,
            bottom:
                _locations.isNotEmpty ? 140 : 16, // ปรับตำแหน่งตามความเหมาะสม
            child: FloatingActionButton(
              heroTag: "btn_my_location",
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              backgroundColor: Colors.white,
              child: _isLoadingLocation
                  ? CircularProgressIndicator()
                  : Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
          if (_locations.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 120,
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _locations.length,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (context, index) {
                    Location loc = _locations[index];
                    return Card(
                      margin: EdgeInsets.only(right: 8),
                      elevation: 2,
                      child: Container(
                        width: 200,
                        padding: EdgeInsets.all(8),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  loc.description ?? '',
                                  style: TextStyle(fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Spacer(),
                                // เพิ่มปุ่มไปยังตำแหน่งที่บันทึกไว้
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Lat: ${loc.lat.toStringAsFixed(4)}\nLng: ${loc.lng.toStringAsFixed(4)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.navigation,
                                          color: Colors.blue),
                                      onPressed: () {
                                        _mapController.animateCamera(
                                          CameraUpdate.newLatLngZoom(
                                            LatLng(loc.lat, loc.lng),
                                            15,
                                          ),
                                        );
                                      },
                                      tooltip: 'Navigate to location',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Positioned(
                              top: -8,
                              right: -8,
                              child: IconButton(
                                icon: Icon(Icons.close, color: Colors.red),
                                onPressed: () => _deleteLocation(loc),
                                tooltip: 'Delete location',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
