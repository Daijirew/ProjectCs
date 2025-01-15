import 'package:flutter/material.dart';
import 'package:myproject/Catpage.dart/cat_history.dart';
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
      body: Container(
        margin: const EdgeInsets.only(top: 50, left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cat Sitter', style: AppWidget.boldTextFeildStyle()),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.home,
                    color: Colors.white,
                  ),
                )
              ],
            ),
            const SizedBox(height: 30),
            Text('Cat', style: AppWidget.HeadlineTextFeildStyle()),
            Text('Pet take care', style: AppWidget.LightTextFeildStyle()),
            const SizedBox(height: 20),
            showItem(),
            const SizedBox(height: 30),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Details()));
                    },
                    child: Container(
                      margin: const EdgeInsets.all(5),
                      child: Material(
                        elevation: 5,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Image.asset(
                                    'images/cat.png',
                                    height: 120,
                                    width: 120,
                                    fit: BoxFit.cover,
                                    color: Colors.black,
                                  ),
                                  Text('Pet of your customer house',
                                      style:
                                          AppWidget.semiboldTextFeildStyle()),
                                  const SizedBox(height: 10),
                                  Text('John Terry House',
                                      style: AppWidget.LightTextFeildStyle()),
                                  const SizedBox(height: 10),
                                  Text('Total cat 5',
                                      style:
                                          AppWidget.semiboldTextFeildStyle()),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    margin: const EdgeInsets.all(5),
                    child: Material(
                      elevation: 5,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Image.asset(
                                  'images/cat.png',
                                  height: 120,
                                  width: 120,
                                  fit: BoxFit.cover,
                                  color: Colors.black,
                                ),
                                Text('Pet of your customer house',
                                    style: AppWidget.semiboldTextFeildStyle()),
                                const SizedBox(height: 10),
                                Text('John Terry House',
                                    style: AppWidget.LightTextFeildStyle()),
                                const SizedBox(height: 10),
                                Text('Total cat 5',
                                    style: AppWidget.semiboldTextFeildStyle()),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget showItem() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CatHistoryPage(),
              ),
            );
          },
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cat ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                'images/cat.png',
                height: 50,
                width: 50,
                fit: BoxFit.cover,
                color: cat ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReviewsPage(
                    itemId: 'some_item_id'), // แก้ไขโดยการส่ง itemId
              ),
            );
          },
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: paw ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(10)),
              child: Image.asset(
                'images/paw.png',
                height: 50,
                width: 50,
                fit: BoxFit.cover,
                color: paw ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SelectTargetDateScreen(onDateSelected: (selectedDate) {}),
              ),
            );
          },
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: backpack ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(10)),
              child: Image.asset(
                'images/backpack.png',
                height: 50,
                width: 50,
                fit: BoxFit.cover,
                color: backpack ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            cat = false;
            paw = false;
            backpack = false;
            ball = true;
            setState(() {});
          },
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: ball ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(10)),
              child: Image.asset(
                'images/ball.png',
                height: 50,
                width: 50,
                fit: BoxFit.cover,
                color: ball ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
