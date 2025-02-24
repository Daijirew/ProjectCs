import 'package:flutter/material.dart';
import 'package:myproject/Catpage.dart/cat_history.dart';
import 'package:myproject/page2.dart/_CatSearchPageState.dart';
import 'package:myproject/page2.dart/workdate/workdate.dart';
import 'package:myproject/pages.dart/details.dart';

class Home2 extends StatefulWidget {
  const Home2({super.key});

  @override
  State<Home2> createState() => _Home2State();
}

class _Home2State extends State<Home2> {
  bool cat = false, paw = false, backpack = false, ball = false;

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

              // เพิ่มปุ่มเพื่อไปที่หน้า CatSearchPage
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CatSearchPage()),
                  );
                },
                child: const Text('Search Cats'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal, // สีของปุ่ม
                ),
              ),

              const SizedBox(height: 20),
              _buildCatCards(),
            ],
          ),
        ),
      ),
    );
  }

  // ฟังก์ชั่นที่ใช้เลือก task
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
            MaterialPageRoute(builder: (context) => AvailableDatesPage()),
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

  Widget _buildCatCards() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Details()),
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
                  Image.asset('images/cat.png', height: 100, fit: BoxFit.cover),
                  const SizedBox(height: 10),
                  const Text(
                    'John Terry House',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Total Cats: 5',
                    style: TextStyle(color: Colors.grey),
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
