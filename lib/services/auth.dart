import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ฟังก์ชันเพื่อตรวจสอบผู้ใช้ปัจจุบัน
  getCurrentUser() async {
    return await _auth.currentUser;
  }

  // ฟังก์ชันสำหรับการออกจากระบบ
  Future<void> signOut() async {
    try {
      await _auth.signOut(); // เรียกใช้ Firebase Authentication เพื่อลงชื่อออก
    } catch (e) {
      print("Error signing out: $e");
      rethrow; // ถ้ามีข้อผิดพลาดก็จะโยนข้อผิดพลาดออกไป
    }
  }

  // ฟังก์ชันสำหรับการลงชื่อเข้าใช้ด้วย Google
  signInWithGoogle(BuildContext context) async {
    try {
      final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
      final GoogleSignIn googleSignIn = GoogleSignIn();

      final GoogleSignInAccount? googleSignInAccount =
          await googleSignIn.signIn();
      if (googleSignInAccount == null) {
        // ผู้ใช้ยกเลิกการลงชื่อเข้าใช้
        return;
      }

      final GoogleSignInAuthentication? googleSignInAuthentication =
          await googleSignInAccount.authentication;
      if (googleSignInAuthentication == null) {
        // การตรวจสอบการยืนยันล้มเหลว
        return;
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleSignInAuthentication.idToken,
        accessToken: googleSignInAuthentication.accessToken,
      );

      // การลงชื่อเข้าใช้ด้วย Google
      UserCredential result =
          await firebaseAuth.signInWithCredential(credential);
      User? userdetails = result.user;

      if (userdetails != null) {
        Map<String, dynamic> userInfoMap = {
          "email": userdetails.email,
          "username": userdetails.displayName,
          "imgUrl": userdetails.photoURL,
          "id": userdetails.uid,
        };

        // เพิ่มข้อมูลผู้ใช้ลงใน Firestore
        await DatabaseMethods()
            .addUser(userdetails.uid, userInfoMap)
            .then((value) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => BottomNav()));
        });
      }
    } catch (e) {
      print("Error signing in with Google: $e");
      throw Exception("Error signing in with Google: $e");
    }
  }
}

class DatabaseMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ฟังก์ชันสำหรับการเพิ่มข้อมูลผู้ใช้ลงใน Firestore
  Future<void> addUser(String id, Map<String, dynamic> userInfo) async {
    try {
      await _firestore.collection('users').doc(id).set(userInfo);
    } catch (e) {
      print("Error adding user: $e");
    }
  }
}

class BottomNav extends StatefulWidget {
  @override
  _BottomNavState createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _selectedIndex = 0;

  // ฟังก์ชันสำหรับการจัดการการเลือกใน Bottom Navigation
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bottom Navigation")),
      body: Center(
        child: Text("Selected Index: $_selectedIndex"),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class SignUpPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign Up')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              // เรียกใช้ฟังก์ชันลงชื่อเข้าใช้ด้วย Google
              await AuthMethods().signInWithGoogle(context);
            } catch (e) {
              // แสดงข้อความผิดพลาดในกรณีที่เกิดข้อผิดพลาด
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
          child: Text('Sign Up with Google'),
        ),
      ),
    );
  }
}
