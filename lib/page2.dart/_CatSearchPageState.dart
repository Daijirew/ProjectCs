import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myproject/Catpage.dart/cat.dart';

class CatSearchPage extends StatefulWidget {
  const CatSearchPage({Key? key}) : super(key: key);

  @override
  _CatSearchPageState createState() => _CatSearchPageState();
}

class _CatSearchPageState extends State<CatSearchPage> {
  List<Cat> cats = [];
  List<Cat> filteredCats = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  // ฟังก์ชันโหลดแมวจาก Firestore
  Future<void> _loadCats() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(
              'izpM2XvdqJW4odaugUa2f2a9TTZ2') // ใส่ user_id ของผู้ใช้ที่ต้องการดึงข้อมูล
          .collection('cats')
          .get();

      setState(() {
        cats = snapshot.docs
            .map((doc) =>
                Cat.fromFirestore(doc)) // แปลงจาก DocumentSnapshot เป็น Cat
            .toList();
        filteredCats = cats;
      });
    } catch (e) {
      print("Error loading cats: $e");
    }
  }

  // ฟังก์ชันค้นหาแมว
  void _searchCats(String query) {
    setState(() {
      searchQuery = query;
      filteredCats = cats
          .where((cat) => cat.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Cats',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        elevation: 5,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 3,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: TextField(
                onChanged: _searchCats,
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: const Icon(Icons.search, color: Colors.teal),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 15.0, horizontal: 20.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredCats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.search_off, size: 80, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'ไม่พบผลลัพธ์',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredCats.length,
                    itemBuilder: (context, index) {
                      final cat = filteredCats[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        elevation: 3,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12.0),
                          title: Text(
                            cat.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.0,
                            ),
                          ),
                          subtitle: Text(
                            cat.breed,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          leading: CircleAvatar(
                            radius: 30,
                            backgroundImage: cat.imagePath.isNotEmpty
                                ? NetworkImage(cat.imagePath)
                                : const AssetImage('images/default_cat.png')
                                    as ImageProvider,
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.teal),
                          onTap: () {
                            // กำหนด action เมื่อคลิกที่แมว
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8F9FA),
    );
  }
}
