// สร้างไฟล์ใหม่ lib/utils/user_fix.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDataFix {
  static Future<void> fixSearchKeys() async {
    try {
      // ดึงข้อมูลผู้ใช้ทั้งหมด
      QuerySnapshot users =
          await FirebaseFirestore.instance.collection("users").get();

      for (var userDoc in users.docs) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String username = userData['username'] ?? '';

        if (username.isNotEmpty) {
          // ปรับปรุง SearchKey
          await FirebaseFirestore.instance
              .collection("users")
              .doc(userDoc.id)
              .update({
            'SearchKey': username.substring(0, 1).toUpperCase(),
            'username_lowercase':
                username.toLowerCase(), // เพิ่มฟิลด์สำหรับค้นหาง่ายขึ้น
          });
          print("อัปเดต SearchKey สำหรับ: $username");
        }
      }
      print("อัปเดต SearchKey เสร็จสิ้น");
    } catch (e) {
      print("เกิดข้อผิดพลาดในการอัปเดต SearchKey: $e");
    }
  }
}
