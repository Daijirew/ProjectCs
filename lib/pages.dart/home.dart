import 'package:flutter/material.dart';
import 'package:myproject/Catpage.dart/cat_history.dart';
import 'package:myproject/page2.dart/location/location.dart';
import 'package:myproject/pages.dart/PrepareCatsForSittingPage.dart';
import 'package:myproject/pages.dart/details.dart';
import 'package:myproject/pages.dart/matching/matching.dart';
import 'package:myproject/pages.dart/reviwe.dart';
import 'package:myproject/widget/widget_support.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<Home> {
  bool cat = false, paw = false, backpack = false, ball = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.orange.shade50, Colors.white],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 30),
                    Text('Cat', style: AppWidget.HeadlineTextFeildStyle()),
                    Text('Pet take care',
                        style: AppWidget.LightTextFeildStyle()),
                    const SizedBox(height: 20),
                    _buildQuickActions(),
                    const SizedBox(height: 30),
                    Text('Recent Customers',
                        style: AppWidget.semiboldTextFeildStyle()),
                    const SizedBox(height: 15),
                    _buildCustomerCards(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Cat Sitter',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]),
            child: const Icon(Icons.home, color: Colors.white),
          )
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionItem('images/cat.png', cat, () {
          setState(() {
            cat = true;
            paw = backpack = ball = false;
          });
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CatHistoryPage()),
          );
        }, 'แมวของคุณ'),
        _buildActionItem('images/paw.png', paw, () {
          setState(() {
            paw = true;
            cat = backpack = ball = false;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ReviewsPage(
                itemId: 'booking_id',
                sitterId: '/ sitters_id',
              ),
            ),
          );
        }, 'รีวิว'),
        _buildActionItem('images/backpack.png', backpack, () {
          setState(() {
            backpack = true;
            cat = paw = ball = false;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SelectTargetDateScreen(onDateSelected: (selectedDate) {}),
            ),
          );
        }, 'จองบริการ'),
        _buildActionItem('images/ball.png', ball, () {
          setState(() {
            ball = true;
            cat = paw = backpack = false;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LocationMapPage(),
            ),
          );
        }, 'ตำแหน่ง'),
      ],
    );
  }

  Widget _buildActionItem(
      String image, bool isSelected, VoidCallback onTap, String label) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.orange : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
              border: Border.all(
                color: isSelected ? Colors.orange : Colors.orange.shade100,
                width: 1.5,
              ),
            ),
            child: Image.asset(
              image,
              height: 45,
              width: 45,
              color: isSelected ? Colors.white : Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.orange.shade700 : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCards() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // เพิ่มปุ่มเตรียมแมวสำหรับฝากเลี้ยง
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrepareCatsForSittingPage(),
                  ),
                );
              },
              icon: const Icon(Icons.pets, color: Colors.white),
              label: const Text(
                'เตรียมแมวสำหรับฝากเลี้ยง',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 3,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCustomerCard('John Terry House', 5),
                const SizedBox(width: 15),
                _buildCustomerCard('Sarah Johnson House', 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(String name, int cats) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => const Details()));
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
          border: Border.all(
            color: Colors.orange.shade100,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Image.asset(
                'images/cat.png',
                height: 100,
                width: 100,
                fit: BoxFit.contain,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pet of your customer house',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: AppWidget.LightTextFeildStyle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.pets,
                  size: 16,
                  color: Colors.orange.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  'Total cat $cats',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
