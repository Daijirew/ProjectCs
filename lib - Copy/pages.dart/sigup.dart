import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myproject/pages.dart/login.dart';
import 'package:myproject/services/shared_pref.dart';
import 'package:myproject/widget/widget_support.dart';
import 'package:random_string/random_string.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  String email = '', password = '', name = '';
  String role = 'user'; // บทบาทเริ่มต้น
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  // ฟังก์ชันลงทะเบียน
  registration() async {
    if (_formKey.currentState!.validate()) {
      try {
        // สร้างผู้ใช้ใน Firebase Authentication
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: emailController.text.trim(),
                password: passwordController.text.trim());

        String uid = userCredential.user!.uid; // UID ของผู้ใช้

        // เก็บข้อมูลใน Firestore
        Map<String, dynamic> userInfoMap = {
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'username': nameController.text.trim(),
          'photo': 'images/User.png', // รูปโปรไฟล์เริ่มต้น
          'uid': uid,
          'role': role, // บทบาท (user หรือ sitter)
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userInfoMap);

        // เก็บข้อมูลใน SharedPreferences
        await SharedPreferenceHelper().saveUserDisplayName(nameController.text);
        await SharedPreferenceHelper().saveUserPic('images/User.png');
        await SharedPreferenceHelper().saveUserRole(role);

        // นำไปยังหน้า Login
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => LogIn()));
      } catch (e) {
        // จัดการข้อผิดพลาด
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            "Registration failed: ${e.toString()}",
            style: TextStyle(fontSize: 18, color: Colors.black),
          ),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Stack(
          children: [
            // ส่วนหัว
            Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height / 2.5,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xff84ffff),
                    Color(0xff26c6da),
                    Color(0xff00e5ff)
                  ],
                ))),
            // ส่วนแบบฟอร์ม
            Container(
              margin:
                  EdgeInsets.only(top: MediaQuery.of(context).size.height / 3),
              height: MediaQuery.of(context).size.height / 2,
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15))),
            ),
            // แบบฟอร์มการสมัคร
            Container(
              margin: EdgeInsets.only(top: 50),
              child: Column(
                children: [
                  Center(
                    child: Image.asset('images/logo.png',
                        width: MediaQuery.of(context).size.width / 2.5,
                        fit: BoxFit.cover),
                  ),
                  SizedBox(height: 20),
                  Material(
                    elevation: 5,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      width: MediaQuery.of(context).size.width / 1.2,
                      height: MediaQuery.of(context).size.height / 1.75,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15)),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            SizedBox(height: 20),
                            Text('Sign Up',
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                            SizedBox(height: 20),
                            // ชื่อ
                            TextFormField(
                              controller: nameController,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                  hintText: 'Name',
                                  prefixIcon: Icon(Icons.person_outline)),
                            ),
                            SizedBox(height: 20),
                            // อีเมล
                            TextFormField(
                              controller: emailController,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                  hintText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined)),
                            ),
                            SizedBox(height: 20),
                            // รหัสผ่าน
                            TextFormField(
                              controller: passwordController,
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                  hintText: 'Password',
                                  prefixIcon: Icon(Icons.password_outlined)),
                            ),
                            SizedBox(height: 20),
                            // เลือกบทบาท
                            DropdownButton<String>(
                              value: role,
                              items: <String>['user', 'sitter']
                                  .map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  role = newValue!;
                                });
                              },
                            ),
                            SizedBox(height: 30),
                            // ปุ่ม Sign Up
                            GestureDetector(
                              onTap: registration,
                              child: Material(
                                elevation: 5,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  width: 200,
                                  decoration: BoxDecoration(
                                    color: Color.fromARGB(255, 253, 107, 63),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'SIGN UP',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 30),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => LogIn()));
                              },
                              child: Text("Already have an account? Login",
                                  style: AppWidget.LightTextFeildStyle()),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
