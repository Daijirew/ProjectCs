import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    final records = await _attendanceService.getAttendanceRecords();
    // เรียงข้อมูลตามวันที่ล่าสุด
    records.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  // แก้ไขฟังก์ชันลบประวัติ
  Future<void> _deleteRecord(String recordId) async {
    // แสดงกล่องยืนยันการลบ
    bool confirm =
        await _showDeleteConfirmDialog('คุณต้องการลบรายการนี้ใช่หรือไม่?');

    if (confirm) {
      setState(() {
        _isLoading = true;
      });

      bool success = await _attendanceService.deleteRecord(recordId);

      // อัปเดตหน้าจอ
      if (success) {
        // ลบข้อมูลออกจาก records โดยตรง
        setState(() {
          _records.removeWhere((record) => record.id == recordId);
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ลบรายการสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการลบรายการ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// แก้ไขฟังก์ชันลบประวัติทั้งหมด
  Future<void> _deleteAllRecords() async {
    // แสดงกล่องยืนยันการลบทั้งหมด
    bool confirm = await _showDeleteConfirmDialog(
        'คุณต้องการลบประวัติทั้งหมดใช่หรือไม่?\nการกระทำนี้ไม่สามารถเรียกคืนได้',
        isDangerous: true);

    if (confirm) {
      setState(() {
        _isLoading = true;
      });

      bool success = await _attendanceService.deleteAllRecords();

      setState(() {
        if (success) {
          // ล้างข้อมูลโดยตรง
          _records.clear();
        }
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'ลบประวัติทั้งหมดสำเร็จ'
              : 'เกิดข้อผิดพลาดในการลบประวัติ'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // เพิ่มฟังก์ชันลบประวัติทั้งหมด

  // ฟังก์ชันแสดงกล่องยืนยันการลบ
  Future<bool> _showDeleteConfirmDialog(String message,
      {bool isDangerous = false}) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.delete,
                  color: isDangerous ? Colors.red : Colors.orange,
                ),
                SizedBox(width: 10),
                Text('ยืนยันการลบ'),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'ยกเลิก',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDangerous ? Colors.red : const Color(0xFFF57C00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('ลบ'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF57C00),
        elevation: 0,
        title: Text(
          'ประวัติการดูแลแมว',
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
        // เพิ่มปุ่มลบทั้งหมดใน AppBar
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.white),
              onPressed: _deleteAllRecords,
              tooltip: 'ลบประวัติทั้งหมด',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 70,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 20),
                      Text(
                        'ไม่พบประวัติการเช็คอิน/เช็คเอาท์',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : _buildRecordsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadRecords,
        backgroundColor: const Color(0xFFF57C00),
        child: Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildRecordsList() {
    // จัดกลุ่มข้อมูลตามวันที่
    Map<String, List<AttendanceRecord>> groupedRecords = {};

    for (var record in _records) {
      final dateStr = DateFormat('yyyy-MM-dd').format(record.date);
      if (!groupedRecords.containsKey(dateStr)) {
        groupedRecords[dateStr] = [];
      }
      groupedRecords[dateStr]!.add(record);
    }

    // สร้างตัวแปรเก็บรายการล่าสุดที่สุด
    String latestRecordId = _records.isNotEmpty ? _records.first.id : "";

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: groupedRecords.length,
      itemBuilder: (context, index) {
        final dateStr = groupedRecords.keys.elementAt(index);
        final records = groupedRecords[dateStr]!;
        final date = DateFormat('yyyy-MM-dd').parse(dateStr);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                DateFormat('d MMMM yyyy', 'th_TH').format(date),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF57C00),
                ),
              ),
            ),
            ...records
                .map((record) =>
                    _buildRecordCard(record, record.id == latestRecordId))
                .toList(),
            Divider(thickness: 1),
          ],
        );
      },
    );
  }

  Widget _buildRecordCard(AttendanceRecord record, bool isLatest) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          // ถ้าเป็นรายการล่าสุด แสดงแบนเนอร์ "ล่าสุด"
          if (isLatest)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(15),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                child: Text(
                  'ล่าสุด',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // เพิ่มปุ่มลบในหัวข้อการ์ด
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                      onPressed: () => _deleteRecord(record.id),
                      tooltip: 'ลบรายการนี้',
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                // แสดงรูปภาพถ้ามี
                if (record.imagePath != null && record.imagePath!.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showFullImage(record.imagePath!),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(File(record.imagePath!)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                // แสดงเวลาเช็คอิน/เช็คเอาท์
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'เช็คอิน',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          record.checkInTime.format(context),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'เช็คเอาท์',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          record.checkOutTime?.format(context) ?? '--:--',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: record.checkOutTime != null
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // แสดงบันทึกถ้ามี
                if (record.note != null && record.note!.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 16),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'บันทึก:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          record.note!,
                          style: TextStyle(
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: FileImage(File(imagePath)),
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}
