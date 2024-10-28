import 'package:flutter/material.dart';

class AppWidget {
  static TextStyle boldTextFeildStyle() {
    return TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins');
  }

  static TextStyle HeadlineTextFeildStyle() {
    return TextStyle(
        color: Colors.black,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins');
  }

  static TextStyle LightTextFeildStyle() {
    return TextStyle(
        color: Colors.black38,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        fontFamily: 'Poppins');
  }

  static TextStyle semiboldTextFeildStyle() {
    return TextStyle(
        color: Colors.black54,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins');
  }
}
