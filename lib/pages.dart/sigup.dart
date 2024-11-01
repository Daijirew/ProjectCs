import 'package:flutter/material.dart';
import 'package:myproject/pages.dart/login.dart';
import 'package:myproject/widget/widget_support.dart';

class Sigup extends StatefulWidget {
  const Sigup({super.key});

  @override
  State<Sigup> createState() => _SigupState();
}

class _SigupState extends State<Sigup> {
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
              colors: [Color(0xff84ffff), Color(0xff26c6da), Color(0xff00e5ff)],
            )),
          ),
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
            margin: EdgeInsets.only(
              top: 50,
            ),
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
                    height: MediaQuery.of(context).size.height / 1.75,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 20,
                        ),
                        Text(
                          'Sign Up',
                          style: AppWidget.HeadlineTextFeildStyle(),
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        TextField(
                          decoration: InputDecoration(
                              hintText: 'Name',
                              hintStyle: AppWidget.LightTextFeildStyle(),
                              prefixIcon: Icon(Icons.person_outline)),
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        TextField(
                          decoration: InputDecoration(
                              hintText: 'Email',
                              hintStyle: AppWidget.LightTextFeildStyle(),
                              prefixIcon: Icon(Icons.email_outlined)),
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        TextField(
                          obscureText: true,
                          decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: AppWidget.LightTextFeildStyle(),
                              prefixIcon: Icon(Icons.password_outlined)),
                        ),
                        SizedBox(
                          height: 40,
                        ),
                        Material(
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
                                'SING UP',
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
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 70,
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => LogIn()));
                  },
                  child: Text("Already have an account? Login",
                      style: AppWidget.LightTextFeildStyle()),
                )
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
