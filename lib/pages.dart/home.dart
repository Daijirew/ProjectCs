import 'package:flutter/material.dart';
import 'package:myproject/Catpage.dart/cat_history.dart';
import 'package:myproject/pages.dart/details.dart';
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
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 30),
                  Text('Cat', style: AppWidget.HeadlineTextFeildStyle()),
                  Text('Pet take care', style: AppWidget.LightTextFeildStyle()),
                  const SizedBox(height: 20),
                  _buildQuickActions(),
                  const SizedBox(height: 30),
                  Text('Recent Customers',
                      style: AppWidget.semiboldTextFeildStyle()),
                  const SizedBox(height: 15),
                  _buildCustomerCards(),
                ],
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
          const Text('Cat Sitter',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              )),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
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
        }),
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
                sitterId: 'qMiu4Jh11Mbj5vzV3YEi23qp0Kv1',
              ),
            ),
          );
        }),
        _buildActionItem('images/backpack.png', backpack, () {
          setState(() {
            backpack = true;
            cat = paw = ball = false;
          });
        }),
        _buildActionItem('images/ball.png', ball, () {
          setState(() {
            ball = true;
            cat = paw = backpack = false;
          });
        }),
      ],
    );
  }

  Widget _buildActionItem(String image, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: isSelected ? Colors.teal : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 3),
              )
            ]),
        child: Image.asset(
          image,
          height: 45,
          width: 45,
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildCustomerCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCustomerCard('John Terry House', 5),
          const SizedBox(width: 15),
          _buildCustomerCard('Sarah Johnson House', 3),
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
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 3),
              )
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'images/cat.png',
              height: 120,
              width: 120,
              fit: BoxFit.contain,
              color: Colors.black,
            ),
            const SizedBox(height: 10),
            Text('Pet of your customer house',
                style: AppWidget.semiboldTextFeildStyle()),
            const SizedBox(height: 8),
            Text(name, style: AppWidget.LightTextFeildStyle()),
            const SizedBox(height: 8),
            Text('Total cat $cats', style: AppWidget.semiboldTextFeildStyle()),
          ],
        ),
      ),
    );
  }
}
