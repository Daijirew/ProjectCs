import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:myproject/Catpage.dart/CatDetailsPage.dart';
import 'package:myproject/Catpage.dart/CatRegistrationPage.dart';
import 'package:myproject/page2.dart/homesitter.dart';
import 'package:myproject/page2.dart/nevbarr..dart';
import 'package:myproject/pages.dart/chat.dart';
import 'package:myproject/pages.dart/chatpage.dart';
import 'package:myproject/pages.dart/home.dart';
import 'package:myproject/pages.dart/login.dart';
import 'package:myproject/pages.dart/onboard.dart';
import 'package:myproject/pages.dart/sigup.dart';
import 'package:myproject/services/auth.dart';
import 'package:myproject/widget/app_constant.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Stripe.publishableKey = publishableKey;
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ar', 'TH'),
      ],
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
      home: LogIn(),
    );
  }
}
