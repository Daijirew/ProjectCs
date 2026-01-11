import 'package:flutter/material.dart';
import 'package:myproject/models/simple_checklist_model.dart';
import 'package:myproject/services/simple_checklist_service.dart';
import 'package:intl/intl.dart';

class SimpleSitterChecklistPage extends StatefulWidget {
  final String bookingId;

  const SimpleSitterChecklistPage({
    Key? key,
    required this.bookingId,
  }) : super(key: key);

  @override
  _SimpleSitterChecklistPageState createState() =>
      _SimpleSitterChecklistPageState();
}

class _SimpleSitterChecklistPageState extends State<SimpleSitterChecklistPage> {
  final SimpleChecklistService _checklistService = SimpleChecklistService();
  bool _isLoading = true;
  List<SimpleChecklistItem> _checklistItems = [];
  List<Map<String, dynamic>> _cats = [];
  String? _selectedCatId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ดึงข้อมูลแมวสำหรับการจอง
      List<Map<String, dynamic>> cats =
          await _checklistService.getCatsForBooking(widget.bookingId);

      // ดึงเช็คลิสต์สำหรับการจอง
      List<SimpleChecklistItem> items =
          await _checklistService.getChecklistForBooking(widget.bookingId);

      // ถ้าไม่มีเช็คลิสต์ให้สร้างใหม่
      if (items.isEmpty) {
        bool created =
            await _checklistService.createChecklistForBooking(widget.bookingId);
        if (created) {
          items =
              await _checklistService.getChecklistForBooking(widget.bookingId);
        }
      }

      setState(() {
        _cats = cats;
        _checklistItems = items;
        if (cats.isNotEmpty && _selectedCatId == null) {
          _selectedCatId = cats.first['id'];
        }
        _isLoading = false;
      });
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('เกิดข้อผิดพลาดในการโหลดข้อมูล กรุณาลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _toggleChecklistItem(SimpleChecklistItem item) async {
    try {
      bool success = await _checklistService.updateChecklistStatus(
          item.id, !item.isCompleted);
      if (success) {
        setState(() {
          item.isCompleted = !item.isCompleted;
          item.completedAt = item.isCompleted ? DateTime.now() : null;
        });
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการอัปเดตสถานะ: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('เกิดข้อผิดพลาดในการอัปเดตสถานะ กรุณาลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('เช็คลิสต์การดูแลแมว'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ส่วนเลือกแมว
                _buildCatSelector(),

                // ส่วนแสดงเช็คลิสต์
                Expanded(
                  child: _selectedCatId != null
                      ? _buildChecklistForCat(_selectedCatId!)
                      : Center(
                          child: Text('กรุณาเลือกแมว'),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCatSelector() {
    if (_cats.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('ไม่พบข้อมูลแมวสำหรับการจองนี้'),
        ),
      );
    }

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
                  color: isSelected ? Colors.teal : Colors.grey.shade300,
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

  Widget _buildChecklistForCat(String catId) {
    // กรองรายการเฉพาะแมวที่เลือก
    List<SimpleChecklistItem> filteredItems =
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
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              child: Text('โหลดข้อมูลใหม่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];

        return Card(
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: CheckboxListTile(
            title: Text(
              item.task,
              style: TextStyle(
                decoration:
                    item.isCompleted ? TextDecoration.lineThrough : null,
                color: item.isCompleted ? Colors.grey : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: item.completedAt != null
                ? Text(
                    'เสร็จเมื่อ: ${DateFormat('dd/MM/yyyy HH:mm').format(item.completedAt!)}',
                    style: TextStyle(fontSize: 12),
                  )
                : null,
            value: item.isCompleted,
            onChanged: (value) {
              _toggleChecklistItem(item);
            },
            activeColor: Colors.teal,
            checkColor: Colors.white,
            controlAffinity: ListTileControlAffinity.leading,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}
