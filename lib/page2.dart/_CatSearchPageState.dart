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
              'wVmQtidCCcRFbGevZcICnre9tPo2') // ใส่ user_id ของผู้ใช้ที่ต้องการดึงข้อมูล
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
        title: const Text('Search Cats'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _searchCats,
              decoration: InputDecoration(
                labelText: 'Search by name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredCats.isEmpty
                ? Center(child: Text('ไม่พบผลลัพธ์'))
                : ListView.builder(
                    itemCount: filteredCats.length,
                    itemBuilder: (context, index) {
                      final cat = filteredCats[index];
                      return ListTile(
                        title: Text(cat.name),
                        subtitle: Text(cat.breed),
                        leading: cat.imagePath.isNotEmpty
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(cat.imagePath),
                              )
                            : null,
                        onTap: () {
                          // กำหนด action เมื่อคลิกที่แมว
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
