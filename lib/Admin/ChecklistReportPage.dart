import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/services/checklist_service.dart';
import 'package:fl_chart/fl_chart.dart';

class ChecklistReportPage extends StatefulWidget {
  const ChecklistReportPage({Key? key}) : super(key: key);

  @override
  _ChecklistReportPageState createState() => _ChecklistReportPageState();
}

class _ChecklistReportPageState extends State<ChecklistReportPage> {
  final ChecklistService _checklistService = ChecklistService();
  bool _isLoading = true;
  Map<String, dynamic> _statistics = {};
  List<Map<String, dynamic>> _topSitters = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    try {
      // โหลดข้อมูลสถิติเช็คลิสต์
      Map<String, dynamic> stats =
          await _checklistService.getChecklistStatistics();

      // โหลดข้อมูลการจัดอันดับผู้รับเลี้ยง
      List<Map<String, dynamic>> sitters = await _loadTopSitters();

      setState(() {
        _statistics = stats;
        _topSitters = sitters;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading report data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadTopSitters() async {
    try {
      // ดึงข้อมูลเช็คลิสต์ทั้งหมด
      QuerySnapshot checklistSnapshot = await FirebaseFirestore.instance
          .collection('checklists')
          .where('isCompleted', isEqualTo: true)
          .get();

      // นับจำนวนรายการที่เสร็จแล้วสำหรับแต่ละ sitterId
      Map<String, int> completedBySitter = {};

      for (var doc in checklistSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String sitterId = data['sitterId'] ?? '';

        if (sitterId.isNotEmpty) {
          completedBySitter[sitterId] = (completedBySitter[sitterId] ?? 0) + 1;
        }
      }

      // โหลดข้อมูลผู้รับเลี้ยง
      List<Map<String, dynamic>> sitters = [];

      for (var entry in completedBySitter.entries) {
        DocumentSnapshot sitterDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(entry.key)
            .get();

        if (sitterDoc.exists) {
          Map<String, dynamic> sitterData =
              sitterDoc.data() as Map<String, dynamic>;
          sitters.add({
            'id': sitterDoc.id,
            'name': sitterData['name'] ?? 'ไม่ระบุชื่อ',
            'photo': sitterData['photo'],
            'completedItems': entry.value,
          });
        }
      }

      // เรียงลำดับตามจำนวนรายการที่เสร็จแล้ว (มากไปน้อย)
      sitters
          .sort((a, b) => b['completedItems'].compareTo(a['completedItems']));

      // จำกัดจำนวนให้แสดงแค่ 5 อันดับแรก
      return sitters.take(5).toList();
    } catch (e) {
      print('Error loading top sitters: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('รายงานเช็คลิสต์'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadReportData,
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
                  // ส่วนหัวของรายงาน
                  Text(
                    'สรุปภาพรวมการทำเช็คลิสต์',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'รายงานสรุปประสิทธิภาพการทำเช็คลิสต์ของผู้รับเลี้ยงแมว',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 24),

                  // ส่วนสรุปข้อมูลสถิติ
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'การจองทั้งหมด',
                          _statistics['totalBookings']?.toString() ?? '0',
                          Icons.calendar_today,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'จำนวนเช็คลิสต์ทั้งหมด',
                          _statistics['totalChecklists']?.toString() ?? '0',
                          Icons.format_list_bulleted,
                          Colors.deepPurple,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'รายการที่เสร็จแล้ว',
                          _statistics['completedItems']?.toString() ?? '0',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // ส่วนแสดงอัตราการเสร็จสิ้น
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
                          Text(
                            'อัตราการทำเช็คลิสต์เสร็จสิ้น',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildProgressWithLabel(
                                  'รายการเช็คลิสต์',
                                  (_statistics['completionRate'] as double?) ??
                                      0.0,
                                  Colors.blue,
                                ),
                              ),
                              SizedBox(width: 20),
                              Expanded(
                                child: _buildProgressWithLabel(
                                  'การจองที่มีการทำเช็คลิสต์',
                                  (_statistics['bookingCompletionRate']
                                          as double?) ??
                                      0.0,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 32),

                  // ส่วนแสดงผู้รับเลี้ยงที่มีการทำเช็คลิสต์มากที่สุด
                  if (_topSitters.isNotEmpty) ...[
                    Text(
                      'ผู้รับเลี้ยงแมวที่มีการทำเช็คลิสต์มากที่สุด',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    ..._topSitters.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> sitter = entry.value;
                      return _buildSitterRankingItem(sitter, index + 1);
                    }),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
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
                Icon(icon, color: color, size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressWithLabel(String label, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${(progress * 100).toInt()}%',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.2),
            color: color,
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildSitterRankingItem(Map<String, dynamic> sitter, int rank) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getRankColor(rank),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            CircleAvatar(
              radius: 24,
              backgroundImage: sitter['photo'] != null &&
                      sitter['photo'].toString().isNotEmpty
                  ? NetworkImage(sitter['photo'])
                  : null,
              child:
                  sitter['photo'] == null || sitter['photo'].toString().isEmpty
                      ? Icon(Icons.person)
                      : null,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sitter['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'รหัส: ${sitter['id'].substring(0, 8)}...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  sitter['completedItems'].toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'รายการที่เสร็จ',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade700; // สีทอง
      case 2:
        return Colors.grey.shade400; // สีเงิน
      case 3:
        return Colors.brown.shade300; // สีทองแดง
      default:
        return Colors.blue.shade400; // สีสำหรับอันดับอื่นๆ
    }
  }
}
