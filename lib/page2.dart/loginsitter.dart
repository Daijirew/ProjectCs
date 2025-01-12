import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myproject/page2.dart/nevbarr..dart';
import 'package:myproject/pages.dart/buttomnav.dart';
import 'package:myproject/pages.dart/forgotpassword.dart';
import 'package:myproject/pages.dart/sigup.dart';
import 'package:myproject/services/database.dart';
import 'package:myproject/services/shared_pref.dart';
import 'package:myproject/widget/widget_support.dart';

class LogInSitter extends StatefulWidget {
  const LogInSitter({super.key});

  @override
  State<LogInSitter> createState() => _LoginState();
}

class _LoginState extends State<LogInSitter> {
  String email = '',
      password = '',
      name = '',
      pic = '',
      username = '',
      id = '',
      role = '';
  TextEditingController useremailController = TextEditingController();
  TextEditingController userpasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  // ฟังก์ชันล็อกอิน
  userLogin() async {
    try {
      // ล็อกอินด้วยอีเมลและรหัสผ่าน
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: email.trim(), password: password.trim());

      // ดึง UID ของผู้ใช้
      String uid = userCredential.user!.uid;
      print('User logged in with UID: $uid');

      // ดึงข้อมูลผู้ใช้จาก Firestore โดยใช้ UID
      DocumentSnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userSnapshot.exists) {
        // ดึงข้อมูลจากเอกสาร
        Map<String, dynamic> userData =
            userSnapshot.data() as Map<String, dynamic>;
        name = userData['name'] ?? '';
        username = userData['username'] ?? '';
        pic = userData['photo'] ?? '';
        id = userData['uid'] ?? '';
        role = userData['role'] ?? '';
        print('User data: $userData');

        // เก็บข้อมูลผู้ใช้ใน SharedPreferences
        await SharedPreferenceHelper().saveUserDisplayName(name);
        await SharedPreferenceHelper().saveUserName(username);
        await SharedPreferenceHelper().saveUserId(id);
        await SharedPreferenceHelper().saveUserPic(pic);
        await SharedPreferenceHelper().saveUserRole(role);

        // นำทางไปยังหน้าต่างๆ ตามบทบาท
        if (role == 'sitter') {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => Nevbarr()));
        } else {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => BottomNav()));
        }
      } else {
        // กรณีข้อมูลผู้ใช้ไม่พบใน Firestore
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User data not found in Firestore.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      // จัดการข้อผิดพลาดเมื่อล็อกอินไม่สำเร็จ
      if (e.code == 'user-not-found') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No user found for that email.')),
        );
      } else if (e.code == 'wrong-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wrong password provided for that user.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.message}')),
        );
      }
    } catch (e) {
      // จัดการข้อผิดพลาดทั่วไป
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Stack(
          children: [
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
              child: Text(''),
            ),
            Container(
              margin: EdgeInsets.only(top: 50),
              child: Column(
                children: [
                  Center(
                    child: Image.asset(
                      'images/logo.png',
                      width: MediaQuery.of(context).size.width / 2.5,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Material(
                    elevation: 5,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: EdgeInsets.only(left: 20, right: 20),
                      width: MediaQuery.of(context).size.width / 1.2,
                      height: MediaQuery.of(context).size.height / 2.5,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15)),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 20,
                            ),
                            Text(
                              'Login here',
                              style: AppWidget.HeadlineTextFeildStyle(),
                            ),
                            SizedBox(
                              height: 20,
                            ),
                            TextFormField(
                              controller: useremailController,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter Email';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                  hintText: 'Email',
                                  hintStyle: AppWidget.LightTextFeildStyle(),
                                  prefixIcon: Icon(Icons.email_outlined)),
                            ),
                            SizedBox(
                              height: 20,
                            ),
                            TextFormField(
                              controller: userpasswordController,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter Password';
                                }
                                return null;
                              },
                              obscureText: true,
                              decoration: InputDecoration(
                                  hintText: 'Password',
                                  hintStyle: AppWidget.LightTextFeildStyle(),
                                  prefixIcon: Icon(Icons.password_outlined)),
                            ),
                            SizedBox(
                              height: 30,
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            ForgotPassword()));
                              },
                              child: Container(
                                alignment: Alignment.topRight,
                                child: Text('Forgot Password?',
                                    style: AppWidget.LightTextFeildStyle()),
                              ),
                            ),
                            SizedBox(
                              height: 40,
                            ),
                            GestureDetector(
                              onTap: () {
                                if (_formKey.currentState!.validate()) {
                                  setState(() {
                                    email = useremailController.text;
                                    password = userpasswordController.text;
                                  });
                                  userLogin();
                                }
                              },
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
                                      'LOGIN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontFamily: 'Poppins1',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 70,
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => SignUp()));
                    },
                    child: Text("Don't have an account? Sign Up",
                        style: AppWidget.LightTextFeildStyle()),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
