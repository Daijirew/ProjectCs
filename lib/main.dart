import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:myproject/Admin/ScheduledTasksManager.dart';
import 'package:myproject/utils/fix_database.dart';
import 'package:myproject/utils/user_fix.dart';
import 'package:myproject/Admin/AdminLoginPage.dart';
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
import 'package:myproject/utils/check_status_wrapper.dart'; // เพิ่ม import
import 'package:myproject/widget/app_constant.dart';
import 'package:myproject/utils/review_repair.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  Stripe.publishableKey = publishableKey;
  await UserDataFix.fixReviewUserInfo();
  await ReviewRepair.fixReviews();
  await DatabaseFixer.fixAllReviews();
  ScheduledTasksManager().startScheduledTasks();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cat Sitter App',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ar', 'TH'),
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) =>
            const CheckStatusWrapper(), // เปลี่ยนจาก LogIn เป็น CheckStatusWrapper
        '/login': (context) => const LogIn(),
        '/signup': (context) => const SignUp(),
        '/admin': (context) => const AdminLoginPage(),
      },
    );
  }

  Future<void> _checkAndFixBookings() async {
    try {
      // ตรวจสอบผู้ใช้ที่ล็อกอินอยู่
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      print('Starting database check and fix operations...');

      // ตรวจสอบการจองทั้งหมดที่มี sitterId เป็นค่าว่าง
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      print('Found ${bookingsSnapshot.docs.length} bookings for current user');

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();

        if (!data.containsKey('sitterId') ||
            data['sitterId'] == null ||
            data['sitterId'] == '') {
          print('Found booking with missing sitterId: ${doc.id}');

          // อัพเดตสถานะเป็น 'cancelled'
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(doc.id)
              .update({
            'status': 'cancelled',
            'cancelReason': 'ข้อมูลการจองไม่สมบูรณ์ (ไม่มี sitterId)',
            'updatedAt': FieldValue.serverTimestamp()
          });

          print('Updated booking ${doc.id} status to cancelled');
        } else {
          // ตรวจสอบว่า sitterId ที่มีอยู่จริงหรือไม่
          final sitterId = data['sitterId'];
          final sitterDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(sitterId)
              .get();

          if (!sitterDoc.exists) {
            print(
                'Found booking with invalid sitterId: ${doc.id}, sitterId: $sitterId');

            // อัพเดตสถานะเป็น 'cancelled'
            await FirebaseFirestore.instance
                .collection('bookings')
                .doc(doc.id)
                .update({
              'status': 'cancelled',
              'cancelReason': 'ข้อมูลผู้รับเลี้ยงไม่ถูกต้อง',
              'updatedAt': FieldValue.serverTimestamp()
            });

            print(
                'Updated booking ${doc.id} status to cancelled (invalid sitterId)');
          }
        }
      }

      // ทำเช่นเดียวกันสำหรับ booking_requests
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('booking_requests')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      print(
          'Found ${requestsSnapshot.docs.length} booking requests for current user');

      for (var doc in requestsSnapshot.docs) {
        final data = doc.data();

        if (!data.containsKey('sitterId') ||
            data['sitterId'] == null ||
            data['sitterId'] == '') {
          print('Found booking request with missing sitterId: ${doc.id}');

          // อัพเดตสถานะเป็น 'cancelled'
          await FirebaseFirestore.instance
              .collection('booking_requests')
              .doc(doc.id)
              .update({
            'status': 'cancelled',
            'cancelReason': 'ข้อมูลการจองไม่สมบูรณ์ (ไม่มี sitterId)',
            'updatedAt': FieldValue.serverTimestamp()
          });

          print('Updated booking request ${doc.id} status to cancelled');
        } else {
          // ตรวจสอบว่า sitterId ที่มีอยู่จริงหรือไม่
          final sitterId = data['sitterId'];
          final sitterDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(sitterId)
              .get();

          if (!sitterDoc.exists) {
            print(
                'Found booking request with invalid sitterId: ${doc.id}, sitterId: $sitterId');

            // อัพเดตสถานะเป็น 'cancelled'
            await FirebaseFirestore.instance
                .collection('booking_requests')
                .doc(doc.id)
                .update({
              'status': 'cancelled',
              'cancelReason': 'ข้อมูลผู้รับเลี้ยงไม่ถูกต้อง',
              'updatedAt': FieldValue.serverTimestamp()
            });

            print(
                'Updated booking request ${doc.id} status to cancelled (invalid sitterId)');
          }
        }
      }

      print('Database check and fix operations completed');
    } catch (e) {
      print('Error checking and fixing bookings: $e');
    }
  }

  // เพิ่มในไฟล์ lib/main.dart
  Future<void> _fixCorruptedSitterIds() async {
    try {
      print('Starting database repair for corrupted sitterIds...');

      // ตรวจสอบผู้ใช้ที่ล็อกอินอยู่
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // 1. ดึงข้อมูลผู้รับเลี้ยงทั้งหมด
      final sittersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .limit(10) // จำกัดจำนวน
          .get();

      if (sittersSnapshot.docs.isEmpty) {
        print('No sitters found in database!');
        return;
      }

      // รายชื่อ sitterIds ที่มีอยู่จริง
      List<String> validSitterIds =
          sittersSnapshot.docs.map((doc) => doc.id).toList();
      print('Valid sitter IDs: $validSitterIds');

      // 2. ตรวจสอบการจองที่มี sitterId ไม่ถูกต้อง
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final sitterId = data['sitterId'];

        // ตรวจสอบว่า sitterId มีอยู่ในรายชื่อที่ถูกต้องหรือไม่
        if (sitterId == null ||
            sitterId == '' ||
            !validSitterIds.contains(sitterId)) {
          print(
              'Found booking with invalid sitterId: ${doc.id}, current sitterId: $sitterId');

          // แก้ไขโดยใส่ sitterId ที่ถูกต้องตัวแรกจากรายการ
          if (validSitterIds.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('bookings')
                .doc(doc.id)
                .update({
              'sitterId': validSitterIds[0],
              'fixedAt': FieldValue.serverTimestamp(),
              'fixNote': 'Auto-fixed invalid sitterId',
            });

            print(
                'Fixed booking ${doc.id} with new sitterId: ${validSitterIds[0]}');
          }
        }
      }

      print('Database repair completed');
    } catch (e) {
      print('Error fixing corrupted sitterIds: $e');
    }
  }

// เพิ่มในส่วนของฟังก์ชัน main หลังจากที่ initialize Firebase เรียบร้อยแล้ว
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    // เริ่มระบบทำความสะอาดคิวอัตโนมัติ
    ScheduledTasksManager().startScheduledTasks();

    runApp(MyApp());
  }
}
