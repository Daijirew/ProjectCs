import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewRepair {
  static Future<void> fixReviews() async {
    try {
      print('Starting review repair...');
      
      // 1. ดึงข้อมูลรีวิวทั้งหมด
      final QuerySnapshot reviewsSnapshot = 
          await FirebaseFirestore.instance.collection('reviews').get();
      
      print('Found ${reviewsSnapshot.docs.length} reviews to check');
      
      // 2. วนลูปตรวจสอบและซ่อมแซมแต่ละรีวิว
      for (var doc in reviewsSnapshot.docs) {
        try {
          final reviewData = doc.data() as Map<String, dynamic>;
          final userId = reviewData['userId'];
          
          // ถ้าไม่มี userId หรือมี userName แล้ว ให้ข้าม
          if (userId == null || userId.isEmpty ||
              (reviewData.containsKey('userName') && 
               reviewData['userName'] != null && 
               reviewData['userName'].toString().isNotEmpty)) {
            continue;
          }
          
          print('Fixing review ${doc.id} for user $userId');
          
          // ดึงข้อมูลผู้ใช้
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userName = userData['name'] ?? '';
            final userPhoto = userData['photo'] ?? '';
            
            print('Found user info: name=$userName, has photo=${userPhoto.isNotEmpty}');
            
            // อัพเดตข้อมูลในรีวิว
            await FirebaseFirestore.instance
                .collection('reviews')
                .doc(doc.id)
                .update({
              'userName': userName,
              'userPhoto': userPhoto,
            });
            
            print('Updated review ${doc.id}');
          } else {
            print('User document not found for ID: $userId');
          }
        } catch (e) {
          print('Error processing review ${doc.id}: $e');
        }
      }
      
      print('Review repair completed');
    } catch (e) {
      print('Error in review repair: $e');
    }
  }
}