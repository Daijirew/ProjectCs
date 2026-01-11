// lib/services/checklist_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:myproject/models/checklist_model.dart';

class ChecklistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<ChecklistItem>> getTasksForBooking(String bookingId) {
    print('Getting tasks stream for booking: $bookingId');
    return _firestore
        .collection('checklists')
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ChecklistItem.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

// สร้างรายการเช็คลิสต์พื้นฐานเมื่อยืนยันการจอง
  Future<bool> createDefaultChecklist(String bookingId, String userId,
      String sitterId, List<String> catIds) async {
    try {
      print('Creating default checklist for booking: $bookingId');
      print('User ID: $userId, Sitter ID: $sitterId');
      print('Cat IDs: $catIds');

      if (bookingId.isEmpty || userId.isEmpty || sitterId.isEmpty) {
        print('Error: Required parameters are empty');
        return false;
      }

      if (catIds.isEmpty) {
        print('Error: No cats found for this booking');
        return false;
      }

      // ตรวจสอบว่ามีเช็คลิสต์อยู่แล้วหรือไม่
      QuerySnapshot existingChecklist = await _firestore
          .collection('checklists')
          .where('bookingId', isEqualTo: bookingId)
          .limit(1)
          .get();

      if (existingChecklist.docs.isNotEmpty) {
        print('Checklist already exists for this booking');
        return true; // ถือว่าสร้างสำเร็จเนื่องจากมีอยู่แล้ว
      }

      // รายการกิจกรรมมาตรฐานที่ต้องทำ
      List<String> standardActivities = [
        'ให้อาหาร',
        'เปลี่ยนน้ำ',
        'ทำความสะอาดกระบะทราย',
        'เล่นกับแมว',
        'แปรงขน',
        'ตรวจสอบสุขภาพทั่วไป'
      ];

      // สร้างเช็คลิสต์สำหรับแมวแต่ละตัว
      int successCount = 0;
      for (String catId in catIds) {
        for (String activity in standardActivities) {
          String id = Uuid().v4();
          ChecklistItem item = ChecklistItem(
            id: id,
            bookingId: bookingId,
            sitterId: sitterId,
            userId: userId,
            catId: catId,
            description: activity,
            timestamp: DateTime.now(),
            isCompleted: false,
          );

          try {
            await _firestore
                .collection('checklists')
                .doc(id)
                .set(item.toJson());
            successCount++;
            print('Created checklist item: $activity for cat: $catId');
          } catch (itemError) {
            print(
                'Error creating item: $activity for cat: $catId - $itemError');
          }
        }
      }

      print('Successfully created $successCount checklist items');
      return successCount > 0; // ส่งคืนค่า true ถ้าสร้างอย่างน้อย 1 รายการ
    } catch (e) {
      print('Error creating default checklist: $e');
      return false;
    }
  }

  Future<String?> uploadImageAndUpdateChecklist(
      String checklistId, File imageFile, String note, bool isCompleted) async {
    try {
      print('Uploading image and updating checklist ID: $checklistId');

      // ตรวจสอบว่า checklistId ไม่ว่างเปล่า
      if (checklistId.isEmpty) {
        print('Error: checklistId is empty');
        return null;
      }

      // ตรวจสอบว่าไฟล์มีอยู่จริง
      if (!imageFile.existsSync()) {
        print('Error: Image file does not exist');
        return null;
      }

      // อัปโหลดรูปภาพไปที่ Firebase Storage
      String fileName =
          'checklist_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = _storage.ref().child('checklist_images/$fileName');

      // แก้ตรงนี้: เพิ่มการจัดการ error ในการอัปโหลดไฟล์
      try {
        await storageRef.putFile(imageFile);
        String downloadUrl = await storageRef.getDownloadURL();
        print('Image uploaded successfully: $downloadUrl');

        // อัปเดตเช็คลิสต์ใน Firestore
        await _firestore.collection('checklists').doc(checklistId).update({
          'imageUrl': downloadUrl,
          'note': note,
          'isCompleted': isCompleted,
          'timestamp': FieldValue.serverTimestamp(),
        });
        print('Checklist updated successfully');

        return downloadUrl;
      } catch (uploadError) {
        print('Error during file upload: $uploadError');

        // ถ้าการอัปโหลดรูปล้มเหลว แต่ยังต้องการอัปเดตสถานะเช็คลิสต์
        await _firestore.collection('checklists').doc(checklistId).update({
          'note': note,
          'isCompleted': isCompleted,
          'timestamp': FieldValue.serverTimestamp(),
        });
        print('Checklist updated without image');

        return null;
      }
    } catch (e) {
      print('Error uploading image and updating checklist: $e');
      return null;
    }
  }

// เพิ่มเมธอดใหม่ต่อท้ายคลาส ChecklistService
  Future<bool> testFirestoreConnection() async {
    try {
      await _firestore.collection('test').doc('connection_test').set({
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Connection test successful'
      });
      return true;
    } catch (e) {
      print('Error connecting to Firestore: $e');
      return false;
    }
  }

  // อัปเดตรายการเช็คลิสต์
  Future<void> updateChecklistItem(String checklistId, bool isCompleted,
      {String? note}) async {
    try {
      print('Updating checklist item: $checklistId to completed: $isCompleted');

      Map<String, dynamic> updateData = {
        'isCompleted': isCompleted,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (note != null) {
        updateData['note'] = note;
      }

      await _firestore
          .collection('checklists')
          .doc(checklistId)
          .update(updateData);

      print('Checklist item updated successfully');
    } catch (e) {
      print('Error updating checklist item: $e');
      throw e;
    }
  }

  // ดึงข้อมูลเช็คลิสต์ตามการจอง
  Future<List<ChecklistItem>> getChecklistByBooking(String bookingId) async {
    try {
      print('Fetching checklist for booking: $bookingId');

      if (bookingId.isEmpty) {
        print('Error: bookingId is empty');
        return [];
      }

      QuerySnapshot snapshot = await _firestore
          .collection('checklists')
          .where('bookingId', isEqualTo: bookingId)
          .orderBy('timestamp', descending: true)
          .get();

      print('Found ${snapshot.docs.length} checklist items');

      if (snapshot.docs.isEmpty) {
        print(
            'No checklist items found for this booking, creating default items...');
        // แก้ไขตรงนี้ - ตรวจสอบฟิลด์ catIds ให้ถูกต้อง
        try {
          DocumentSnapshot bookingDoc =
              await _firestore.collection('bookings').doc(bookingId).get();

          if (bookingDoc.exists) {
            Map<String, dynamic> bookingData =
                bookingDoc.data() as Map<String, dynamic>;
            String userId = bookingData['userId'] ?? '';
            String sitterId = bookingData['sitterId'] ?? '';

            // แก้ตรงนี้: ตรวจสอบชื่อฟิลด์ให้ถูกต้อง
            List<String> catIds = [];
            if (bookingData.containsKey('catIds') &&
                bookingData['catIds'] != null) {
              catIds = List<String>.from(bookingData['catIds']);
            } else if (bookingData.containsKey('cats') &&
                bookingData['cats'] != null) {
              // เพิ่มการตรวจสอบกรณีที่ชื่อฟิลด์เป็น 'cats' แทน 'catIds'
              catIds = List<String>.from(bookingData['cats']);
            }

            // Process checklist items for each cat
            for (String catId in catIds) {
              await createDefaultChecklistItems(
                  bookingId, catId, userId, sitterId);
            }
          }
        } catch (e) {
          print('Error creating default checklist items: $e');
          return []; // Return empty list on error
        }
      }

      return snapshot.docs
          .map((doc) =>
              ChecklistItem.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting checklist by booking: $e');
      return [];
    }
  }

  // ดึงรายการเช็คลิสต์ตามแมว
  Future<List<ChecklistItem>> getChecklistByCat(
      String catId, String bookingId) async {
    try {
      print('Fetching checklist for cat: $catId in booking: $bookingId');

      if (catId.isEmpty || bookingId.isEmpty) {
        print('Error: catId or bookingId is empty');
        return [];
      }

      QuerySnapshot snapshot = await _firestore
          .collection('checklists')
          .where('catId', isEqualTo: catId)
          .where('bookingId', isEqualTo: bookingId)
          .orderBy('timestamp', descending: true)
          .get();

      print('Found ${snapshot.docs.length} checklist items for this cat');

      return snapshot.docs
          .map((doc) =>
              ChecklistItem.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting checklist by cat: $e');
      return [];
    }
  }

  // ดึงรายชื่อแมวสำหรับการจอง
  Future<List<Map<String, dynamic>>> getCatsForBooking(String bookingId) async {
    try {
      print('Fetching cats for booking: $bookingId');

      if (bookingId.isEmpty) {
        print('Error: bookingId is empty');
        return [];
      }

      // ดึงข้อมูลการจอง
      DocumentSnapshot bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();

      if (!bookingDoc.exists) {
        print('Booking document does not exist');
        return [];
      }

      Map<String, dynamic> bookingData =
          bookingDoc.data() as Map<String, dynamic>;
      String userId = bookingData['userId'] ?? '';

      if (userId.isEmpty) {
        print('User ID is empty in the booking document');
        return [];
      }

      List<String> catIds = [];
      if (bookingData.containsKey('catIds') && bookingData['catIds'] != null) {
        catIds = List<String>.from(bookingData['catIds']);
      } else {
        print('No cat IDs found in booking document');
        // ถ้าไม่มี catIds ให้ลองดึงข้อมูลแมวทั้งหมดของผู้ใช้
        try {
          QuerySnapshot catsSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('cats')
              .get();

          catIds = catsSnapshot.docs.map((doc) => doc.id).toList();
          print('Found ${catIds.length} cats for user: $userId');
        } catch (e) {
          print('Error fetching user cats: $e');
        }
      }

      List<Map<String, dynamic>> cats = [];
      for (String catId in catIds) {
        try {
          DocumentSnapshot catDoc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('cats')
              .doc(catId)
              .get();

          if (catDoc.exists) {
            Map<String, dynamic> catData =
                catDoc.data() as Map<String, dynamic>;
            catData['id'] = catId;
            cats.add(catData);
            print('Added cat: ${catData['name']} to the list');
          } else {
            print('Cat document does not exist: $catId');
          }
        } catch (e) {
          print('Error fetching cat document: $e');
        }
      }

      print('Returning ${cats.length} cats for this booking');
      return cats;
    } catch (e) {
      print('Error getting cats for booking: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getChecklistStatistics() async {
    try {
      // ดึงข้อมูลเช็คลิสต์ทั้งหมด
      QuerySnapshot allChecklistsSnapshot =
          await _firestore.collection('checklists').get();
      int totalChecklists = allChecklistsSnapshot.docs.length;

      // ดึงข้อมูลเช็คลิสต์ที่เสร็จแล้ว
      QuerySnapshot completedChecklistsSnapshot = await _firestore
          .collection('checklists')
          .where('isCompleted', isEqualTo: true)
          .get();
      int completedItems = completedChecklistsSnapshot.docs.length;

      // ดึงข้อมูลการจองทั้งหมด
      QuerySnapshot bookingSnapshot =
          await _firestore.collection('bookings').get();
      int totalBookings = bookingSnapshot.docs.length;

      // ดึงจำนวนการจองที่มีเช็คลิสต์ (เช่น มีรายการใน collection checklist ที่ bookingId ตรงกัน)
      Set<String> bookingIdsWithChecklist = allChecklistsSnapshot.docs
          .map((doc) =>
              (doc.data() as Map<String, dynamic>)['bookingId'] as String)
          .toSet();
      int bookingsWithChecklist = bookingIdsWithChecklist.length;

      // คำนวณเปอร์เซ็นต์
      double completionRate =
          totalChecklists > 0 ? completedItems / totalChecklists : 0.0;
      double bookingCompletionRate =
          totalBookings > 0 ? bookingsWithChecklist / totalBookings : 0.0;

      return {
        'totalChecklists': totalChecklists,
        'completedItems': completedItems,
        'completionRate': completionRate,
        'totalBookings': totalBookings,
        'bookingCompletionRate': bookingCompletionRate,
      };
    } catch (e) {
      print('Error getting checklist statistics: $e');
      return {
        'totalChecklists': 0,
        'completedChecklists': 0,
        'totalBookings': 0,
        'bookingsWithChecklists': 0,
        'error': e.toString()
      };
    }
  }

  Future<void> createDefaultChecklistItems(
    String bookingId,
    String catId,
    String userId,
    String sitterId,
  ) async {
    try {
      // Define default checklist items
      final defaultItems = [
        {
          'title': 'ตรวจสอบอาหารและน้ำ',
          'description': 'เติมอาหารและน้ำให้เพียงพอ ทำความสะอาดภาชนะ',
          'isCompleted': false,
          'order': 1,
          'catId': catId,
          'bookingId': bookingId,
          'userId': userId,
          'sitterId': sitterId,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'ทำความสะอาดกรงทราย',
          'description': 'ตักทรายแมวที่ใช้แล้ว เติมทรายแมวใหม่ถ้าจำเป็น',
          'isCompleted': false,
          'order': 2,
          'catId': catId,
          'bookingId': bookingId,
          'userId': userId,
          'sitterId': sitterId,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'เล่นกับแมว',
          'description':
              'ใช้เวลาอย่างน้อย 15 นาทีในการเล่นและมีปฏิสัมพันธ์กับแมว',
          'isCompleted': false,
          'order': 3,
          'catId': catId,
          'bookingId': bookingId,
          'userId': userId,
          'sitterId': sitterId,
          'createdAt': FieldValue.serverTimestamp(),
        }
      ];

      // Use batch write for better performance
      final batch = _firestore.batch();

      for (var item in defaultItems) {
        final docRef =
            _firestore.collection('checklists').doc(); // Auto-generate ID
        batch.set(docRef, item);
      }

      await batch.commit();
      print('Created default checklist items for cat: $catId');
    } catch (e) {
      print('Error creating default checklist items: $e');
      throw Exception('Failed to create default checklist items: $e');
    }
  }
}
