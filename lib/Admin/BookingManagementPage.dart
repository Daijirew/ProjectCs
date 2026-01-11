import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:myproject/Admin/BookingDetailPage.dart';

class BookingManagementPage extends StatefulWidget {
  const BookingManagementPage({Key? key}) : super(key: key);

  @override
  _BookingManagementPageState createState() => _BookingManagementPageState();
}

class _BookingManagementPageState extends State<BookingManagementPage> {
  bool _isLoading = false;
  String _selectedStatus = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // เพิ่มแคชข้อมูลผู้ใช้เพื่อป้องกันการโหลดซ้ำ
  Map<String, Map<String, dynamic>> _usersCache = {};

  @override
  void initState() {
    super.initState();
    // กำหนดค่าเริ่มต้นให้วันที่
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(Duration(days: 30));
  }

  // ฟังก์ชันดึงข้อมูลผู้ใช้โดยใช้แคช
  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    // ถ้ามีข้อมูลในแคชแล้ว ให้ใช้จากแคชเลย
    if (_usersCache.containsKey(userId)) {
      return _usersCache[userId];
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        // เก็บข้อมูลในแคช
        _usersCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      print('Error loading user data: $e');
    }

    return null;
  }

  String _formatDates(List<dynamic> dates) {
    if (dates.isEmpty) return 'ไม่ระบุวันที่';

    final formatter = DateFormat('dd/MM/yyyy');
    final List<DateTime> dateTimes = dates
        .map((date) => date is Timestamp ? date.toDate() : DateTime.now())
        .toList();

    dateTimes.sort();

    if (dateTimes.length > 1) {
      return '${formatter.format(dateTimes.first)} - ${formatter.format(dateTimes.last)}';
    }
    return formatter.format(dateTimes.first);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'in_progress':
        return 'กำลังดูแล';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ทั้งหมด';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.pets;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepOrange,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // อัพเดทสถานะการจอง
  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    try {
      // แสดง loading
      setState(() {
        _isLoading = true;
      });

      // อัพเดทสถานะการจอง
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // แสดงข้อความสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัพเดทสถานะสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating booking status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการการจอง'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
            tooltip: 'เลือกช่วงเวลา',
          ),
        ],
      ),
      body: Column(
        children: [
          // แสดงช่วงเวลาที่เลือก
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepOrange.shade50,
            child: Row(
              children: [
                const Icon(Icons.date_range, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Text(
                  'ช่วงเวลา: ${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('เปลี่ยน'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // ช่องค้นหา
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาด้วยชื่อหรือรหัสการจอง',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepOrange, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // แท็บสถานะ
          Container(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildStatusTab('all', 'ทั้งหมด', Icons.all_inclusive),
                _buildStatusTab('pending', 'รอยืนยัน', Icons.hourglass_empty),
                _buildStatusTab('confirmed', 'ยืนยันแล้ว', Icons.check_circle),
                _buildStatusTab('in_progress', 'กำลังดูแล', Icons.pets),
                _buildStatusTab('completed', 'เสร็จสิ้น', Icons.done_all),
                _buildStatusTab('cancelled', 'ยกเลิก', Icons.cancel),
              ],
            ),
          ),

          // รายการการจอง
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: Colors.deepOrange))
                : _buildBookingsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String status, String label, IconData icon) {
    bool isSelected = _selectedStatus == status;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStatus = status;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepOrange : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildBookingsQuery(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: Colors.deepOrange));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  'ไม่พบข้อมูลการจอง',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // กรองข้อมูลตามคำค้นหา
        var filteredDocs = snapshot.data!.docs;
        if (_searchQuery.isNotEmpty) {
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final bookingId = doc.id.toLowerCase();

            // ค้นหาจากรหัสการจอง
            if (bookingId.contains(_searchQuery.toLowerCase())) {
              return true;
            }

            // ค้นหาจากชื่อผู้ใช้หรือพี่เลี้ยง (ถ้ามีข้อมูล)
            if (data.containsKey('userName') &&
                data['userName'] != null &&
                data['userName']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase())) {
              return true;
            }

            if (data.containsKey('sitterName') &&
                data['sitterName'] != null &&
                data['sitterName']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase())) {
              return true;
            }

            return false;
          }).toList();
        }

        return filteredDocs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'ไม่พบข้อมูลที่ตรงกับการค้นหา',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: filteredDocs.length,
                padding: EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final bookingData = doc.data() as Map<String, dynamic>;

                  // ใช้ Widget ที่สร้างใหม่สำหรับแสดงรายการการจอง
                  return BookingItemWidget(
                    bookingData: bookingData,
                    bookingId: doc.id,
                    onStatusUpdate: _updateBookingStatus,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingDetailPage(
                            bookingId: doc.id,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
      },
    );
  }

  // แก้ไขฟังก์ชัน _buildBookingsQuery() หรือฟังก์ชันที่เกี่ยวข้อง
  Stream<QuerySnapshot> _buildBookingsQuery() {
    Query query = FirebaseFirestore.instance.collection('bookings');

    if (_selectedStatus != 'all') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots();
  }

  Widget _buildBookingDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.deepOrange),
        SizedBox(width: 4),
        Text(
          '$label ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// สร้าง Widget ใหม่สำหรับแสดงรายการการจอง
class BookingItemWidget extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final String bookingId;
  final Function(String, String) onStatusUpdate;
  final VoidCallback onTap;

  const BookingItemWidget({
    Key? key,
    required this.bookingData,
    required this.bookingId,
    required this.onStatusUpdate,
    required this.onTap,
  }) : super(key: key);

  @override
  _BookingItemWidgetState createState() => _BookingItemWidgetState();
}

class _BookingItemWidgetState extends State<BookingItemWidget> {
  String _userName = 'ไม่พบข้อมูลผู้ใช้'; // เปลี่ยนค่าเริ่มต้น
  String _sitterName = 'ไม่พบข้อมูลพี่เลี้ยง'; // เปลี่ยนค่าเริ่มต้น

  @override
  void initState() {
    super.initState();
    // เรียกโหลดข้อมูลทันทีที่สร้าง Widget
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // เพิ่ม print เพื่อดีบั๊ก
    print('Loading user data for booking ${widget.bookingId}');

    try {
      // ตรวจสอบว่ามี userId หรือไม่
      if (widget.bookingData.containsKey('userId') &&
          widget.bookingData['userId'] != null) {
        String userId = widget.bookingData['userId'];
        print('User ID: $userId');

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        print('User doc exists: ${userDoc.exists}');

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          print('User name: ${userData['name']}');

          setState(() {
            _userName = userData['name'] ?? 'ไม่ระบุชื่อ';
          });
        }
      } else {
        print('No userId in booking data');
      }

      // ตรวจสอบว่ามี sitterId หรือไม่
      if (widget.bookingData.containsKey('sitterId') &&
          widget.bookingData['sitterId'] != null) {
        String sitterId = widget.bookingData['sitterId'];
        print('Sitter ID: $sitterId');

        DocumentSnapshot sitterDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(sitterId)
            .get();

        print('Sitter doc exists: ${sitterDoc.exists}');

        if (sitterDoc.exists) {
          Map<String, dynamic> sitterData =
              sitterDoc.data() as Map<String, dynamic>;
          print('Sitter name: ${sitterData['name']}');

          setState(() {
            _sitterName = sitterData['name'] ?? 'ไม่ระบุชื่อ';
          });
        }
      } else {
        print('No sitterId in booking data');
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // ส่วนของโค้ดที่เหลือยังคงเหมือนเดิม
  // ...

  String _formatDates(List<dynamic> dates) {
    if (dates.isEmpty) return 'ไม่ระบุวันที่';

    final formatter = DateFormat('dd/MM/yyyy');
    final List<DateTime> dateTimes = dates
        .map((date) => date is Timestamp ? date.toDate() : DateTime.now())
        .toList();

    dateTimes.sort();

    if (dateTimes.length > 1) {
      return '${formatter.format(dateTimes.first)} - ${formatter.format(dateTimes.last)}';
    }
    return formatter.format(dateTimes.first);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'in_progress':
        return 'กำลังดูแล';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'กำลังดำเนินงาน';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.pets;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Widget _buildBookingDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.deepOrange),
        SizedBox(width: 4),
        Text(
          '$label ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.bookingData['status'] ?? 'pending';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'รหัส: ${widget.bookingId.substring(0, 8)}...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getStatusText(status),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            if (widget.bookingData['totalPrice'] != null)
                              Text(
                                '฿${widget.bookingData['totalPrice']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.green.shade700,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.bookingData['createdAt'] != null)
                        Text(
                          DateFormat('dd/MM/yyyy').format(
                              (widget.bookingData['createdAt'] as Timestamp)
                                  .toDate()),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      SizedBox(height: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ],
              ),
              Divider(height: 24),
              _buildBookingDetailRow(
                'วันที่ฝากเลี้ยง:',
                widget.bookingData['dates'] != null
                    ? _formatDates(widget.bookingData['dates'])
                    : 'ไม่ระบุ',
                Icons.calendar_month,
              ),
              SizedBox(height: 8),
              _buildBookingDetailRow('ผู้จอง:', _userName, Icons.person),
              SizedBox(height: 8),
              _buildBookingDetailRow('พี่เลี้ยง:', _sitterName, Icons.pets),

              // แสดงปุ่มยืนยันสำหรับการจองที่รอการยืนยันเท่านั้น
              if (status == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => widget.onStatusUpdate(
                            widget.bookingId, 'cancelled'),
                        child: Text('ยกเลิก'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => widget.onStatusUpdate(
                            widget.bookingId, 'confirmed'),
                        child: Text('ยืนยัน'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
