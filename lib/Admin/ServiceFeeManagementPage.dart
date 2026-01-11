import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ServiceFeeManagementPage extends StatefulWidget {
  const ServiceFeeManagementPage({Key? key}) : super(key: key);

  @override
  _ServiceFeeManagementPageState createState() =>
      _ServiceFeeManagementPageState();
}

class _ServiceFeeManagementPageState extends State<ServiceFeeManagementPage> {
  bool _isLoading = true;
  Map<String, dynamic> _serviceFees = {};
  final Map<String, TextEditingController> _controllers = {};
  String _errorMessage = '';
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadServiceFees();
  }

  Future<void> _loadServiceFees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // ดึงข้อมูลจาก collection 'admin/service_fees'
      DocumentSnapshot feeDoc = await FirebaseFirestore.instance
          .collection('admin')
          .doc('service_fees')
          .get();

      // ถ้าไม่มีข้อมูล ให้ใช้ค่าเริ่มต้น
      if (!feeDoc.exists) {
        _serviceFees = {
          'baseFee': 100.0,
          'commissionRate': 10.0,
          'extraCatFee': 50.0,
          'taxRate': 7.0,
          'cancellationFee': 50.0,
        };

        // สร้างเอกสารใหม่ด้วยค่าเริ่มต้น
        await FirebaseFirestore.instance
            .collection('admin')
            .doc('service_fees')
            .set(_serviceFees);

        // สร้างเอกสารใหม่ในคอลเลคชัน service_fees ด้วย
        await FirebaseFirestore.instance
            .collection('service_fees')
            .doc('default')
            .set(_serviceFees);
      } else {
        _serviceFees = feeDoc.data() as Map<String, dynamic>;
      }

      // สร้าง controllers สำหรับแต่ละฟิลด์
      _serviceFees.forEach((key, value) {
        _controllers[key] = TextEditingController(
            text: value is double ? value.toString() : value.toString());
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading service fees: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'เกิดข้อผิดพลาดในการโหลดข้อมูล: $e';
      });
    }
  }

  Future<void> _saveServiceFees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // แปลงข้อมูลจาก controllers เป็น Map
      Map<String, dynamic> updatedFees = {};

      _controllers.forEach((key, controller) {
        // แปลงข้อความเป็น double
        double? value = double.tryParse(controller.text);
        if (value != null) {
          updatedFees[key] = value;
        } else {
          throw Exception('ค่า $key ไม่ถูกต้อง');
        }
      });

      // อัพเดทข้อมูลลง Firestore
      await FirebaseFirestore.instance
          .collection('admin')
          .doc('service_fees')
          .set(updatedFees, SetOptions(merge: true));

      // อัพเดทข้อมูลใน service_fees/default ด้วย
      await FirebaseFirestore.instance
          .collection('service_fees')
          .doc('default')
          .set(updatedFees, SetOptions(merge: true));

      print('Service fees saved successfully: $updatedFees');

      // รีเซ็ตแคชในตัวคำนวณค่าบริการ (ถ้ามี)
      try {
        await FirebaseFirestore.instance
            .collection('system')
            .doc('cache')
            .set({'serviceFeeLastUpdated': FieldValue.serverTimestamp()});
      } catch (e) {
        print('Note: Failed to update cache timestamp: $e');
      }

      // อัพเดทค่าในตัวแปร _serviceFees
      setState(() {
        _serviceFees = Map.from(updatedFees);
        _hasChanges = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกการตั้งค่าเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving service fees: $e');
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $_errorMessage'),
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
  void dispose() {
    // ล้าง controllers เมื่อออกจากหน้านี้
    _controllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการค่าบริการ'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveServiceFees,
            tooltip: 'บันทึกการเปลี่ยนแปลง',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadServiceFees,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // หัวข้อและคำอธิบาย
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.deepOrange),
                              SizedBox(width: 8),
                              Text(
                                'ข้อมูลการตั้งค่า',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'การเปลี่ยนแปลงค่าบริการจะมีผลกับการจองใหม่เท่านั้น ไม่มีผลกับการจองที่มีอยู่แล้ว',
                            style: TextStyle(
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // แสดงข้อผิดพลาด (ถ้ามี)
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ฟอร์มค่าบริการ
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.paid, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'ค่าบริการพื้นฐาน',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),

                          // สร้าง input fields สำหรับแต่ละค่าบริการ
                          _buildFeeTextField(
                            'ค่าบริการพื้นฐาน (บาท/วัน)',
                            'baseFee',
                            Icons.home,
                          ),
                          _buildFeeTextField(
                            'ค่าคอมมิชชั่น (%)',
                            'commissionRate',
                            Icons.account_balance,
                          ),
                          _buildFeeTextField(
                            'ค่าธรรมเนียมแมวเพิ่ม (บาท/ตัว)',
                            'extraCatFee',
                            Icons.pets,
                          ),
                          _buildFeeTextField(
                            'ภาษีมูลค่าเพิ่ม (%)',
                            'taxRate',
                            Icons.receipt,
                          ),
                          _buildFeeTextField(
                            'ค่าธรรมเนียมการยกเลิก (บาท)',
                            'cancellationFee',
                            Icons.cancel,
                          ),

                          // เพิ่มฟิลด์อื่นๆ ตามต้องการ
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // ปุ่มบันทึก
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveServiceFees, // ปรับให้สามารถกดปุ่มได้เสมอ
                      icon: Icon(Icons.save),
                      label: Text('บันทึกการเปลี่ยนแปลง'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFeeTextField(String label, String key, IconData icon) {
    // ถ้าไม่มี controller สำหรับ key นี้ จะข้ามไป
    if (!_controllers.containsKey(key)) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: _controllers[key],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.deepOrange, width: 2),
          ),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        onChanged: (value) {
          // ตรวจสอบว่ามีการเปลี่ยนแปลงค่าหรือไม่
          double? newValue = double.tryParse(value);
          double? oldValue = _serviceFees[key] is double
              ? _serviceFees[key]
              : double.tryParse(_serviceFees[key].toString());

          print('Key: $key, New Value: $newValue, Old Value: $oldValue');

          setState(() {
            if (newValue != oldValue) {
              _hasChanges = true;
            }
          });
        },
      ),
    );
  }
}
