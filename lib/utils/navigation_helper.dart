// lib/utils/navigation_helper.dart
import 'package:flutter/material.dart';
import 'package:myproject/page2.dart/sitter_checklist_page.dart';
import 'package:myproject/pages.dart/user_checklist_page.dart';

class NavigationHelper {
  static void navigateToChecklist(
      BuildContext context, String bookingId, String userRole) {
    print(
        'Navigating to checklist. BookingId: $bookingId, UserRole: $userRole');

    if (userRole == 'sitter') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SitterChecklistPage(bookingId: bookingId),
        ),
      );
    } else if (userRole == 'user') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserChecklistPage(bookingId: bookingId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ไม่มีสิทธิ์เข้าถึงเช็คลิสต์')));
    }
  }
}
