import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/Admin/BookingCleanupService.dart';
import 'package:myproject/Admin/ScheduledTasksManager.dart';
import 'package:myproject/Admin/ServiceFeeManagementPage.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({Key? key}) : super(key: key);

  @override
  _AdminSettingsPageState createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  bool _isLoading = false;
  int _bookingTimeoutMinutes = 30;
  int _oldBookingsDays = 90;
  bool _autoCleanupEnabled = true;
  final TextEditingController _timeoutController = TextEditingController();
  final TextEditingController _oldBookingsDaysController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // โหลดการตั้งค่าจาก Firestore
      DocumentSnapshot settingsDoc = await FirebaseFirestore.instance
          .collection('admin')
          .doc('settings')
          .get();

      if (settingsDoc.exists) {
        Map<String, dynamic> data = settingsDoc.data() as Map<String, dynamic>;
        setState(() {
          _bookingTimeoutMinutes = data['bookingTimeoutMinutes'] ?? 30;
          _oldBookingsDays = data['oldBookingsDays'] ?? 90;
          _autoCleanupEnabled = data['autoCleanupEnabled'] ?? true;
        });
      }

      // ตั้งค่าตัวควบคุมข้อความ
      _timeoutController.text = _bookingTimeoutMinutes.toString();
      _oldBookingsDaysController.text = _oldBookingsDays.toString();
    } catch (e) {
      print('Error loading settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการโหลดการตั้งค่า: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ตรวจสอบและแปลงค่า
      int timeout = int.tryParse(_timeoutController.text) ?? 30;
      int days = int.tryParse(_oldBookingsDaysController.text) ?? 90;

      // ต้องมีค่ามากกว่า 0
      if (timeout <= 0 || days <= 0) {
        throw Exception('ค่าต้องมากกว่า 0');
      }

      // บันทึกค่าลงตัวแปร
      _bookingTimeoutMinutes = timeout;
      _oldBookingsDays = days;

      // บันทึกการตั้งค่าลง Firestore
      await FirebaseFirestore.instance.collection('admin').doc('settings').set({
        'bookingTimeoutMinutes': _bookingTimeoutMinutes,
        'oldBookingsDays': _oldBookingsDays,
        'autoCleanupEnabled': _autoCleanupEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // หยุดหรือเริ่มระบบทำความสะอาดอัตโนมัติ
      if (_autoCleanupEnabled) {
        ScheduledTasksManager().startScheduledTasks();
      } else {
        ScheduledTasksManager().stopScheduledTasks();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกการตั้งค่าเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึกการตั้งค่า: $e'),
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
        title: Text('ตั้งค่าระบบ'),
        backgroundColor: Colors.deepOrange,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // หัวข้อการตั้งค่าระบบทำความสะอาด
                  Card(
                    elevation: 2,
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
                              Icon(Icons.cleaning_services,
                                  color: Colors.deepOrange),
                              SizedBox(width: 8),
                              Text(
                                'การตั้งค่าระบบทำความสะอาดคิว',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),

                          // เปิด/ปิดระบบทำความสะอาดอัตโนมัติ
                          SwitchListTile(
                            title: Text('เปิดใช้ระบบทำความสะอาดอัตโนมัติ'),
                            subtitle: Text(
                                'ระบบจะทำความสะอาดคิวที่ไม่ได้รับการยืนยันและคิวเก่าตามกำหนดเวลา'),
                            value: _autoCleanupEnabled,
                            activeColor: Colors.deepOrange,
                            onChanged: (value) {
                              setState(() {
                                _autoCleanupEnabled = value;
                              });
                            },
                          ),

                          Divider(),

                          // เวลาในการยกเลิกคิวอัตโนมัติ
                          Text(
                            'ระยะเวลาที่รอการยืนยัน (นาที)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _timeoutController,
                            decoration: InputDecoration(
                              hintText: 'ระบุเวลา (นาที)',
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.deepOrange, width: 2),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'คิวที่ไม่ได้รับการยืนยันเกินเวลาที่กำหนดจะถูกยกเลิกอัตโนมัติ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),

                          SizedBox(height: 16),

                          // จำนวนวันที่เก็บคิวเก่า
                          Text(
                            'จำนวนวันที่เก็บคิวเก่า',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _oldBookingsDaysController,
                            decoration: InputDecoration(
                              hintText: 'ระบุจำนวนวัน',
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.deepOrange, width: 2),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'คิวที่เสร็จสิ้นหรือยกเลิกแล้วจะถูกลบหลังจากผ่านไปจำนวนวันที่กำหนด',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // ปุ่มทำความสะอาดทันที
                  Card(
                    elevation: 2,
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
                              Icon(Icons.timer, color: Colors.deepOrange),
                              SizedBox(width: 8),
                              Text(
                                'การทำงานทันที',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),

                          // ปุ่มทำความสะอาดทันที

                          SizedBox(height: 8),
                          Text(
                            'ทำความสะอาดคิวทันทีตามการตั้งค่าปัจจุบัน',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

// เพิ่มส่วนการจัดการค่าบริการ
                  Card(
                    elevation: 2,
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
                              Icon(Icons.attach_money,
                                  color: Colors.deepOrange),
                              SizedBox(width: 8),
                              Text(
                                'การจัดการค่าบริการ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'ปรับแต่งค่าบริการและค่าธรรมเนียมต่างๆ ของระบบ',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          ServiceFeeManagementPage()),
                                );
                              },
                              icon: Icon(Icons.settings),
                              label: Text('ไปยังหน้าจัดการค่าบริการ'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ปุ่มบันทึกการตั้งค่า
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: Icon(Icons.save),
                      label: Text('บันทึกการตั้งค่า'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
