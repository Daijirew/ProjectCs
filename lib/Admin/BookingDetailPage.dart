import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:myproject/Admin/NotificationService.dart';
import 'package:myproject/services/checklist_service.dart'; // เปลี่ยนเป็น ChecklistService
import 'package:url_launcher/url_launcher.dart';
import 'package:myproject/models/checklist_model.dart';

class BookingDetailPage extends StatefulWidget {
  final String bookingId;

  BookingDetailPage({Key? key, required this.bookingId}) : super(key: key);

  @override
  _BookingDetailPageState createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _sitterData;
  List<Map<String, dynamic>> _catsList = [];
  List<ChecklistItem> _checklistItems = [];
  String? _selectedCatId;
  final NotificationService _notificationService = NotificationService();
  TextEditingController _messageController = TextEditingController();
  final ChecklistService _checklistService =
      ChecklistService(); // ใช้ ChecklistService

  @override
  void initState() {
    super.initState();
    _loadBookingData();
  }

// เพิ่มเมธอดสำหรับแสดงรูปภาพ
  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('รูปภาพ'),
              leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              automaticallyImplyLeading: false,
            ),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBooking() async {
    try {
      bool confirmDelete = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('ยืนยันการลบการจอง'),
          content: Text(
              'คุณต้องการลบการจองนี้หรือไม่? การดำเนินการนี้ไม่สามารถยกเลิกได้'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('ลบการจอง'),
            ),
          ],
        ),
      );

      if (confirmDelete != true) return;

      setState(() => _isLoading = true);

      // ลบการจอง
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .delete();

      // ส่งการแจ้งเตือนไปยังผู้ใช้
      if (_bookingData != null && _bookingData!['userId'] != null) {
        await _notificationService.sendBookingStatusNotification(
          userId: _bookingData!['userId'],
          bookingId: widget.bookingId,
          status: 'deleted',
          message: 'การจองของคุณถูกลบโดยผู้ดูแลระบบ',
        );
      }

      // ส่งการแจ้งเตือนไปยังพี่เลี้ยง
      if (_bookingData != null && _bookingData!['sitterId'] != null) {
        await _notificationService.sendBookingStatusNotification(
          userId: _bookingData!['sitterId'],
          bookingId: widget.bookingId,
          status: 'deleted',
          message: 'การจองที่คุณรับได้ถูกลบโดยผู้ดูแลระบบ',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบการจองเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );

      // กลับไปหน้าก่อนหน้า
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error deleting booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการลบการจอง: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadBookingData() async {
    try {
      setState(() => _isLoading = true);

      // ดึงข้อมูลการจอง
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('ไม่พบข้อมูลการจอง');
      }

      _bookingData = bookingDoc.data() as Map<String, dynamic>;

      // ดึงข้อมูลผู้ใช้
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_bookingData!['userId'])
          .get();

      if (userDoc.exists) {
        _userData = userDoc.data() as Map<String, dynamic>;
      }

      // ดึงข้อมูลพี่เลี้ยง
      final sitterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_bookingData!['sitterId'])
          .get();

      if (sitterDoc.exists) {
        _sitterData = sitterDoc.data() as Map<String, dynamic>;
      }

      // ดึงข้อมูลแมว
      if (_bookingData!.containsKey('catIds')) {
        final catIds = List<String>.from(_bookingData!['catIds']);
        _catsList = [];

        for (var catId in catIds) {
          final catDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_bookingData!['userId'])
              .collection('cats')
              .doc(catId)
              .get();

          if (catDoc.exists) {
            Map<String, dynamic> catData =
                catDoc.data() as Map<String, dynamic>;
            catData['id'] = catDoc.id;
            _catsList.add(catData);
          }
        }
      }

      // ดึงข้อมูลเช็คลิสต์
      List<ChecklistItem> checklistItems =
          await _checklistService.getChecklistByBooking(widget.bookingId);

      setState(() {
        _checklistItems = checklistItems;
        // ถ้ามีแมว ให้เลือกแมวตัวแรก
        if (_catsList.isNotEmpty && _selectedCatId == null) {
          _selectedCatId = _catsList.first['id'];
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading booking data: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  Future<void> _updateBookingStatus(String newStatus) async {
    try {
      setState(() => _isLoading = true);

      String adminMessage = _messageController.text.trim().isNotEmpty
          ? _messageController.text.trim()
          : _getDefaultMessageForStatus(newStatus);

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'adminMessage': adminMessage,
      });

      // ส่งการแจ้งเตือนไปยังผู้ใช้
      await _notificationService.sendBookingStatusNotification(
        userId: _bookingData!['userId'],
        bookingId: widget.bookingId,
        status: newStatus,
        message: adminMessage,
      );

      // ส่งการแจ้งเตือนไปยังพี่เลี้ยง
      await _notificationService.sendBookingStatusNotification(
        userId: _bookingData!['sitterId'],
        bookingId: widget.bookingId,
        status: newStatus,
        message: adminMessage,
      );

      // รีเซ็ตข้อความ
      _messageController.clear();

      // โหลดข้อมูลใหม่
      _loadBookingData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัพเดทสถานะสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // แสดงหน้าต่างสำหรับป้อนข้อความเพิ่มเติม
  Future<void> _showMessageDialog(String newStatus) async {
    _messageController.text = _getDefaultMessageForStatus(newStatus);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ข้อความแจ้งเตือน'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('กรุณาระบุข้อความที่จะส่งให้ผู้ใช้และพี่เลี้ยง:'),
                SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'ข้อความแจ้งเตือน',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('ยืนยัน'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getStatusColor(newStatus),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _updateBookingStatus(newStatus);
              },
            ),
          ],
        );
      },
    );
  }

  String _getDefaultMessageForStatus(String status) {
    switch (status) {
      case 'confirmed':
        return 'การจองของคุณได้รับการยืนยันแล้ว กรุณาติดต่อพี่เลี้ยงเพื่อนัดส่งแมว';
      case 'in_progress':
        return 'แมวของคุณกำลังได้รับการดูแลโดยพี่เลี้ยง';
      case 'completed':
        return 'การบริการเสร็จสิ้น ขอบคุณที่ใช้บริการ';
      case 'cancelled':
        return 'การจองได้ถูกยกเลิก';
      default:
        return '';
    }
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
        return 'กำลังดำเนินการ';
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'ไม่ระบุ';
    return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
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

  // เปิดแอปโทรศัพท์เพื่อโทรหาผู้ใช้หรือพี่เลี้ยง
  Future<void> _callPhone(String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่พบหมายเลขโทรศัพท์')),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถโทรออกได้')),
      );
    }
  }

  // เปิดแอปส่งข้อความเพื่อส่ง SMS
  Future<void> _sendSMS(String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่พบหมายเลขโทรศัพท์')),
      );
      return;
    }

    final Uri smsUri = Uri(scheme: 'sms', path: phone);
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถส่งข้อความได้')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดการจอง'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadBookingData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookingData == null
              ? const Center(child: Text('ไม่พบข้อมูลการจอง'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 16),
                      _buildUserInfo(),
                      const SizedBox(height: 16),
                      _buildSitterInfo(),
                      const SizedBox(height: 16),
                      _buildBookingDetails(),
                      const SizedBox(height: 16),
                      _buildCatsList(),
                      const SizedBox(height: 16),
                      // เพิ่มส่วนเช็คลิสต์ตรงนี้
                      _buildChecklistSection(),
                      const SizedBox(height: 16),
                      _buildAdminActions(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusCard() {
    final status = _bookingData!['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getStatusIcon(status),
                color: statusColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สถานะ: ${_getStatusText(status)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (_bookingData!.containsKey('createdAt'))
                    Text(
                      'วันที่จอง: ${_formatTimestamp(_bookingData!['createdAt'])}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  if (_bookingData!.containsKey('updatedAt'))
                    Text(
                      'อัพเดทล่าสุด: ${_formatTimestamp(_bookingData!['updatedAt'])}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildUserInfo() {
    if (_userData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('ไม่พบข้อมูลผู้ใช้'),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'ข้อมูลผู้จอง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: _userData!['photo'] != null &&
                          _userData!['photo'].toString().isNotEmpty &&
                          _userData!['photo'] != 'images/User.png'
                      ? NetworkImage(_userData!['photo'])
                      : null,
                  child: (_userData!['photo'] == null ||
                          _userData!['photo'].toString().isEmpty ||
                          _userData!['photo'] == 'images/User.png')
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userData!['name'] ?? 'ไม่ระบุชื่อ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_userData!['email'] != null)
                        Text(
                          _userData!['email'],
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      if (_userData!['phone'] != null)
                        Row(
                          children: [
                            Text(
                              _userData!['phone'],
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () => _callPhone(_userData!['phone']),
                              child: Icon(Icons.call,
                                  color: Colors.green, size: 20),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () => _sendSMS(_userData!['phone']),
                              child: Icon(Icons.message,
                                  color: Colors.blue, size: 20),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSitterInfo() {
    if (_sitterData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('ไม่พบข้อมูลพี่เลี้ยง'),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pets, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'ข้อมูลพี่เลี้ยง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: _sitterData!['photo'] != null &&
                          _sitterData!['photo'].toString().isNotEmpty &&
                          _sitterData!['photo'] != 'images/User.png'
                      ? NetworkImage(_sitterData!['photo'])
                      : null,
                  child: (_sitterData!['photo'] == null ||
                          _sitterData!['photo'].toString().isEmpty ||
                          _sitterData!['photo'] == 'images/User.png')
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sitterData!['name'] ?? 'ไม่ระบุชื่อ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_sitterData!['email'] != null)
                        Text(
                          _sitterData!['email'],
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      if (_sitterData!['phone'] != null)
                        Row(
                          children: [
                            Text(
                              _sitterData!['phone'],
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () => _callPhone(_sitterData!['phone']),
                              child: Icon(Icons.call,
                                  color: Colors.green, size: 20),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () => _sendSMS(_sitterData!['phone']),
                              child: Icon(Icons.message,
                                  color: Colors.blue, size: 20),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingDetails() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'รายละเอียดการจอง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'รหัสการจอง:',
              widget.bookingId,
            ),
            _buildDetailRow(
              'วันที่ฝากเลี้ยง:',
              _formatDates(_bookingData!['dates'] ?? []),
            ),
            _buildDetailRow(
              'จำนวนวัน:',
              '${(_bookingData!['dates'] as List?)?.length ?? 0} วัน',
            ),
            _buildDetailRow(
              'ราคารวม:',
              '฿${_bookingData!['totalPrice'] ?? 0}',
              valueColor: Colors.green,
            ),
            if (_bookingData!['adminMessage'] != null &&
                _bookingData!['adminMessage'].isNotEmpty)
              _buildDetailRow(
                'ข้อความจากแอดมิน:',
                _bookingData!['adminMessage'],
              ),
            if (_bookingData!['notes'] != null &&
                _bookingData!['notes'].isNotEmpty)
              _buildDetailRow(
                'บันทึกเพิ่มเติม:',
                _bookingData!['notes'],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatsList() {
    if (_catsList.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('ไม่พบข้อมูลแมวที่ฝากเลี้ยง'),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pets, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'แมวที่ฝากเลี้ยง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _catsList.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final cat = _catsList[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: cat['imagePath'] != null &&
                            cat['imagePath'].toString().isNotEmpty
                        ? NetworkImage(cat['imagePath'])
                        : null,
                    child: cat['imagePath'] == null ||
                            cat['imagePath'].toString().isEmpty
                        ? const Icon(Icons.pets)
                        : null,
                  ),
                  title: Text(cat['name'] ?? 'ไม่ระบุชื่อแมว'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat['breed'] ?? 'ไม่ระบุสายพันธุ์'),
                      if (cat['age'] != null) Text('อายุ: ${cat['age']} ปี'),
                    ],
                  ),
                  isThreeLine: cat['age'] != null,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  // เพิ่มการเลือกแมวเพื่อดูเช็คลิสต์
                  trailing: Radio<String>(
                    value: cat['id'],
                    groupValue: _selectedCatId,
                    onChanged: (value) {
                      setState(() {
                        _selectedCatId = value;
                      });
                    },
                    activeColor: Colors.deepOrange,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // เพิ่มเมธอดใหม่สำหรับแสดงเช็คลิสต์
  Widget _buildChecklistSection() {
    if (_bookingData!['status'] != 'in_progress' &&
        _bookingData!['status'] != 'completed') {
      return Container(); // ไม่แสดงเช็คลิสต์ถ้าสถานะไม่ใช่กำลังดำเนินการหรือเสร็จสิ้น
    }

    if (_selectedCatId == null) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment, color: Colors.deepOrange),
                  SizedBox(width: 8),
                  Text(
                    'เช็คลิสต์การดูแล',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Center(
                child: Text('กรุณาเลือกแมวเพื่อดูเช็คลิสต์'),
              ),
            ],
          ),
        ),
      );
    }

    // กรองเช็คลิสต์ตามแมวที่เลือก
    List<ChecklistItem> filteredItems =
        _checklistItems.where((item) => item.catId == _selectedCatId).toList();

    if (filteredItems.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment, color: Colors.deepOrange),
                  SizedBox(width: 8),
                  Text(
                    'เช็คลิสต์การดูแล',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Center(
                child: Text('ยังไม่มีรายการเช็คลิสต์สำหรับแมวตัวนี้'),
              ),
            ],
          ),
        ),
      );
    }

    // คำนวณความคืบหน้า
    int completedTasks = filteredItems.where((item) => item.isCompleted).length;
    double progress =
        filteredItems.isEmpty ? 0.0 : completedTasks / filteredItems.length;

    // แยกรายการเป็นที่ทำแล้วกับยังไม่ได้ทำ
    List<ChecklistItem> completedItems =
        filteredItems.where((item) => item.isCompleted).toList();
    List<ChecklistItem> pendingItems =
        filteredItems.where((item) => !item.isCompleted).toList();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'เช็คลิสต์การดูแล',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ความคืบหน้า',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
            ),
            SizedBox(height: 4),
            Text(
              'เสร็จแล้ว $completedTasks จาก ${filteredItems.length} รายการ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),

            // แสดงรายการที่ทำแล้ว
            if (completedItems.isNotEmpty) ...[
              Text(
                'รายการที่ดำเนินการแล้ว',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 8),
              ...completedItems.map((item) => _buildChecklistItemCard(item)),
              SizedBox(height: 16),
            ],

            // แสดงรายการที่ยังไม่ได้ทำ
            if (pendingItems.isNotEmpty) ...[
              Text(
                'รายการที่รอดำเนินการ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              SizedBox(height: 8),
              ...pendingItems
                  .map((item) => _buildChecklistItemCard(item, enabled: false)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItemCard(ChecklistItem item, {bool enabled = true}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.isCompleted ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              item.isCompleted ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                color: item.isCompleted ? Colors.green : Colors.grey,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.description,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration:
                        item.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          if (item.isCompleted)
            Padding(
              padding: EdgeInsets.only(left: 28, top: 4),
              child: Text(
                'เสร็จเมื่อ: ${DateFormat('dd/MM/yyyy HH:mm').format(item.timestamp)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                ),
              ),
            ),
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () => _showImageDialog(item.imageUrl!),
                child: Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(item.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          if (item.note != null && item.note!.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.yellow.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'บันทึก:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    item.note!,
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminActions() {
    final status = _bookingData!['status'] ?? 'pending';

    // ถ้าสถานะเป็น cancelled หรือ completed ไม่ต้องแสดงปุ่มให้อัพเดทสถานะ
    if (status == 'cancelled' || status == 'completed') {
      return Container();
    }

    // สร้าง List ของสถานะถัดไปที่สามารถอัพเดทได้
    List<Map<String, dynamic>> nextStatuses = [];

    if (status == 'pending') {
      nextStatuses = [
        {'value': 'confirmed', 'label': 'ยืนยัน', 'color': Colors.green},
        {'value': 'cancelled', 'label': 'ยกเลิก', 'color': Colors.red},
      ];
    } else if (status == 'confirmed') {
      nextStatuses = [
        {
          'value': 'in_progress',
          'label': 'เริ่มให้บริการ',
          'color': Colors.blue
        },
        {'value': 'cancelled', 'label': 'ยกเลิก', 'color': Colors.red},
      ];
    } else if (status == 'in_progress') {
      nextStatuses = [
        {'value': 'completed', 'label': 'เสร็จสิ้น', 'color': Colors.purple},
      ];
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.update, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'อัพเดทสถานะ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // สร้างปุ่มสำหรับแต่ละสถานะ
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: nextStatuses.map((status) {
                return ElevatedButton.icon(
                  onPressed: () => _showMessageDialog(status['value']),
                  icon: Icon(_getIconForStatus(status['value'])),
                  label: Text(status['label']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status['color'],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                );
              }).toList(),
            ),
            // เพิ่มปุ่มลบการจอง
            Divider(height: 32),
            InkWell(
              onTap: _deleteBooking,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'ลบการจอง',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForStatus(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.pets;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.update;
    }
  }
}
