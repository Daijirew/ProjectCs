import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:myproject/Catpage.dart/CatEdid.dart';
import 'package:intl/intl.dart';
import 'cat.dart';

class CatDetailsPage extends StatefulWidget {
  final Cat cat;
  const CatDetailsPage({Key? key, required this.cat}) : super(key: key);

  @override
  State<CatDetailsPage> createState() => _CatDetailsPageState();
}

class _CatDetailsPageState extends State<CatDetailsPage> {
  late Cat currentCat;
  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    currentCat = widget.cat;
  }

  String _formatBirthDate(Timestamp? timestamp) {
    if (timestamp == null) return 'ไม่ระบุ';
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _calculateAge(Timestamp? birthDate) {
    if (birthDate == null) return 'ไม่ระบุ';
    DateTime now = DateTime.now();
    DateTime birth = birthDate.toDate();
    int years = now.year - birth.year;
    int months = now.month - birth.month;
    if (months < 0) {
      years--;
      months += 12;
    }
    return '$years ปี $months เดือน';
  }

  // เพิ่มฟังก์ชันแสดงกล่องยืนยันการลบ
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'ลบข้อมูลแมว',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.black87, fontSize: 16),
                  children: [
                    TextSpan(text: 'แน่ใจหรือไม่ว่าต้องการลบข้อมูลแมว '),
                    TextSpan(
                      text: currentCat.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    TextSpan(text: ' ?'),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'การลบข้อมูลนี้จะไม่สามารถกู้คืนได้',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(
                'ยกเลิก',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.delete_forever, color: Colors.white, size: 18),
              label: Text(
                'ลบข้อมูล',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                Navigator.pop(context);
                _deleteCat();
              },
            ),
          ],
        );
      },
    );
  }

// เพิ่มฟังก์ชันลบแมว
  void _deleteCat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ลบรูปภาพจาก Storage (ถ้ามี)
      if (currentCat.imagePath.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(currentCat.imagePath);
          await ref.delete();
        } catch (e) {
          print('Error deleting image: $e');
        }
      }

      // ลบข้อมูลจาก Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cats')
          .doc(currentCat.id)
          .delete();

      // แสดงข้อความสำเร็จและกลับไปหน้าก่อนหน้า
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบข้อมูลแมว ${currentCat.name} สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      // กรณีเกิดข้อผิดพลาด
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการลบ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. App Bar ที่มีภาพแมวเป็นพื้นหลัง
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'cat-${currentCat.id}',
                child: currentCat.imagePath.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            currentCat.imagePath,
                            fit: BoxFit.cover,
                          ),
                          // ไล่เฉดสีจากด้านล่างขึ้นบนเพื่อให้อ่านชื่อแมวได้ชัดเจน
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                                stops: const [0.7, 1.0],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        color: Colors.orange.shade200,
                        child: const Center(
                          child: Icon(
                            Icons.pets,
                            size: 100,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              title: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text(
                  currentCat.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit, color: Colors.white),
                ),
                onPressed: () async {
                  final updatedCat = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CatEditPage(cat: currentCat),
                    ),
                  );

                  if (updatedCat != null) {
                    setState(() {
                      currentCat = updatedCat;
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),

          // 2. สรุปข้อมูลสำคัญ (Info Summary)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryItem(
                          icon: Icons.cake,
                          title: 'อายุ',
                          value: _calculateAge(currentCat.birthDate),
                          color: Colors.pink.shade300,
                        ),
                      ),
                      Expanded(
                        child: _buildSummaryItem(
                          icon: Icons.category,
                          title: 'สายพันธุ์',
                          value: currentCat.breed,
                          color: Colors.purple.shade300,
                        ),
                      ),
                      Expanded(
                        child: _buildSummaryItem(
                          icon: Icons.medical_services,
                          title: 'วัคซีน',
                          value:
                              currentCat.vaccinations.isEmpty ? 'ไม่มี' : 'มี',
                          color: Colors.green.shade300,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. รายละเอียดแมว (Cat Details)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ข้อมูลแมว',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ข้อมูลแมว (สายพันธุ์)
                  _buildDetailCard(
                    icon: Icons.category,
                    iconColor: Colors.purple.shade400,
                    iconBackground: Colors.purple.shade50,
                    title: 'สายพันธุ์',
                    content: currentCat.breed,
                  ),

                  // วันเกิด
                  _buildDetailCard(
                    icon: Icons.cake,
                    iconColor: Colors.pink.shade400,
                    iconBackground: Colors.pink.shade50,
                    title: 'วันเกิด',
                    content: _formatBirthDate(currentCat.birthDate),
                  ),

                  // วัคซีน
                  _buildDetailCard(
                    icon: Icons.medical_services,
                    iconColor: Colors.green.shade400,
                    iconBackground: Colors.green.shade50,
                    title: 'วัคซีน',
                    content: currentCat.vaccinations.isEmpty
                        ? 'ไม่มีข้อมูลวัคซีน'
                        : currentCat.vaccinations,
                    isExpanded: isExpanded,
                    onTap: () {
                      if (currentCat.vaccinations.length > 30) {
                        setState(() {
                          isExpanded = !isExpanded;
                        });
                      }
                    },
                  ),

                  // คำอธิบาย
                  _buildDetailCard(
                    icon: Icons.description,
                    iconColor: Colors.blue.shade400,
                    iconBackground: Colors.blue.shade50,
                    title: 'คำอธิบาย',
                    content: currentCat.description.isEmpty
                        ? 'ไม่มีคำอธิบาย'
                        : currentCat.description,
                    isExpanded: isExpanded,
                    onTap: () {
                      if (currentCat.description.length > 100) {
                        setState(() {
                          isExpanded = !isExpanded;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. ส่วนปุ่มการจัดการแมว (ฝากเลี้ยง, นัดหาหมอ, ฯลฯ)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'การจัดการ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.home_work,
                          color: Colors.orange,
                          title: 'ฝากเลี้ยง',
                          onPressed: () {
                            // ฟังก์ชันการฝากเลี้ยง
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.medical_services,
                          color: Colors.teal,
                          title: 'นัดหาหมอ',
                          onPressed: () {
                            // ฟังก์ชันนัดหาหมอ
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.content_paste,
                          color: Colors.purple,
                          title: 'ตารางดูแล',
                          onPressed: () {
                            // ฟังก์ชันตารางดูแล
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.access_time,
                          color: Colors.indigo,
                          title: 'ประวัติแมว',
                          onPressed: () {
                            // ฟังก์ชันประวัติแมว
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // พื้นที่ว่างข้างล่าง
          SliverToBoxAdapter(
            child: SizedBox(height: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String content,
    bool isExpanded = false,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: isExpanded ? null : 3,
                      overflow: isExpanded ? null : TextOverflow.ellipsis,
                    ),
                    if (content.length > 100 && onTap != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          isExpanded ? 'แสดงน้อยลง' : 'อ่านเพิ่มเติม',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
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

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3), width: 1),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
