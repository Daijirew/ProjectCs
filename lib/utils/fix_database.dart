import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseFixer {
  static Future<void> fixAllReviews() async {
    try {
      print('Starting to fix all reviews...');

      // 1. ดึงข้อมูลรีวิวทั้งหมด
      final QuerySnapshot reviewsSnapshot =
          await FirebaseFirestore.instance.collection('reviews').get();

      print('Found ${reviewsSnapshot.docs.length} reviews to fix');

      // 2. ดึงข้อมูลผู้ใช้ที่ต้องการใช้
      final String forcedUserId = 'SE9htBfMnRbSnTUgA9bViITgH6M2';
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(forcedUserId)
          .get();

      if (!userDoc.exists) {
        print('User ID $forcedUserId not found');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) {
        print('User data is null');
        return;
      }

      final String userName = userData['name'] ?? 'ไม่ระบุชื่อ';
      final String userPhoto = userData['photo'] ?? '';

      print(
          'Using user data - Name: $userName, Has Photo: ${userPhoto.isNotEmpty}');

      // 3. วนลูปและอัพเดตทุกรีวิวให้ใช้ข้อมูลเดียวกัน
      for (var reviewDoc in reviewsSnapshot.docs) {
        try {
          print('Fixing review ${reviewDoc.id}');

          // อัพเดต Firestore document
          await FirebaseFirestore.instance
              .collection('reviews')
              .doc(reviewDoc.id)
              .update({
            'userId': forcedUserId,
            'userName': userName,
            'userPhoto': userPhoto,
          });

          print('Updated review ${reviewDoc.id}');
        } catch (e) {
          print('Error processing review ${reviewDoc.id}: $e');
        }
      }

      print('Review fixing completed');
    } catch (e) {
      print('Error in fixAllReviews: $e');
    }
  }
}
