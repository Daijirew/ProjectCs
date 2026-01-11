import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class SitterVerificationPage extends StatefulWidget {
  const SitterVerificationPage({Key? key}) : super(key: key);

  @override
  _SitterVerificationPageState createState() => _SitterVerificationPageState();
}

class _SitterVerificationPageState extends State<SitterVerificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<DocumentSnapshot> _pendingSitters = [];
  List<DocumentSnapshot> _verifiedSitters = [];
  List<DocumentSnapshot> _rejectedSitters = [];
  TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadData();
      }
    });
    _loadData();

    // อัพเดทสถานะการอ่านการแจ้งเตือน
    _markNotificationsAsRead();
  }

  // ฟังก์ชันอัพเดทสถานะการอ่านการแจ้งเตือน
  Future<void> _markNotificationsAsRead() async {
    try {
      QuerySnapshot notificationsSnapshot = await FirebaseFirestore.instance
          .collection('admin_notifications')
          .where('type', isEqualTo: 'new_sitter')
          .where('isRead', isEqualTo: false)
          .get();

      // อัพเดทสถานะการอ่านเป็น true
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in notificationsSnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // แก้ไขวิธีการโหลดข้อมูล โดยแยกการค้นหาและการเรียงลำดับ
      if (_tabController.index == 0) {
        // วิธีที่ 1: โหลดข้อมูลโดยไม่ใช้ orderBy (จะใช้ index น้อยลง)
        QuerySnapshot pendingSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'sitter')
            .where('status', isEqualTo: 'pending')
            .get();

        // จัดเรียงข้อมูลในแอปแทน (ถ้าจำเป็น)
        List<DocumentSnapshot> sortedDocs = pendingSnapshot.docs;
        sortedDocs.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>;
          var bData = b.data() as Map<String, dynamic>;

          Timestamp? aTime = aData['registrationDate'] as Timestamp?;
          Timestamp? bTime = bData['registrationDate'] as Timestamp?;

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1; // null comes last
          if (bTime == null) return -1;

          // descending order
          return bTime.compareTo(aTime);
        });

        setState(() {
          _pendingSitters = sortedDocs;
        });

        /* วิธีที่ 2: ถ้าวิธีที่ 1 ไม่ได้ผล ลองใช้วิธีนี้
      // โหลดข้อมูลทั้งหมดก่อนแล้วค่อยกรอง
      QuerySnapshot allSittersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .get();
      
      // กรองเฉพาะที่มีสถานะ pending
      List<DocumentSnapshot> pendingDocs = allSittersSnapshot.docs
          .where((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return data['status'] == 'pending';
          })
          .toList();
      
      // เรียงลำดับตาม registrationDate
      pendingDocs.sort((a, b) {
        var aData = a.data() as Map<String, dynamic>;
        var bData = b.data() as Map<String, dynamic>;
        
        Timestamp? aTime = aData['registrationDate'] as Timestamp?;
        Timestamp? bTime = bData['registrationDate'] as Timestamp?;
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        // descending order
        return bTime.compareTo(aTime);
      });
      
      setState(() {
        _pendingSitters = pendingDocs;
      });
      */
      } else {
        // โค้ดสำหรับแท็บอื่นๆ (ให้แก้ไขในลักษณะเดียวกัน)
      }
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  

  // ฟังก์ชันอนุมัติ
  Future<void> _approveSitter(String userId) async {
    try {
      // แสดง dialog ยืนยัน
      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('ยืนยันการอนุมัติ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('คุณต้องการอนุมัติผู้รับเลี้ยงแมวรายนี้ใช่หรือไม่?'),
              SizedBox(height: 16),
              Text('หมายเหตุ (ถ้ามี):'),
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'เหตุผลในการปฏิเสธ',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('อนุมัติ'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // อัพเดทสถานะใน Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'adminComment': _commentController.text.trim(),
        });

        // สร้างการแจ้งเตือนสำหรับผู้ใช้
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
          'title': 'บัญชีของคุณได้รับการอนุมัติแล้ว',
          'message':
              'บัญชีผู้รับเลี้ยงแมวของคุณได้รับการอนุมัติแล้ว คุณสามารถให้บริการได้ทันที' +
                  (_commentController.text.isNotEmpty
                      ? '\n\nหมายเหตุ: ${_commentController.text}'
                      : ''),
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'verification',
        });

        // รีเซ็ตค่า comment
        _commentController.clear();

        // แสดงข้อความสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อนุมัติสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );

        // โหลดข้อมูลใหม่
        _loadData();
      }
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

  // ฟังก์ชันปฏิเสธ
  Future<void> _rejectSitter(String userId) async {
    try {
      // ตรวจสอบว่า comment ไม่ว่างเปล่า
      _commentController.clear();

      // แสดง dialog ให้ใส่เหตุผล
      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('ยืนยันการปฏิเสธ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('กรุณาระบุเหตุผลในการปฏิเสธ:'),
              SizedBox(height: 16),
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'เหตุผลในการปฏิเสธ',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_commentController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('กรุณาระบุเหตุผลในการปฏิเสธ'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  Navigator.of(context).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('ปฏิเสธ'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // อัพเดทสถานะใน Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'adminComment': _commentController.text.trim(),
        });

        // สร้างการแจ้งเตือนสำหรับผู้ใช้
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
          'title': 'บัญชีของคุณไม่ได้รับการอนุมัติ',
          'message': 'ขออภัย บัญชีผู้รับเลี้ยงแมวของคุณไม่ได้รับการอนุมัติ\n\n' +
              'เหตุผล: ${_commentController.text}\n\n' +
              'คุณสามารถปรับปรุงข้อมูลและยื่นขอเป็นผู้รับเลี้ยงแมวได้อีกครั้งในภายหลัง',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'verification',
        });

        // รีเซ็ตค่า comment
        _commentController.clear();

        // แสดงข้อความสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ปฏิเสธสำเร็จ'),
            backgroundColor: Colors.orange,
          ),
        );

        // โหลดข้อมูลใหม่
        _loadData();
      }
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

  // ฟังก์ชันระงับการใช้งาน
  Future<void> _suspendSitter(String userId) async {
    try {
      // แสดง dialog ให้ใส่เหตุผล
      _commentController.clear();
      final _formKey = GlobalKey<FormState>();

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('ยืนยันการระงับการใช้งาน'),
          content: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  // เปลี่ยนจาก TextField เป็น TextFormField
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'เหตุผลในการปฏิเสธ',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณาระบุเหตุผล';
                    }
                    return null;
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: Text('ปฏิเสธ'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_commentController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('กรุณาระบุเหตุผลในการระงับการใช้งาน'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  Navigator.of(context).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('ระงับการใช้งาน'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // อัพเดทสถานะใน Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'status': 'suspended',
          'suspendedAt': FieldValue.serverTimestamp(),
          'adminComment': _commentController.text.trim(),
        });

        // สร้างการแจ้งเตือนสำหรับผู้ใช้
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
          'title': 'บัญชีของคุณถูกระงับการใช้งาน',
          'message': 'ขออภัย บัญชีผู้รับเลี้ยงแมวของคุณถูกระงับการใช้งาน\n\n' +
              'เหตุผล: ${_commentController.text}\n\n' +
              'โปรดติดต่อฝ่ายช่วยเหลือหากต้องการข้อมูลเพิ่มเติม',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'verification',
        });

        // รีเซ็ตค่า comment
        _commentController.clear();

        // แสดงข้อความสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ระงับการใช้งานสำเร็จ'),
            backgroundColor: Colors.orange,
          ),
        );

        // โหลดข้อมูลใหม่
        _loadData();
      }
    } catch (e) {
      print('Error suspending sitter: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการระงับการใช้งาน: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ตรวจสอบผู้รับเลี้ยงแมว'),
        backgroundColor: Colors.deepOrange,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: Stack(
                children: [
                  Icon(Icons.pending_actions),
                  if (_pendingSitters.length > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          _pendingSitters.length.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              text: 'รอตรวจสอบ',
            ),
            Tab(
              icon: Icon(Icons.check_circle),
              text: 'อนุมัติแล้ว',
            ),
            Tab(
              icon: Icon(Icons.cancel),
              text: 'ปฏิเสธแล้ว',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // แท็บรอตรวจสอบ
                _buildSitterList(_pendingSitters, 'pending'),

                // แท็บอนุมัติแล้ว
                _buildSitterList(_verifiedSitters, 'approved'),

                // แท็บปฏิเสธแล้ว
                _buildSitterList(_rejectedSitters, 'rejected'),
              ],
            ),
    );
  }

  Widget _buildSitterList(List<DocumentSnapshot> sitters, String status) {
    if (sitters.isEmpty) {
      // ไม่มีรายการแสดง
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'pending'
                  ? Icons.pending_actions
                  : status == 'approved'
                      ? Icons.check_circle
                      : Icons.cancel,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              status == 'pending'
                  ? 'ไม่มีผู้รับเลี้ยงแมวที่รอตรวจสอบ'
                  : status == 'approved'
                      ? 'ไม่มีผู้รับเลี้ยงแมวที่อนุมัติแล้ว'
                      : 'ไม่มีผู้รับเลี้ยงแมวที่ปฏิเสธแล้ว',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: sitters.length,
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final sitter = sitters[index];
        final sitterData = sitter.data() as Map<String, dynamic>;

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ส่วนหัวข้อมูลคำขอ
              Container(
                decoration: BoxDecoration(
                  color: status == 'pending'
                      ? Colors.amber.shade100
                      : status == 'approved'
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      status == 'pending'
                          ? Icons.pending_actions
                          : status == 'approved'
                              ? Icons.check_circle
                              : Icons.cancel,
                      color: status == 'pending'
                          ? Colors.amber.shade800
                          : status == 'approved'
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                    ),
                    SizedBox(width: 8),
                    Text(
                      status == 'pending'
                          ? 'รอการตรวจสอบ'
                          : status == 'approved'
                              ? 'อนุมัติแล้ว'
                              : 'ปฏิเสธแล้ว',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: status == 'pending'
                            ? Colors.amber.shade800
                            : status == 'approved'
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'ลงทะเบียนเมื่อ: ${_formatTimestamp(sitterData['registrationDate'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // ข้อมูลผู้รับเลี้ยงแมว
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ข้อมูลส่วนตัว
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // รูปโปรไฟล์
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: sitterData['photo'] ??
                                'https://via.placeholder.com/150',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[300],
                              child:
                                  Icon(Icons.person, color: Colors.grey[500]),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[300],
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),

                        // ข้อมูลพื้นฐาน
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sitterData['name'] ?? 'ไม่ระบุชื่อ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.email,
                                      size: 16, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      sitterData['email'] ?? 'ไม่ระบุอีเมล',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone,
                                      size: 16, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text(
                                    sitterData['phone'] ?? 'ไม่ระบุเบอร์โทร',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // รายละเอียดบริการ
                    Text(
                      'รายละเอียดบริการ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildServiceInfo(
                        'อัตราค่าบริการ',
                        '${sitterData['serviceRate'] ?? 'ไม่ระบุ'} บาท/วัน',
                        Icons.monetization_on),
                    _buildServiceInfo(
                        'จำนวนแมวที่รับได้',
                        '${sitterData['petsPerDay'] ?? 'ไม่ระบุ'} ตัว/วัน',
                        Icons.pets),
                    _buildServiceInfo(
                        'ช่วงอายุแมวที่รับเลี้ยง',
                        sitterData['acceptedCatAge'] ?? 'ไม่ระบุ',
                        Icons.access_time),
                    SizedBox(height: 20),

                    // ประสบการณ์การเลี้ยงแมว
                    Text(
                      'ประสบการณ์และประวัติการเลี้ยงแมว',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        sitterData['catExperience'] ?? 'ไม่ระบุ',
                        style: TextStyle(
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // รูปภาพสถานที่ให้บริการ
                    Text(
                      'รูปภาพสถานที่ให้บริการ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (sitterData.containsKey('servicePictures') &&
                        (sitterData['servicePictures'] as List).isNotEmpty)
                      Container(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              (sitterData['servicePictures'] as List).length,
                          itemBuilder: (context, imageIndex) {
                            String imageUrl = (sitterData['servicePictures']
                                as List)[imageIndex];
                            return GestureDetector(
                              onTap: () {
                                // แสดงรูปภาพแบบเต็มจอ
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 120,
                                margin: EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[300],
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: Colors.grey[300],
                                      child:
                                          Icon(Icons.error, color: Colors.red),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Text(
                        'ไม่มีรูปภาพสถานที่ให้บริการ',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                    // ข้อมูลช่องทางการติดต่อ
                    SizedBox(height: 20),
                    Text(
                      'ช่องทางการติดต่อ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    SizedBox(height: 8),

                    // Facebook
                    if (sitterData.containsKey('facebook') &&
                        sitterData['facebook'] != null &&
                        sitterData['facebook'].toString().isNotEmpty)
                      _buildContactInfo(
                        'Facebook',
                        sitterData['facebook'],
                        Icons.facebook,
                        Colors.blue,
                        () => _launchUrl(sitterData['facebook']),
                      ),

                    // Instagram
                    if (sitterData.containsKey('instagram') &&
                        sitterData['instagram'] != null &&
                        sitterData['instagram'].toString().isNotEmpty)
                      _buildContactInfo(
                        'Instagram',
                        sitterData['instagram'],
                        Icons.camera_alt,
                        Colors.purple,
                        () => _launchUrl(sitterData['instagram']),
                      ),

                    // Line ID
                    if (sitterData.containsKey('line') &&
                        sitterData['line'] != null &&
                        sitterData['line'].toString().isNotEmpty)
                      _buildContactInfo(
                        'Line ID',
                        sitterData['line'],
                        Icons.chat,
                        Colors.green,
                        null,
                      ),

                    // หมายเหตุจากแอดมิน (ถ้ามี)
                    if (status != 'pending' &&
                        sitterData.containsKey('adminComment') &&
                        sitterData['adminComment'] != null &&
                        sitterData['adminComment'].toString().isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 20),
                          Text(
                            'หมายเหตุจากแอดมิน',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: status == 'approved'
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: status == 'approved'
                                    ? Colors.green.shade200
                                    : Colors.red.shade200,
                              ),
                            ),
                            child: Text(
                              sitterData['adminComment'],
                              style: TextStyle(
                                color: status == 'approved'
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // ปุ่มตัวเลือกการดำเนินการ
              if (status == 'pending')
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _rejectSitter(sitter.id),
                          icon: Icon(Icons.cancel),
                          label: Text('ปฏิเสธ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveSitter(sitter.id),
                          icon: Icon(Icons.check_circle),
                          label: Text('อนุมัติ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (status == 'approved')
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _suspendSitter(sitter.id),
                    icon: Icon(Icons.block),
                    label: Text('ระงับการใช้งาน'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceInfo(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(String label, String value, IconData icon,
      Color color, Function()? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            SizedBox(width: 8),
            Text(
              '$label: ',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: onTap != null ? color : Colors.grey[700],
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null) Icon(Icons.open_in_new, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'ไม่ระบุ';

    if (timestamp is Timestamp) {
      DateTime dateTime = timestamp.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }

    return 'ไม่ระบุ';
  }

  Future<void> _launchUrl(String urlString) async {
    // ตรวจสอบว่า URL มี scheme หรือไม่
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://' + urlString;
    }

    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('ไม่สามารถเปิด $url');
    }
  }
}
