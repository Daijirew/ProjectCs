import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myproject/page2.dart/_CatSearchPageState.dart';
import 'package:myproject/page2.dart/location/location.dart';
import 'package:myproject/page2.dart/showreviwe.dart';
import 'package:myproject/page2.dart/workdate/workdate.dart';
import 'package:myproject/pages.dart/booking/detail_page.dart';
import 'package:myproject/pages.dart/details.dart';
import 'package:myproject/pages.dart/matching/matching.dart';

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
          .doc('wVmQtidCCcRFbGevZcICnre9tPo2')
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
      backgroundColor: const Color(0xFFF5F5F5), // Soft grey background
      appBar: AppBar(
        title: Text(
          'Cat Sitter',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black38,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF6FDFDF), // Soft teal
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
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
              Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.teal[800],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Choose a task to start:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              _buildTaskSelector(),
              const SizedBox(height: 20),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchAdoptedCats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.teal[300]!),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading cats',
                        style: TextStyle(color: Colors.red[300]),
                      ),
                    );
                  } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return _buildCatCards(snapshot.data!);
                  } else {
                    return Center(
                      child: Text(
                        'No adopted cats found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
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
        _buildTaskItem('images/cat.png', 'Cat', cat, () {
          _updateTaskState(TaskType.cat);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CatSearchPage()),
          );
        }),
        _buildTaskItem('images/paw.png', 'Sitter', paw, () {
          _updateTaskState(TaskType.paw);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SitterReviewsPage()),
          );
        }),
        _buildTaskItem('images/backpack.png', 'Travel', backpack, () {
          _updateTaskState(TaskType.backpack);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AvailableDatesPage(),
            ),
          );
        }),
        _buildTaskItem('images/ball.png', 'Play', ball, () {
          _updateTaskState(TaskType.ball);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LocationMapPage(),
            ),
          );
        }),
      ],
    );
  }

  void _updateTaskState(TaskType type) {
    setState(() {
      cat = type == TaskType.cat;
      paw = type == TaskType.paw;
      backpack = type == TaskType.backpack;
      ball = type == TaskType.ball;
    });
  }

  Widget _buildTaskItem(
      String imagePath, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.teal[100] : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: isSelected ? Colors.teal : Colors.transparent,
                width: 2,
              ),
            ),
            child: Image.asset(
              imagePath,
              height: 50,
              width: 50,
              fit: BoxFit.contain,
              color: isSelected ? Colors.teal : Colors.black54,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.teal : Colors.black54,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
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
              MaterialPageRoute(builder: (context) => const Details()),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.grey[50]!,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: cat['imagePath'] != null && cat['imagePath'].isNotEmpty
                      ? Image.network(
                          cat['imagePath'],
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          'images/cat.png',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(
                        cat['name'] ?? 'Unknown Cat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        cat['breed'] ?? 'Unknown Breed',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum TaskType { cat, paw, backpack, ball }
