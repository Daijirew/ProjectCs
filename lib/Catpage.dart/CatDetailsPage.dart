import 'package:flutter/material.dart';
import 'package:myproject/Catpage.dart/CatEdid.dart';
import 'cat.dart';

class CatDetailsPage extends StatelessWidget {
  final Cat cat;

  const CatDetailsPage({Key? key, required this.cat}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ปรับ AppBar ให้ดูทันสมัยขึ้น
      appBar: AppBar(
        title: Text(
          '${cat.name}\'s Profile',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.orange.shade400,
        elevation: 0, // ลบเงา
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CatEditPage(cat: cat),
                ),
              );

              // TODO: เพิ่มฟังก์ชันแก้ไขข้อมูลแมว
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade200, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ส่วนแสดงรูปภาพ
              Container(
                height: 300,
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                child: Hero(
                  tag: 'cat-${cat.name}',
                  child: cat.imagePath.isNotEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Image.network(
                              cat.imagePath,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Icon(
                            Icons.pets,
                            size: 80,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),

              // ส่วนแสดงข้อมูล
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        Icons.pets,
                        'Name',
                        cat.name,
                        Colors.orange.shade400,
                      ),
                      const SizedBox(height: 20),
                      _buildInfoRow(
                        Icons.category,
                        'Breed',
                        cat.breed,
                        Colors.orange.shade400,
                      ),
                      const SizedBox(height: 20),
                      _buildInfoRow(
                        Icons.cake,
                        'Birthday',
                        cat.birthDate?.toDate().toString().split(' ')[0] ??
                            'Unknown',
                        Colors.orange.shade400,
                      ),
                    ],
                  ),
                ),
              ),

              // เพิ่มปุ่มดำเนินการ
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      Icons.medical_services,
                      'Health Records',
                      () {
                        // TODO: นำไปยังหน้าประวัติสุขภาพ
                      },
                    ),
                    _buildActionButton(
                      Icons.calendar_today,
                      'Schedule',
                      () {
                        // TODO: นำไปยังหน้าตารางนัด
                      },
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

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.orange.shade400),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.orange.shade400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
