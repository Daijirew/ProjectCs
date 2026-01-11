import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:myproject/pages.dart/chat.dart';
import 'package:myproject/pages.dart/home.dart';
import 'package:myproject/pages.dart/payment.dart';
import 'package:myproject/pages.dart/profile.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<BottomNav> {
  int currentTapIndex = 0;
  late List<Widget> pages;
  late Widget currentPage;
  late Home homePage;
  late Chat chat;
  late Profile profile;
  late Payment payment;

  @override
  void initState() {
    homePage = const Home();
    chat = const Chat();
    profile = const Profile();
    payment = const Payment();
    pages = [homePage, chat, payment, profile];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CurvedNavigationBar(
        height: 65,
        backgroundColor: Colors.white,
        color: Colors.black,
        animationDuration: const Duration(milliseconds: 500),
        onTap: (int index) {
          setState(() {
            currentTapIndex = index;
          });
        },
        items: const [
          Icon(
            Icons.home_outlined,
            color: Colors.white,
          ),
          Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
          ),
          Icon(
            Icons.payment,
            color: Colors.white,
          ),
          Icon(
            Icons.person_outline,
            color: Colors.white,
          )
        ],
      ),
      body: pages[currentTapIndex],
    );
  }
}
