import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:myproject/Catpage.dart/CatRegistrationPage.dart';
import 'package:myproject/Catpage.dart/cat.dart';
import 'CatDetailsPage.dart';

class CatHistoryPage extends StatefulWidget {
  const CatHistoryPage({Key? key}) : super(key: key);

  @override
  _CatHistoryPageState createState() => _CatHistoryPageState();
}

class _CatHistoryPageState extends State<CatHistoryPage> {
  List<Cat> cats = [];
  List<Cat> filteredCats = [];
  bool isLoading = true;
  final searchController = TextEditingController();
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    loadCats();
  }

  Future<void> loadCats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        setState(() {
          isLoading = true;
        });

        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cats')
            .snapshots()
            .listen((snapshot) {
          setState(() {
            cats = snapshot.docs.map((doc) => Cat.fromFirestore(doc)).toList();
            filteredCats = cats;
            isLoading = false;
          });
        }, onError: (error) {
          print("Error: $error");
          setState(() {
            isLoading = false;
          });
        });
      }
    } catch (e) {
      print("Exception: $e");
      setState(() {
        isLoading = false;
      });
    }
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

  void _filterCats(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredCats = cats;
      } else {
        filteredCats = cats
            .where((cat) =>
                cat.name.toLowerCase().contains(query.toLowerCase()) ||
                cat.breed.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _showDeleteDialog(BuildContext context, Cat cat) {
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
                      text: cat.name,
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
              onPressed: () async {
                Navigator.pop(context);
                await _deleteCat(cat);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCat(Cat cat) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() {
        isLoading = true;
      });

      // Delete image from Storage if exists
      if (cat.imagePath.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(cat.imagePath);
          await ref.delete();
        } catch (e) {
          print('Error deleting image: $e');
        }
      }

      // Delete data from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cats')
          .doc(cat.id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบข้อมูลแมว ${cat.name} สำเร็จ'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'ปิด',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar ที่ทำงานแบบ Sliver
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.orange,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'แมวของฉัน',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.orange.shade400,
                      Colors.orange.shade700,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 50),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      'รายการแมวทั้งหมด ${filteredCats.length} ตัว',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: IconButton(
                  icon:
                      const Icon(Icons.add_circle_outline, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CatRegistrationPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // ช่องค้นหา
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                onChanged: _filterCats,
                decoration: InputDecoration(
                  hintText: 'ค้นหาแมว...',
                  prefixIcon: Icon(Icons.search, color: Colors.orange),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            searchController.clear();
                            _filterCats('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // รายการแมว
          isLoading
              ? SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  ),
                )
              : filteredCats.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pets,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              searchController.text.isNotEmpty
                                  ? 'ไม่พบแมวที่ค้นหา'
                                  : 'คุณยังไม่มีแมว',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            if (searchController.text.isNotEmpty)
                              Text(
                                'ลองค้นหาด้วยคำอื่น',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                icon: Icon(Icons.add),
                                label: Text('เพิ่มแมวตัวแรก'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CatRegistrationPage(),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final cat = filteredCats[index];
                            return _buildCatCard(context, cat);
                          },
                          childCount: filteredCats.length,
                        ),
                      ),
                    ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CatRegistrationPage(),
            ),
          );
        },
        backgroundColor: Colors.orange.shade700,
        child: Icon(Icons.add_circle_outline, color: Colors.white),
        tooltip: 'เพิ่มแมว',
      ),
    );
  }

  Widget _buildCatCard(BuildContext context, Cat cat) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CatDetailsPage(cat: cat),
          ),
        );
      },
      onLongPress: () {
        _showDeleteDialog(context, cat);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // รูปภาพแมว
              Stack(
                children: [
                  Hero(
                    tag: 'cat-${cat.name}',
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      child: cat.imagePath.isNotEmpty
                          ? Image.network(
                              cat.imagePath,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.orange.shade300,
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.pets,
                                  size: 50,
                                  color: Colors.grey[400],
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.pets,
                                size: 50,
                                color: Colors.grey[400],
                              ),
                            ),
                    ),
                  ),
                  // ไอคอนวัคซีน
                  if (cat.vaccinations.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.medical_services,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'วัคซีน',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // วันเกิด/อายุ
                  if (cat.birthDate != null)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      left: 0,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                            stops: [0.0, 1.0],
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cake,
                              size: 12,
                              color: Colors.orange[100],
                            ),
                            SizedBox(width: 4),
                            Text(
                              _calculateAge(cat.birthDate),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // ข้อมูลแมว
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.favorite,
                            size: 18,
                            color: Colors.red[300],
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        cat.breed,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Spacer(),
                      // คำอธิบาย
                      if (cat.description.isNotEmpty)
                        Text(
                          cat.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
