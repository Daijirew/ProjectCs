import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myproject/models/simple_checklist_model.dart';
import 'package:uuid/uuid.dart';

class SimpleChecklistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // รายการกิจกรรมพื้นฐานสำหรับแมว
  final List<String> basicCatTasks = [
    'ให้อาหาร',
    'เปลี่ยนน้ำ',
    'ทำความสะอาดกระบะทราย',
    'เล่นกับแมว',
    'แปรงขน',
    'ตรวจสอบสุขภาพทั่วไป'
  ];

  // สร้างเช็คลิสต์สำหรับการจอง
  Future<bool> createChecklistForBooking(String bookingId) async {
    try {
      // ดึงข้อมูลการจอง
      DocumentSnapshot bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();

      if (!bookingDoc.exists) {
        print('ไม่พบข้อมูลการจอง ID: $bookingId');
        return false;
      }

      Map<String, dynamic> bookingData =
          bookingDoc.data() as Map<String, dynamic>;

      // ดึงรายการแมว
      List<String> catIds = [];
      if (bookingData.containsKey('catIds') && bookingData['catIds'] != null) {
        catIds = List<String>.from(bookingData['catIds']);
      } else if (bookingData.containsKey('cats') &&
          bookingData['cats'] != null) {
        catIds = List<String>.from(bookingData['cats']);
      }

      if (catIds.isEmpty) {
        print('ไม่พบข้อมูลแมวในการจอง ID: $bookingId');
        return false;
      }

      String userId = bookingData['userId'] ?? '';

      // ดึงข้อมูลแมว
      List<Map<String, dynamic>> cats = [];
      for (String catId in catIds) {
        DocumentSnapshot catDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('cats')
            .doc(catId)
            .get();

        if (catDoc.exists) {
          Map<String, dynamic> catData = catDoc.data() as Map<String, dynamic>;
          cats.add({'id': catId, 'name': catData['name'] ?? 'แมว'});
        }
      }

      // ตรวจสอบว่ามีเช็คลิสต์อยู่แล้วหรือไม่
      QuerySnapshot existingChecklistQuery = await _firestore
          .collection('simple_checklists')
          .where('bookingId', isEqualTo: bookingId)
          .get();

      if (existingChecklistQuery.docs.isNotEmpty) {
        print('มีเช็คลิสต์สำหรับการจองนี้อยู่แล้ว');
        return true;
      }

      // สร้างเช็คลิสต์สำหรับแมวแต่ละตัว
      for (var cat in cats) {
        for (String task in basicCatTasks) {
          String id = Uuid().v4();
          SimpleChecklistItem item = SimpleChecklistItem(
              id: id,
              bookingId: bookingId,
              catId: cat['id'],
              catName: cat['name'],
              task: task);

          await _firestore
              .collection('simple_checklists')
              .doc(id)
              .set(item.toMap());
        }
      }

      print('สร้างเช็คลิสต์สำเร็จสำหรับการจอง ID: $bookingId');
      return true;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการสร้างเช็คลิสต์: $e');
      return false;
    }
  }

  // ดึงเช็คลิสต์สำหรับการจอง
  Future<List<SimpleChecklistItem>> getChecklistForBooking(
      String bookingId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('simple_checklists')
          .where('bookingId', isEqualTo: bookingId)
          .get();

      return snapshot.docs
          .map((doc) =>
              SimpleChecklistItem.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงเช็คลิสต์: $e');
      return [];
    }
  }

  // อัปเดตสถานะเช็คลิสต์
  Future<bool> updateChecklistStatus(String itemId, bool isCompleted) async {
    try {
      await _firestore.collection('simple_checklists').doc(itemId).update({
        'isCompleted': isCompleted,
        'completedAt': isCompleted ? FieldValue.serverTimestamp() : null
      });
      return true;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการอัปเดตสถานะเช็คลิสต์: $e');
      return false;
    }
  }

  // ดึงรายการแมวสำหรับการจอง
  Future<List<Map<String, dynamic>>> getCatsForBooking(String bookingId) async {
    try {
      // ดึงข้อมูลการจอง
      DocumentSnapshot bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();

      if (!bookingDoc.exists) {
        return [];
      }

      Map<String, dynamic> bookingData =
          bookingDoc.data() as Map<String, dynamic>;
      String userId = bookingData['userId'] ?? '';

      // ดึงรายการแมว
      List<String> catIds = [];
      if (bookingData.containsKey('catIds') && bookingData['catIds'] != null) {
        catIds = List<String>.from(bookingData['catIds']);
      } else if (bookingData.containsKey('cats') &&
          bookingData['cats'] != null) {
        catIds = List<String>.from(bookingData['cats']);
      }

      List<Map<String, dynamic>> cats = [];
      for (String catId in catIds) {
        DocumentSnapshot catDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('cats')
            .doc(catId)
            .get();

        if (catDoc.exists) {
          Map<String, dynamic> catData = catDoc.data() as Map<String, dynamic>;
          cats.add({
            'id': catId,
            'name': catData['name'] ?? 'แมว',
            'imagePath': catData['imagePath'] ?? ''
          });
        }
      }

      return cats;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงข้อมูลแมว: $e');
      return [];
    }
  }
}
