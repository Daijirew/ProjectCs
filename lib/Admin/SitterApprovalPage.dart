import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/Admin/NotificationService.dart';

class SitterApprovalPage extends StatefulWidget {
  const SitterApprovalPage({Key? key}) : super(key: key);

  @override
  State<SitterApprovalPage> createState() => _SitterApprovalPageState();
}

class _SitterApprovalPageState extends State<SitterApprovalPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingSitters = [];
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadPendingSitters();
  }

  Future<void> _loadPendingSitters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> pendingSitters = [];
      for (var doc in snapshot.docs) {
        pendingSitters.add({
          'id': doc.id,
          ...doc.data(),
        });
      }

      setState(() {
        _pendingSitters = pendingSitters;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading pending sitters: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveSitter(String sitterId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(sitterId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // ส่งการแจ้งเตือนไปยังผู้รับเลี้ยงแมว
      await _notificationService.sendBookingStatusNotification(
        userId: sitterId,
        bookingId: '',
        status: 'approval',
        message: 'คำขอเป็นพี่เลี้ยงแมวของคุณได้รับการอนุมัติแล้ว คุณสามารถเริ่มรับงานได้ทันที',
      );

      // อัพเดตรายการในหน้าจอ
      setState(() {
        _pendingSitters.removeWhere((sitter) => sitter['id'] == sitterId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อนุมัติผู้รับเลี้ยงแมวเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error approving sitter: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการอนุมัติ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectSitter(String sitterId) async {
    try {
      // แสดงไดอะล็อกให้ระบุเหตุผลในการปฏิเสธ
      String? rejectionReason = await showDialog<String>(
        context: context,
        builder: (context) => _buildRejectionDialog(context),
      );

      if (rejectionReason == null || rejectionReason.isEmpty) {
        return; // ผู้ใช้ยกเลิกการปฏิเสธ
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(sitterId)
          .update({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // ส่งการแจ้งเตือนไปยังผู้รับเลี้ยงแมว
      await _notificationService.sendBookingStatusNotification(
        userId: sitterId,
        bookingId: '',
        status: 'rejection',
        message: 'คำขอเป็นพี่เลี้ยงแมวของคุณถูกปฏิเสธ: $rejectionReason',
      );

      // อัพเดตรายการในหน้าจอ
      setState(() {
        _pendingSitters.removeWhere((sitter) => sitter['id'] == sitterId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ปฏิเสธผู้รับเลี้ยงแมวเรียบร้อยแล้ว'),
          backgroundColor: Colors.deepOrange,
        ),
      );
    } catch (e) {
      print('Error rejecting sitter: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการปฏิเสธ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildRejectionDialog(BuildContext context) {
    TextEditingController reasonController = TextEditingController();

    return AlertDialog(
      title: Text('ระบุเหตุผลในการปฏิเสธ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('กรุณาระบุเหตุผลที่ชัดเจนเพื่อให้ผู้สมัครทราบ'),
          SizedBox(height: 16),
          TextField(
            controller: reasonController,
            decoration: InputDecoration(
              hintText: 'เหตุผลในการปฏิเสธ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.deepOrange, width: 2),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () {
            if (reasonController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('กรุณาระบุเหตุผลในการปฏิเสธ')),
              );
              return;
            }
            Navigator.pop(context, reasonController.text.trim());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text('ยืนยัน'),
        ),
      ],
    );
  }

  // สร้าง widget แสดงรายละเอียดพี่เลี้ยง
  Widget _buildSitterDetailDialog(Map<String, dynamic> sitter) {
    return AlertDialog(
      title: Text('รายละเอียดผู้รับเลี้ยงแมว'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: sitter['photo'] != null &&
                        sitter['photo'] != 'images/User.png'
                    ? NetworkImage(sitter['photo'])
                    : null,
                child: sitter['photo'] == 'images/User.png' ||
                        sitter['photo'] == null
                    ? Icon(Icons.person, size: 50)
                    : null,
              ),
            ),
            SizedBox(height: 16),
            _buildDetailItem('ชื่อ', sitter['name'] ?? 'ไม่ระบุ'),
            _buildDetailItem('อีเมล', sitter['email'] ?? 'ไม่ระบุ'),
            _buildDetailItem('เบอร์โทร', sitter['phone'] ?? 'ไม่ระบุ'),
            _buildDetailItem('ที่อยู่', sitter['address'] ?? 'ไม่ระบุ'),
            _buildDetailItem('ประสบการณ์', sitter['experience'] ?? 'ไม่ระบุ'),
            if (sitter['createdAt'] != null)
              _buildDetailItem(
                  'วันที่สมัคร',
                  sitter['createdAt'].toDate().toString().substring(0, 16) ??
                      'ไม่ระบุ'),
            Divider(),
            SizedBox(height: 8),
            Text(
              'ข้อมูลเพิ่มเติม',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(sitter['additionalInfo'] ?? 'ไม่มีข้อมูลเพิ่มเติม'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ปิด'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectSitter(sitter['id']);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text('ปฏิเสธ'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _approveSitter(sitter['id']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('อนุมัติ'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('อนุมัติผู้รับเลี้ยงแมว'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPendingSitters,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _pendingSitters.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'ไม่มีผู้รับเลี้ยงแมวที่รอการอนุมัติ',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _pendingSitters.length,
                  padding: EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final sitter = _pendingSitters[index];
                    return Card(
                      elevation: 3,
                      margin: EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => _buildSitterDetailDialog(sitter),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundImage: sitter['photo'] != null &&
                                            sitter['photo'] != 'images/User.png'
                                        ? NetworkImage(sitter['photo'])
                                        : null,
                                    child: sitter['photo'] == 'images/User.png' ||
                                            sitter['photo'] == null
                                        ? Icon(Icons.person)
                                        : null,
                                    radius: 30,
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sitter['name'] ?? 'ไม่ระบุชื่อ',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          sitter['email'] ?? 'ไม่ระบุอีเมล',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (sitter['phone'] != null)
                                          Text(
                                            'โทร: ${sitter['phone']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        if (sitter['createdAt'] != null)
                                          Text(
                                            'สมัครเมื่อ: ${sitter['createdAt'].toDate().toString().substring(0, 16)}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Divider(),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _rejectSitter(sitter['id']),
                                    icon: Icon(Icons.cancel, color: Colors.red),
                                    label: Text('ปฏิเสธ'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _approveSitter(sitter['id']),
                                    icon: Icon(Icons.check_circle),
                                    label: Text('อนุมัติ'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}