import 'package:flutter/material.dart';
import 'package:myproject/pages.dart/buttomnav.dart';
import 'package:myproject/pages.dart/home.dart';
import 'package:myproject/pages.dart/login.dart';
import 'package:myproject/pages.dart/onboard.dart';
import 'package:myproject/pages.dart/sigup.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BottomNav(),
    );
  }
}
