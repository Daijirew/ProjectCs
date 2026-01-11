import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:myproject/pages.dart/history_screen.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/attendance_service.dart';
import '../models/attendance_record.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// นิยามค่าคงที่สำหรับ timezone ของประเทศไทย (UTC+7)
const int thaiTimeZoneOffset = 7;

class Todayscreen extends StatefulWidget {
  final String? chatRoomId;
  final String? receiverName;
  final String? senderUsername;
  final String bookingId; // เปลี่ยนให้รับค่าว่างได้

  const Todayscreen({
    Key? key,
    this.chatRoomId,
    this.receiverName,
    this.senderUsername,
    this.bookingId = '', // กำหนดค่าเริ่มต้นเป็นค่าว่าง
  }) : super(key: key);

  @override
  State<Todayscreen> createState() => _TodayscreenState();
}

class _TodayscreenState extends State<Todayscreen> {
  double screenHeight = 0;
  double screenWidth = 0;
  Color primary = const Color(0xFFF57C00); // เปลี่ยนสีเป็นสีส้มที่สวยขึ้น

  final AttendanceService _attendanceService = AttendanceService();
  String? _currentRecordId;
  bool _isLoading = true;

  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;
  String? _imagePath;

  // เริ่มต้นค่าด้วยเวลาประเทศไทย
  late TimeOfDay _checkInTime;
  TimeOfDay? _checkOutTime;
  bool _hasCheckedIn = false;
  bool _hasCheckedOut = false;

  // เก็บเวลาปัจจุบันของไทย
  late DateTime _currentDateTime;
  Timer? _timer;

  // ฟังก์ชันสำหรับรับเวลาปัจจุบันของประเทศไทย
  DateTime getThailandTime() {
    final now = DateTime.now().toUtc();
    return now.add(Duration(hours: thaiTimeZoneOffset));
  }

  @override
  void initState() {
    super.initState();

    // ตั้งค่าเวลาเริ่มต้นเป็นเวลาไทย
    _currentDateTime = getThailandTime();
    _checkInTime = TimeOfDay.fromDateTime(_currentDateTime);

    // อัพเดตเวลาทุกวินาที
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _currentDateTime = getThailandTime();
      });
    });

    // โหลดข้อมูลวันนี้
    _loadTodayRecord();

    // เพิ่มการตรวจสอบสถานะการจอง
    _checkBookingStatus();
  }

  Future<void> _loadTodayRecord() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // รีเซ็ตค่าทุกครั้งเมื่อโหลดข้อมูล
      setState(() {
        _hasCheckedIn = false;
        _hasCheckedOut = false;
        _checkOutTime = null;
        _currentRecordId = null;
      });

      final todayRecord = await _attendanceService.getTodayRecord();

      print(
          'โหลดข้อมูลวันนี้: ${todayRecord != null ? 'พบข้อมูล' : 'ไม่พบข้อมูล'}');

      if (todayRecord != null) {
        print('Record ID: ${todayRecord.id}');
        print('Check-in time: ${todayRecord.checkInTime.format(context)}');
        print(
            'Check-out time: ${todayRecord.checkOutTime?.format(context) ?? 'ยังไม่ได้เช็คเอาท์'}');

        setState(() {
          _currentRecordId = todayRecord.id;
          _checkInTime = todayRecord.checkInTime;
          _hasCheckedIn = true;

          if (todayRecord.checkOutTime != null) {
            _checkOutTime = todayRecord.checkOutTime;
            _hasCheckedOut = true;
          }

          if (todayRecord.imagePath != null &&
              todayRecord.imagePath!.isNotEmpty) {
            _imagePath = todayRecord.imagePath;

            // ตรวจสอบว่าไฟล์ภาพยังมีอยู่หรือไม่ก่อนโหลด
            final file = File(todayRecord.imagePath!);
            if (file.existsSync()) {
              _capturedImage = file;
            } else {
              _imagePath = null; // รีเซ็ตค่าถ้าไฟล์ภาพไม่มีอยู่แล้ว
            }
          }
        });
      }
    } catch (e) {
      print("เกิดข้อผิดพลาดในการโหลดข้อมูล: $e");
    }

    setState(() {
      _isLoading = false;
    });
  }

  // เพิ่มฟังก์ชันรีเซ็ต
  void _resetCheckIn() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.refresh, color: primary),
              SizedBox(width: 10),
              Text('รีเซ็ตการเช็คอิน'),
            ],
          ),
          content: Text('คุณต้องการรีเซ็ตการเช็คอินวันนี้ใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ยกเลิก',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasCheckedIn = false;
                  _hasCheckedOut = false;
                  _checkOutTime = null;
                  _currentRecordId = null;
                  _capturedImage = null;
                  _imagePath = null;
                  // ตั้งเวลาเช็คอินใหม่เป็นเวลาไทยปัจจุบัน
                  _checkInTime = TimeOfDay.fromDateTime(getThailandTime());
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('รีเซ็ต'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ฟังก์ชันสำหรับเลือกเวลาเข้างาน
  Future<void> _selectCheckInTime(BuildContext context) async {
    if (_hasCheckedIn) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _checkInTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            buttonTheme: ButtonThemeData(
              colorScheme: ColorScheme.light(
                primary: primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null && pickedTime != _checkInTime) {
      setState(() {
        _checkInTime = pickedTime;
      });
    }
  }

  void _checkBookingStatus() async {
    // ข้ามการตรวจสอบถ้า bookingId เป็นค่าว่าง
    if (widget.bookingId.isEmpty) {
      print('bookingId เป็นค่าว่าง ข้ามการตรวจสอบสถานะการจอง');
      return;
    }

    try {
      DocumentSnapshot bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (bookingDoc.exists) {
        Map<String, dynamic> data = bookingDoc.data() as Map<String, dynamic>;

        // ตรวจสอบสถานะ
        if (data['status'] == 'completed' && data['checkOutTime'] != null) {
          setState(() {
            _hasCheckedOut = true;
            // แปลงเวลาจาก Timestamp เป็น TimeOfDay
            if (data['checkOutTime'] is Timestamp) {
              DateTime checkOutDateTime =
                  (data['checkOutTime'] as Timestamp).toDate();

              // ปรับให้เป็นเวลาไทย
              checkOutDateTime = checkOutDateTime.add(Duration(
                  hours: checkOutDateTime.timeZoneOffset.inHours < 7
                      ? (7 - checkOutDateTime.timeZoneOffset.inHours)
                      : 0));

              _checkOutTime = TimeOfDay.fromDateTime(checkOutDateTime);
            }
          });
          print('สถานะการจอง: completed');
        } else if (data['checkInTime'] != null) {
          setState(() {
            _hasCheckedIn = true;
            // ถ้ามีข้อมูล checkInTime ใน Firestore ให้ใช้เวลานั้น
            if (data['checkInTime'] is Timestamp) {
              DateTime checkInDateTime =
                  (data['checkInTime'] as Timestamp).toDate();

              // ปรับให้เป็นเวลาไทย
              checkInDateTime = checkInDateTime.add(Duration(
                  hours: checkInDateTime.timeZoneOffset.inHours < 7
                      ? (7 - checkInDateTime.timeZoneOffset.inHours)
                      : 0));

              _checkInTime = TimeOfDay.fromDateTime(checkInDateTime);
            }
          });
          print('มีการเช็คอินแล้ว');
        }
      } else {
        print('ไม่พบข้อมูลการจอง: ${widget.bookingId}');
      }
    } catch (e) {
      print('Error checking booking status: $e');
    }
  }

  // ฟังก์ชันสำหรับเช็คอิน
  void _checkIn() async {
    if (_hasCheckedIn) return; // เช็คซ้ำอีกครั้งเพื่อความปลอดภัย

    if (widget.chatRoomId != null && widget.receiverName != null) {
      // แสดงไดอะล็อกยืนยันการเช็คอินและส่งข้อความ
      _showCheckInConfirmDialog();
    } else {
      try {
        // บันทึกข้อมูลการเช็คอิน
        final record = await _attendanceService.saveCheckIn(
          _checkInTime,
          '', // บันทึกเปล่า
          _imagePath,
        );

        setState(() {
          _currentRecordId = record.id;
          _hasCheckedIn = true;
        });

        // อัปเดท Firestore ถ้ามี bookingId
        if (widget.bookingId.isNotEmpty) {
          try {
            // แปลงเวลาเป็น DateTime
            final DateTime now = getThailandTime();
            final DateTime checkInDateTime = DateTime(now.year, now.month,
                now.day, _checkInTime.hour, _checkInTime.minute);

            await FirebaseFirestore.instance
                .collection('bookings')
                .doc(widget.bookingId)
                .update({
              'checkInTime': checkInDateTime,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            print('อัปเดทเวลาเช็คอินใน Firestore สำเร็จ');
          } catch (e) {
            print('ไม่สามารถอัปเดทเวลาเช็คอินใน Firestore: $e');
          }
        }

        // แสดงแจ้งเตือนบันทึกสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกการเช็คอินสำเร็จ'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        // แสดงข้อผิดพลาด
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ฟังก์ชันแสดงไดอะล็อกยืนยันการเช็คอิน
  void _showCheckInConfirmDialog() {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('ยืนยันการบันทึกเวลา'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'คุณต้องการบันทึกเวลาและแจ้ง ${widget.receiverName} หรือไม่?',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 15),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: 'เพิ่มข้อความ (ถ้ามี)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.green, width: 2),
                  ),
                  fillColor: Colors.grey.shade50,
                  filled: true,
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ยกเลิก',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // บันทึกการเช็คอิน
                  final record = await _attendanceService.saveCheckIn(
                    _checkInTime,
                    noteController.text,
                    _imagePath,
                  );

                  setState(() {
                    _currentRecordId = record.id;
                    _hasCheckedIn = true;
                  });

                  // อัปเดท Firestore ถ้ามี bookingId
                  if (widget.bookingId.isNotEmpty) {
                    try {
                      // แปลงเวลาเป็น DateTime
                      final DateTime now = getThailandTime();
                      final DateTime checkInDateTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          _checkInTime.hour,
                          _checkInTime.minute);

                      await FirebaseFirestore.instance
                          .collection('bookings')
                          .doc(widget.bookingId)
                          .update({
                        'checkInTime': checkInDateTime,
                        'lastUpdated': FieldValue.serverTimestamp(),
                      });
                      print('อัปเดทเวลาเช็คอินใน Firestore สำเร็จ');
                    } catch (e) {
                      print('ไม่สามารถอัปเดทเวลาเช็คอินใน Firestore: $e');
                    }
                  }

                  // ปิดไดอะล็อก
                  Navigator.pop(context);

                  // ส่งข้อมูลกลับไปที่หน้าแชท
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context, {
                      'checkedIn': true,
                      'checkInTime': _checkInTime.format(context),
                      'note': noteController.text,
                      'imagePath': _imagePath,
                      'capturedImage': _capturedImage,
                    });
                  }
                } catch (e) {
                  // แสดงข้อผิดพลาด
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text('บันทึกและแจ้งเตือน'),
            ),
          ],
        );
      },
    );
  }

  // ฟังก์ชันสำหรับการถ่ายรูป
  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // เพิ่มการบีบอัดรูปภาพ
        maxWidth: 1200, // กำหนดความกว้างสูงสุด
      );
      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
          _imagePath = photo.path;
        });
      }
    } catch (e) {
      print("เกิดข้อผิดพลาดในการถ่ายรูป: $e");
      // แสดงข้อผิดพลาด
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการถ่ายรูป: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _checkOut() async {
    print('เริ่มการเช็คเอาท์');
    print(
        'สถานะปัจจุบัน: hasCheckedIn=$_hasCheckedIn, hasCheckedOut=$_hasCheckedOut');
    print('Current Record ID: $_currentRecordId');
    print('Booking ID: ${widget.bookingId}');

    if (!_hasCheckedIn || _hasCheckedOut) {
      print('ไม่สามารถเช็คเอาท์ได้: ไม่ได้เช็คอินหรือเช็คเอาท์ไปแล้ว');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถเช็คเอาท์ได้: ต้องเช็คอินก่อน'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Get current time แบบเวลาไทย
      final now = getThailandTime();
      _checkOutTime = TimeOfDay.fromDateTime(now);
      print('กำหนดเวลาเช็คเอาท์: ${_checkOutTime!.format(context)}');

      // บันทึกการเช็คเอาท์ใน AttendanceService ถ้ามี currentRecordId
      if (_currentRecordId != null) {
        print(
            'กำลังบันทึกเช็คเอาท์ใน AttendanceService สำหรับ ID: $_currentRecordId');
        await _attendanceService.saveCheckOut(
          _currentRecordId!,
          _checkOutTime!,
          'เช็คเอาท์สำเร็จ',
        );
        print('บันทึกเช็คเอาท์ใน AttendanceService สำเร็จ');
      }

      // อัพเดท Firestore เฉพาะเมื่อ bookingId ไม่ว่างเปล่า
      if (widget.bookingId.isNotEmpty) {
        try {
          // ตรวจสอบว่าข้อมูลการจองมีอยู่จริง
          DocumentSnapshot bookingSnapshot = await FirebaseFirestore.instance
              .collection('bookings')
              .doc(widget.bookingId)
              .get();

          if (bookingSnapshot.exists) {
            print(
                'พบข้อมูลการจอง สถานะปัจจุบัน: ${(bookingSnapshot.data() as Map<String, dynamic>)['status']}');

            // Update Firestore document
            print('กำลังอัพเดท Firestore สำหรับการจอง: ${widget.bookingId}');
            await FirebaseFirestore.instance
                .collection('bookings')
                .doc(widget.bookingId)
                .update({
              'checkOutTime': now,
              'status': 'completed',
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            print('อัพเดท Firestore สำเร็จ');
          } else {
            print('ไม่พบข้อมูลการจอง: ${widget.bookingId}');
            // บันทึกเฉพาะในแอปโดยไม่อัพเดท Firestore
            print('ข้ามการอัพเดท Firestore');
          }
        } catch (e) {
          print('เกิดข้อผิดพลาดในการตรวจสอบหรืออัพเดทข้อมูลการจอง: $e');
          // ยังคงถือว่าบันทึกสำเร็จในแอป แม้จะล้มเหลวในการอัพเดท Firestore
        }
      } else {
        print('bookingId เป็นค่าว่าง ข้ามการอัพเดท Firestore');
      }

      setState(() {
        _hasCheckedOut = true;
        _isLoading = false;
      });
      print('อัพเดทสถานะ UI: hasCheckedOut=true');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.bookingId.isEmpty
              ? 'เช็คเอาท์สำเร็จ (บันทึกเฉพาะในอุปกรณ์)'
              : 'เช็คเอาท์สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      print('การเช็คเอาท์เสร็จสมบูรณ์');
    } catch (e) {
      print('เกิดข้อผิดพลาดในการเช็คเอาท์: $e');
      setState(() {
        _isLoading = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการเช็คเอาท์: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    screenHeight = MediaQuery.of(context).size.height;
    screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: Text(
          'บันทึกเวลาการทำงาน',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        // เพิ่มปุ่มดูประวัติและปุ่มรีเซ็ต
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetCheckIn,
            tooltip: 'รีเซ็ตการเช็คอิน',
          ),
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryScreen()),
              ).then((_) =>
                  _loadTodayRecord()); // โหลดข้อมูลใหม่หลังกลับมาจากหน้าประวัติ
            },
            tooltip: 'ดูประวัติการเช็คอิน/เช็คเอาท์',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.orange.shade50, Colors.white],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ส่วนหัว
                    Container(
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(top: 10, bottom: 20),
                      child: Column(
                        children: [
                          Text(
                            "ยินดีต้อนรับ",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            "ระบบบันทึกเวลาการดูแลแมว",
                            style: TextStyle(
                              color: primary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ส่วนแสดงรูปภาพที่ถ่าย
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 10),
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _capturedImage != null
                          ? GestureDetector(
                              onTap: _showFullImage,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.file(
                                  _capturedImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo,
                                    size: 50,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    "ถ่ายรูปแมวที่คุณกำลังดูแล",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                    // ปุ่มถ่ายรูป
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 20),
                      child: ElevatedButton.icon(
                        onPressed: _takePicture,
                        icon: Icon(Icons.camera_alt),
                        label: Text("ถ่ายรูป"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 5,
                          shadowColor: primary.withOpacity(0.5),
                        ),
                      ),
                    ),

                    // ส่วนสถานะวันนี้
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(top: 10, bottom: 10),
                      child: Text(
                        "สถานะการทำงานวันนี้",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    // กล่องแสดงเวลาเช็คอิน/เช็คเอาท์
                    Container(
                      margin: EdgeInsets.only(top: 10, bottom: 20),
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            spreadRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectCheckInTime(context),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "เช็คอิน",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "${_checkInTime.format(context)}",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: _hasCheckedIn
                                          ? Colors.green
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  ElevatedButton(
                                    onPressed: _hasCheckedIn ? null : _checkIn,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      disabledBackgroundColor: Colors.grey[300],
                                    ),
                                    child: Text(
                                      _hasCheckedIn ? "เช็คอินแล้ว" : "เช็คอิน",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            height: 100,
                            width: 1,
                            color: Colors.grey[300],
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "เช็คเอาท์",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _checkOutTime == null
                                      ? "--:--"
                                      : "${_checkOutTime!.format(context)}",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: _hasCheckedOut
                                        ? Colors.red
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                ElevatedButton(
                                  onPressed: (!_hasCheckedIn || _hasCheckedOut)
                                      ? null
                                      : _checkOut,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    disabledBackgroundColor: Colors.grey[300],
                                  ),
                                  child: Text(
                                    _hasCheckedOut
                                        ? "เช็คเอาท์แล้ว"
                                        : "เช็คเอาท์",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // แสดงวันที่และเวลาปัจจุบัน
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('d MMMM yyyy', 'th_TH')
                                .format(_currentDateTime), // ใช้ภาษาไทย
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            DateFormat('HH:mm:ss', 'th_TH')
                                .format(_currentDateTime), // เวลาแบบ 24 ชั่วโมง
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // ปุ่มสไลด์
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 20),
                      child: Builder(builder: (context) {
                        final GlobalKey<SlideActionState> key = GlobalKey();

                        return SlideAction(
                          text: "เลื่อนเพื่อเช็คเอาท์",
                          textStyle: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          outerColor: Colors.white,
                          innerColor: primary,
                          key: key,
                          onSubmit: () {
                            if (_hasCheckedIn && !_hasCheckedOut) {
                              _checkOut();

                              // ถ้ามีข้อมูลแชทให้ส่งข้อมูลกลับ
                              if (widget.chatRoomId != null &&
                                  Navigator.canPop(context)) {
                                Future.delayed(Duration(seconds: 1), () {
                                  Navigator.pop(context, {
                                    'checkedOut': true,
                                    'checkOutTime':
                                        _checkOutTime?.format(context) ??
                                            TimeOfDay.now().format(context),
                                    'imagePath': _imagePath,
                                    'capturedImage': _capturedImage,
                                  });
                                });
                              }
                            } else if (!_hasCheckedIn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'ไม่สามารถเช็คเอาท์ได้: ต้องเช็คอินก่อน'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } else if (_hasCheckedOut) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('คุณได้เช็คเอาท์ไปแล้ว'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }

                            // รีเซ็ต slider
                            Future.delayed(Duration(seconds: 1), () {
                              if (key.currentState != null) {
                                key.currentState!.reset();
                              }
                            });
                          },
                          enabled: _hasCheckedIn && !_hasCheckedOut,
                          sliderButtonIconPadding: 15,
                          sliderButtonYOffset: -1,
                          borderRadius: 15,
                          elevation: 5,
                          submittedIcon: Icon(
                            Icons.check,
                            color: Colors.white,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showFullImage() {
    if (_capturedImage == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.infinity,
            height: screenHeight * 0.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: FileImage(_capturedImage!),
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}
