import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:myproject/models/checklist_model.dart';
import 'package:myproject/services/checklist_service.dart';

class ChecklistManagementPage extends StatefulWidget {
  const ChecklistManagementPage({Key? key}) : super(key: key);

  @override
  _ChecklistManagementPageState createState() =>
      _ChecklistManagementPageState();
}

class _ChecklistManagementPageState extends State<ChecklistManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChecklistService _checklistService = ChecklistService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _activeBookings = [];
  String? _selectedBookingId;
  Map<String, dynamic>? _selectedBookingInfo;
  List<Map<String, dynamic>> _cats = [];
  List<ChecklistItem> _checklistItems = [];
  String? _selectedCatId;

  @override
  void initState() {
    super.initState();
    _loadActiveBookings();
  }

  // โหลดรายการการจองที่กำลังดำเนินการ
  Future<void> _loadActiveBookings() async {
    setState(() => _isLoading = true);

    try {
      QuerySnapshot bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('status', whereIn: ['confirmed', 'in_progress', 'completed'])
          .orderBy('createdAt', descending: true)
          .limit(50) // จำกัดจำนวนที่โหลด
          .get();

      List<Map<String, dynamic>> bookings = [];

      for (var doc in bookingsSnapshot.docs) {
        Map<String, dynamic> bookingData = doc.data() as Map<String, dynamic>;

        // โหลดข้อมูลผู้ใช้
        String userId = bookingData['userId'] ?? '';
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(userId).get();
        String userName = 'ไม่ระบุชื่อ';
        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          userName = userData['name'] ?? 'ไม่ระบุชื่อ';
        }

        // โหลดข้อมูลผู้รับเลี้ยง
        String sitterId = bookingData['sitterId'] ?? '';
        DocumentSnapshot sitterDoc =
            await _firestore.collection('users').doc(sitterId).get();
        String sitterName = 'ไม่ระบุชื่อ';
        if (sitterDoc.exists) {
          Map<String, dynamic> sitterData =
              sitterDoc.data() as Map<String, dynamic>;
          sitterName = sitterData['name'] ?? 'ไม่ระบุชื่อ';
        }

        // คำนวณวันที่จาก timestamps
        List<DateTime> dateList = [];
        if (bookingData['dates'] != null) {
          List<dynamic> dates = bookingData['dates'];
          dateList = dates
              .map((timestamp) => (timestamp as Timestamp).toDate())
              .toList();
          dateList.sort(); // เรียงลำดับวันที่
        }

        // สร้างข้อมูลสรุปสำหรับแสดง
        bookings.add({
          'id': doc.id,
          'userName': userName,
          'sitterName': sitterName,
          'status': bookingData['status'],
          'dateRange': dateList.isEmpty
              ? 'ไม่ระบุวันที่'
              : '${DateFormat('dd/MM/yyyy').format(dateList.first)} - ${DateFormat('dd/MM/yyyy').format(dateList.last)}',
          'totalPrice': bookingData['totalPrice'],
          'createdAt': bookingData['createdAt'],
          'userId': userId,
          'sitterId': sitterId,
        });
      }

      setState(() {
        _activeBookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading active bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  // โหลดข้อมูลสำหรับการจองที่เลือก
  Future<void> _loadBookingDetails(String bookingId) async {
    setState(() => _isLoading = true);

    try {
      // โหลดข้อมูลแมวสำหรับการจอง
      List<Map<String, dynamic>> cats =
          await _checklistService.getCatsForBooking(bookingId);

      // โหลดเช็คลิสต์สำหรับการจอง
      List<ChecklistItem> checklistItems =
          await _checklistService.getChecklistByBooking(bookingId);

      // หาการจองที่เลือกจากรายการ
      Map<String, dynamic>? selectedBooking = _activeBookings.firstWhere(
        (booking) => booking['id'] == bookingId,
        orElse: () => {},
      );

      setState(() {
        _selectedBookingId = bookingId;
        _selectedBookingInfo = selectedBooking;
        _cats = cats;
        _checklistItems = checklistItems;
        if (cats.isNotEmpty) {
          _selectedCatId = cats.first['id'];
        } else {
          _selectedCatId = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading booking details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('การจัดการเช็คลิสต์'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              if (_selectedBookingId != null) {
                _loadBookingDetails(_selectedBookingId!);
              } else {
                _loadActiveBookings();
              }
            },
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // แสดงรายการการจองด้านซ้าย (30% ของความกว้าง)
                Container(
                  width: MediaQuery.of(context).size.width * 0.3,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: _buildBookingsList(),
                ),

                // แสดงรายละเอียดด้านขวา (70% ของความกว้าง)
                Expanded(
                  child: _selectedBookingId != null
                      ? _buildBookingDetails()
                      : Center(
                          child: Text('เลือกการจองเพื่อดูรายละเอียด'),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildBookingsList() {
    if (_activeBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'ไม่พบรายการจอง',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _activeBookings.length,
      itemBuilder: (context, index) {
        final booking = _activeBookings[index];
        final isSelected = booking['id'] == _selectedBookingId;

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: isSelected ? Colors.deepOrange.shade50 : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? Colors.deepOrange : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () => _loadBookingDetails(booking['id']),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(booking['status'])
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(booking['status']),
                          style: TextStyle(
                            color: _getStatusColor(booking['status']),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Spacer(),
                      Text(
                        '฿${booking['totalPrice']}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'เจ้าของ: ${booking['userName']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ผู้รับเลี้ยง: ${booking['sitterName']}',
                  ),
                  SizedBox(height: 4),
                  Text(
                    booking['dateRange'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookingDetails() {
    if (_selectedBookingInfo == null) {
      return Center(
        child: Text('ไม่พบข้อมูลการจอง'),
      );
    }

    return Column(
      children: [
        // ส่วนหัวแสดงข้อมูลการจอง
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ข้อมูลการจอง',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'รหัสการจอง: ${_selectedBookingId}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_selectedBookingInfo!['status'])
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(_selectedBookingInfo!['status']),
                      style: TextStyle(
                        color: _getStatusColor(_selectedBookingInfo!['status']),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      'เจ้าของแมว',
                      _selectedBookingInfo!['userName'],
                      Icons.person,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoCard(
                      'ผู้รับเลี้ยง',
                      _selectedBookingInfo!['sitterName'],
                      Icons.person_outline,
                      Colors.orange,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoCard(
                      'ช่วงวันที่',
                      _selectedBookingInfo!['dateRange'],
                      Icons.calendar_today,
                      Colors.purple,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoCard(
                      'ราคา',
                      '฿${_selectedBookingInfo!['totalPrice']}',
                      Icons.monetization_on,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ส่วนเลือกแมว
        if (_cats.isNotEmpty) _buildCatSelector(),

        // ส่วนแสดงความคืบหน้า
        if (_selectedCatId != null) _buildProgressSection(),

        // ส่วนแสดงเช็คลิสต์
        Expanded(
          child: _selectedCatId != null
              ? _buildChecklistForCat(_selectedCatId!)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pets,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'ไม่พบข้อมูลแมว',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatSelector() {
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
                  color: isSelected ? Colors.deepOrange : Colors.grey.shade300,
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
    List<ChecklistItem> filteredItems =
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
    List<ChecklistItem> filteredItems =
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
    List<ChecklistItem> completedItems =
        filteredItems.where((item) => item.isCompleted).toList();
    List<ChecklistItem> pendingItems =
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
          ...completedItems.map((item) => _buildChecklistItemCard(item)),
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
          ...pendingItems
              .map((item) => _buildChecklistItemCard(item, enabled: false)),
        ],
      ],
    );
  }

  Widget _buildChecklistItemCard(ChecklistItem item, {bool enabled = true}) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: enabled ? () => _showItemDetails(item) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // ไอคอนสถานะ
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.isCompleted
                      ? Colors.green.shade100
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  color: item.isCompleted ? Colors.green : Colors.grey,
                ),
              ),
              SizedBox(width: 16),

              // รายละเอียดรายการ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: item.isCompleted ? Colors.black : Colors.grey,
                      ),
                    ),
                    if (item.isCompleted &&
                        item.note != null &&
                        item.note!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          item.note!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (item.isCompleted)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'เสร็จเมื่อ: ${DateFormat('dd/MM/yyyy HH:mm').format(item.timestamp)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // แสดงรูปย่อ (ถ้ามี)
              if (item.isCompleted && item.imageUrl != null)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(item.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetails(ChecklistItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.description),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imageUrl != null)
                Container(
                  width: double.infinity,
                  height: 200,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(item.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Text(
                'บันทึกเมื่อ: ${DateFormat('dd/MM/yyyy HH:mm').format(item.timestamp)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 12),
              if (item.note != null && item.note!.isNotEmpty) ...[
                Text(
                  'โน้ต:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(item.note!),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ปิด'),
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
}
