import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:myproject/page2.dart/chat2.dart';
import 'package:myproject/page2.dart/homesitter.dart';
import 'package:myproject/page2.dart/payment2.dart';
import 'package:myproject/page2.dart/profilesitter.dart';

class Nevbarr extends StatefulWidget {
  const Nevbarr({super.key});

  @override
  State<Nevbarr> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<Nevbarr> {
  int currentTapIndex = 0;
  late List<Widget> pages;
  late Widget currentPage;
  late Home2 homePage;
  late Chat chat;
  late ProfileSitter profile;
  late Payment2 payment;

  @override
  void initState() {
    homePage = Home2();
    chat = const Chat();
    profile = const ProfileSitter();
    payment = const Payment2();
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
