import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myproject/pages.dart/matching/matching.dart';

class FindSitterScreen extends StatefulWidget {
  @override
  _FindSitterScreenState createState() => _FindSitterScreenState();
}

class _FindSitterScreenState extends State<FindSitterScreen> {
  List<Map<String, dynamic>> _sitters = [];
  bool _isLoading = true;
  String? _error;
  Position? _currentPosition;

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
          _error = 'Location services are disabled.';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Location permissions are denied';
            _isLoading = false;
          });
          return;
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      _loadNearbySitters();
    } catch (e) {
      setState(() {
        _error = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNearbySitters() async {
    try {
      if (_currentPosition != null) {
        //  final sitters = await _sitterService.findNearestSitters(
        // latitude: _currentPosition!.latitude,
        //  longitude: _currentPosition!.longitude,
        //  date: DateTime.now(), // Add the missing date parameter
        // );
        setState(() {
          //    _sitters = sitters;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading sitters: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ค้นหาผู้รับเลี้ยงแมว'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _getCurrentLocation();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isLoading = true;
                });
                _getCurrentLocation();
              },
              child: Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_sitters.isEmpty) {
      return Center(
        child: Text('ไม่พบผู้รับเลี้ยงแมวในบริเวณใกล้เคียง'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadNearbySitters(),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _sitters.length,
        itemBuilder: (context, index) {
          final sitter = _sitters[index];
          return Card(
            margin: EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(sitter['photo']),
              ),
              title: Text(sitter['name']),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sitter['location']['name']),
                  Text('ระยะทาง: ${sitter['distance']} กม.'),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  // TODO: Implement contact/booking functionality
                  print('Contact sitter: ${sitter['id']}');
                },
                child: Text('ติดต่อ'),
              ),
            ),
          );
        },
      ),
    );
  }
}
