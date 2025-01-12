import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myproject/page2.dart/_CatSearchPageState.dart';
import 'package:myproject/page2.dart/showreviwe.dart';
import 'package:myproject/pages.dart/details.dart';

class Home2 extends StatefulWidget {
  const Home2({super.key});

  @override
  State<Home2> createState() => _Home2State();
}

class _Home2State extends State<Home2> {
  bool cat = false, paw = false, backpack = false, ball = false;

  Future<List<Map<String, dynamic>>> _fetchAdoptedCats() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc('wVmQtidCCcRFbGevZcICnre9tPo2') // ใช้ user UID
          .collection('cats')
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching adopted cats: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text(
          'Cat Sitter',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome Back!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose a task to start:',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildTaskSelector(),
              const SizedBox(height: 20),
              FutureBuilder<List<Map<String, dynamic>>>(
                // ดึงข้อมูลแมวที่เพิ่มใหม่
                future: _fetchAdoptedCats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const Center(child: Text('Error loading cats'));
                  } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return _buildCatCards(snapshot.data!);
                  } else {
                    return const Center(child: Text('No adopted cats found'));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTaskItem('images/cat.png', cat, () {
          setState(() {
            cat = true;
            paw = false;
            backpack = false;
            ball = false;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CatSearchPage(), // เปลี่ยนหน้าไป CatSearchPage
            ),
          );
        }),
        _buildTaskItem('images/paw.png', paw, () {
          setState(() {
            cat = false;
            paw = true;
            backpack = false;
            ball = false;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SitterReviewsPage(),
            ),
          );
        }),
        _buildTaskItem('images/backpack.png', backpack, () {
          setState(() {
            cat = false;
            paw = false;
            backpack = true;
            ball = false;
          });
        }),
        _buildTaskItem('images/ball.png', ball, () {
          setState(() {
            cat = false;
            paw = false;
            backpack = false;
            ball = true;
          });
        }),
      ],
    );
  }

  Widget _buildTaskItem(String imagePath, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Image.asset(
            imagePath,
            height: 50,
            width: 50,
            fit: BoxFit.cover,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildCatCards(List<Map<String, dynamic>> catData) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: catData.length,
      itemBuilder: (context, index) {
        final cat = catData[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const Details()), // เปิดหน้า Details
            );
          },
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  cat['imagePath'] != null && cat['imagePath'].isNotEmpty
                      ? Image.network(
                          cat['imagePath'],
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : Image.asset('images/cat.png',
                          height: 100, fit: BoxFit.cover),
                  const SizedBox(height: 10),
                  Text(
                    cat['name'] ?? 'Unknown Cat',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    cat['breed'] ?? 'Unknown Breed',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
