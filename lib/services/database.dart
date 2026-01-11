import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/services/shared_pref.dart';

class DatabaseMethods {
  UpdateUserwallet(String uid, String amount) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .update({
      "wallet": amount,
    });
  }

  Future<void> addUserInfo(Map<String, dynamic> userInfoMap) async {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userInfoMap['uid'])
        .set(userInfoMap);
  }

  Future addUser(String userId, Map<String, dynamic> userInfoMap) async {
    // ถ้า userInfoMap ไม่มีฟิลด์ wallet ให้เพิ่มเข้าไป
    if (!userInfoMap.containsKey('wallet')) {
      userInfoMap['wallet'] = "0";
    }

    return await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .set(userInfoMap);
  }

  Future addUserDetails(Map<String, dynamic> userInfoMap, String uid) async {
    // ถ้า userInfoMap ไม่มีฟิลด์ wallet ให้เพิ่มเข้าไป
    if (!userInfoMap.containsKey('wallet')) {
      userInfoMap['wallet'] = "0";
    }

    return await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .set(userInfoMap);
  }

  Future<QuerySnapshot> getUserbyemail(String email) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: email)
        .get();
  }

  Future<QuerySnapshot> Search(String searchField) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .where('name', isGreaterThanOrEqualTo: searchField)
        .where('name', isLessThanOrEqualTo: searchField + '\uf8ff')
        .get();
  }

  Future<QuerySnapshot> SearchAlternative(String searchTerm) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .where("username", isGreaterThanOrEqualTo: searchTerm)
        .where("username", isLessThanOrEqualTo: searchTerm + '\uf8ff')
        .get();
  }

  Future<QuerySnapshot> SearchByCaseInsensitive(String searchField) async {
    // แปลงคำค้นหาเป็นตัวพิมพ์เล็กทั้งหมด
    String searchLower = searchField.toLowerCase();

    // คำค้นหาที่เป็นตัวพิมพ์ใหญ่
    String searchUpper = searchField.toUpperCase();

    // ค้นหาจากทั้งสามรูปแบบ (ตัวพิมพ์เล็ก, ตัวพิมพ์ใหญ่, หรือตรงตามที่พิมพ์)
    QuerySnapshot lowerResults = await FirebaseFirestore.instance
        .collection("users")
        .where('name', isGreaterThanOrEqualTo: searchLower)
        .where('name', isLessThanOrEqualTo: searchLower + '\uf8ff')
        .get();

    QuerySnapshot upperResults = await FirebaseFirestore.instance
        .collection("users")
        .where('name', isGreaterThanOrEqualTo: searchUpper)
        .where('name', isLessThanOrEqualTo: searchUpper + '\uf8ff')
        .get();

    QuerySnapshot originalResults = await FirebaseFirestore.instance
        .collection("users")
        .where('name', isGreaterThanOrEqualTo: searchField)
        .where('name', isLessThanOrEqualTo: searchField + '\uf8ff')
        .get();

    // รวมผลลัพธ์
    List<DocumentSnapshot> combinedResults = [
      ...lowerResults.docs,
      ...upperResults.docs,
      ...originalResults.docs,
    ];

    // กรองผลลัพธ์ที่ซ้ำกัน
    final Map<String, DocumentSnapshot> uniqueResults = {};
    for (var doc in combinedResults) {
      uniqueResults[doc.id] = doc;
    }

    // สร้าง QuerySnapshot จากผลลัพธ์ที่ไม่ซ้ำกัน
    return FirebaseFirestore.instance
        .collection("users")
        .where(FieldPath.documentId, whereIn: uniqueResults.keys.toList())
        .get();
  }

  createChatRoom(
      String chatRoomId, Map<String, dynamic> chatRoomInfoMap) async {
    chatRoomInfoMap['userIds'] = [
      chatRoomInfoMap['users'][0],
      chatRoomInfoMap['users'][1]
    ];
    final snapshot = await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .get();
    if (snapshot.exists) {
      return true;
    } else {
      return FirebaseFirestore.instance
          .collection("chatrooms")
          .doc(chatRoomId)
          .set(chatRoomInfoMap);
    }
  }

  Future addMessage(String chatRoomId, String messageId,
      Map<String, dynamic> messageInfoMap) async {
    return FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .collection("chats")
        .doc(messageId)
        .set(messageInfoMap);
  }

  updateLastMessageSend(
      String chatRoomId, Map<String, dynamic> lastMessageInfoMap) {
    return FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .update(lastMessageInfoMap);
  }

  Future<Stream<QuerySnapshot>> getChatRoomMessages(chatRoomId) async {
    return FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .collection("chats")
        .orderBy("time", descending: true)
        .snapshots();
  }

  Future<QuerySnapshot> getUserInfo(String username) async {
    // แก้ไขตรงนี้: เพิ่มวิธีค้นหาหลายรูปแบบ (case insensitive)
    // ลองค้นหาทั้งในรูปแบบที่ส่งมา, รูปแบบตัวเล็กทั้งหมด และรูปแบบตัวใหญ่ทั้งหมด
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("users")
        .where("username", isEqualTo: username)
        .get();

    // ถ้าไม่พบข้อมูล ลองค้นหาด้วยรูปแบบตัวพิมพ์เล็ก
    if (snapshot.docs.isEmpty) {
      snapshot = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: username.toLowerCase())
          .get();
    }

    // ถ้ายังไม่พบ ลองค้นหาด้วยรูปแบบตัวพิมพ์ใหญ่
    if (snapshot.docs.isEmpty) {
      snapshot = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: username.toUpperCase())
          .get();
    }

    return snapshot;
  }

  Future<Stream<QuerySnapshot>> getChatRooms(
      String myUsername, String myRole) async {
    return FirebaseFirestore.instance
        .collection("chatrooms")
        .orderBy("time", descending: true)
        .where("users", arrayContains: myUsername)
        .snapshots();
  }
}
