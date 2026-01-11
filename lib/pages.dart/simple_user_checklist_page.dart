import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myproject/models/simple_checklist_model.dart';
import 'package:myproject/services/simple_checklist_service.dart';
import 'package:intl/intl.dart';

class SimpleUserChecklistPage extends StatefulWidget {
  final String bookingId;

  const SimpleUserChecklistPage({
    Key? key,
    required this.bookingId,
  }) : super(key: key);

  @override
  _SimpleUserChecklistPageState createState() =>
      _SimpleUserChecklistPageState();
}

class _SimpleUserChecklistPageState extends State<SimpleUserChecklistPage> {
  final SimpleChecklistService _checklistService = SimpleChecklistService();
  bool _isLoading = true;
  List<SimpleChecklistItem> _checklistItems = [];
  List<Map<String, dynamic>> _cats = [];
  String? _selectedCatId;
  Map<String, dynamic>? _bookingDetails;
  Map<String, dynamic>? _sitterDetails;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ดึงข้อมูลแมวสำหรับการจอง
      List<Map<String, dynamic>> cats =
          await _checklistService.getCatsForBooking(widget.bookingId);

      // ดึงเช็คลิสต์สำหรับการจอง
      List<SimpleChecklistItem> items =
          await _checklistService.getChecklistForBooking(widget.bookingId);

      // ดึงข้อมูลการจอง
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (bookingDoc.exists) {
        Map<String, dynamic> bookingData =
            bookingDoc.data() as Map<String, dynamic>;

        // ดึงข้อมูลผู้รับเลี้ยง
        String sitterId = bookingData['sitterId'] ?? '';
        final sitterDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(sitterId)
            .get();

        Map<String, dynamic>? sitterData =
            sitterDoc.exists ? sitterDoc.data() as Map<String, dynamic> : null;

        setState(() {
          _bookingDetails = bookingData;
          _sitterDetails = sitterData;
        });
      }

      setState(() {
        _cats = cats;
        _checklistItems = items;
        if (cats.isNotEmpty && _selectedCatId == null) {
          _selectedCatId = cats.first['id'];
        }
        _isLoading = false;
      });
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('เกิดข้อผิดพลาดในการโหลดข้อมูล กรุณาลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('รายงานการดูแลแมว'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ส่วนแสดงข้อมูลการจอง
                _buildBookingInfo(),

                // ส่วนเลือกแมว
                _buildCatSelector(),

                // ส่วนแสดงความคืบหน้า
                _buildProgressSection(),

                // ส่วนแสดงเช็คลิสต์
                Expanded(
                  child: _selectedCatId != null
                      ? _buildChecklistForCat(_selectedCatId!)
                      : Center(
                          child: Text('กรุณาเลือกแมว'),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildBookingInfo() {
    if (_bookingDetails == null || _sitterDetails == null) {
      return SizedBox();
    }

    // แปลงวันที่จาก Timestamp เป็น DateTime
    List<DateTime> dates = [];
    if (_bookingDetails!['dates'] != null) {
      dates = (_bookingDetails!['dates'] as List)
          .map((timestamp) => (timestamp as Timestamp).toDate())
          .toList();
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: _sitterDetails!['photo'] != null
                ? NetworkImage(_sitterDetails!['photo'])
                : null,
            child: _sitterDetails!['photo'] == null
                ? Icon(Icons.person, size: 30)
                : null,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'พี่เลี้ยงแมว: ${_sitterDetails!['name'] ?? ''}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (dates.isNotEmpty)
                  Text(
                    'วันที่: ${DateFormat('dd/MM/yyyy').format(dates.first)} - ${DateFormat('dd/MM/yyyy').format(dates.last)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                Text(
                  'สถานะ: ${_getStatusText(_bookingDetails!['status'])}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _getStatusColor(_bookingDetails!['status']),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'confirmed':
        return Colors.blue;
      case 'in_progress':
        return Colors.indigo;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'in_progress':
        return 'กำลังให้บริการ';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  Widget _buildCatSelector() {
    if (_cats.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('ไม่พบข้อมูลแมวสำหรับการจองนี้'),
        ),
      );
    }

    return Container(
      height: 100,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _cats.length,
        itemBuilder: (context, index) {
          final cat = _cats[index];
          final isSelected = cat['id'] == _selectedCatId;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCatId = cat['id'];
              });
            },
            child: Container(
              width: 80,
              margin: EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected ? Colors.orange : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage:
                        cat['imagePath'] != null && cat['imagePath'].isNotEmpty
                            ? NetworkImage(cat['imagePath'])
                            : null,
                    child: cat['imagePath'] == null || cat['imagePath'].isEmpty
                        ? Icon(Icons.pets, color: Colors.grey)
                        : null,
                  ),
                  SizedBox(height: 8),
                  Text(
                    cat['name'] ?? 'แมว',
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressSection() {
    if (_selectedCatId == null) return SizedBox();

    // กรองรายการเฉพาะแมวที่เลือก
    List<SimpleChecklistItem> filteredItems =
        _checklistItems.where((item) => item.catId == _selectedCatId).toList();

    // คำนวณความคืบหน้า
    int totalTasks = filteredItems.length;
    int completedTasks = filteredItems.where((item) => item.isCompleted).length;
    double progressPercentage =
        totalTasks > 0 ? completedTasks / totalTasks : 0;

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ความคืบหน้าการดูแล',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$completedTasks / $totalTasks (${(progressPercentage * 100).toInt()}%)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      progressPercentage == 1.0 ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercentage,
              backgroundColor: Colors.grey[200],
              color: progressPercentage == 1.0 ? Colors.green : Colors.orange,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistForCat(String catId) {
    // กรองรายการเฉพาะแมวที่เลือก
    List<SimpleChecklistItem> filteredItems =
        _checklistItems.where((item) => item.catId == catId).toList();

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.format_list_bulleted,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'ไม่พบรายการเช็คลิสต์สำหรับแมวตัวนี้',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // แยกรายการเป็นที่ทำแล้วกับยังไม่ได้ทำ
    List<SimpleChecklistItem> completedItems =
        filteredItems.where((item) => item.isCompleted).toList();
    List<SimpleChecklistItem> pendingItems =
        filteredItems.where((item) => !item.isCompleted).toList();

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // แสดงรายการที่ทำแล้ว
        if (completedItems.isNotEmpty) ...[
          Text(
            'รายการที่ดำเนินการแล้ว',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          SizedBox(height: 8),
          ...completedItems.map((item) => _buildChecklistItemCard(item, true)),
          SizedBox(height: 24),
        ],

        // แสดงรายการที่ยังไม่ได้ทำ
        if (pendingItems.isNotEmpty) ...[
          Text(
            'รายการที่รอดำเนินการ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          SizedBox(height: 8),
          ...pendingItems.map((item) => _buildChecklistItemCard(item, false)),
        ],
      ],
    );
  }

  Widget _buildChecklistItemCard(SimpleChecklistItem item, bool isCompleted) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // ไอคอนสถานะ
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    isCompleted ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCompleted ? Icons.check_circle : Icons.circle_outlined,
                color: isCompleted ? Colors.green : Colors.grey,
              ),
            ),
            SizedBox(width: 16),

            // รายละเอียดรายการ
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.task,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.black : Colors.grey,
                    ),
                  ),
                  if (isCompleted && item.completedAt != null)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'เสร็จเมื่อ: ${DateFormat('dd/MM/yyyy HH:mm').format(item.completedAt!)}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
