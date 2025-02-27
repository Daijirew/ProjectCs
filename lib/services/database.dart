import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/services/shared_pref.dart';

class DatabaseMethods {
  // เพิ่มข้อมูลผู้ใช้ใหม่
  Future<void> addUserInfo(Map<String, dynamic> userInfoMap) async {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userInfoMap['uid'])
        .set(userInfoMap);
  }

  // เพิ่มผู้ใช้โดยระบุ ID
  Future addUser(String userId, Map<String, dynamic> userInfoMap) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .set(userInfoMap);
  }

  Future addUserDetails(Map<String, dynamic> userInfoMap, String id) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .set(userInfoMap);
  }

  // ค้นหาผู้ใช้จากอีเมล
  Future<QuerySnapshot> getUserbyemail(String email) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: email)
        .get();
  }

  // ค้นหาผู้ใช้จากชื่อผู้ใช้ (รองรับทั้ง user และ sitter)
  Future<QuerySnapshot> Search(String username) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .where("SearchKey", isEqualTo: username.substring(0, 1).toUpperCase())
        .where("role", whereIn: ["user", "sitter"])
        .get();
  }

  // สร้างห้องแชท
  createChatRoom(String chatRoomId, Map<String, dynamic> chatRoomInfoMap) async {
    // เพิ่ม ID ของผู้ใช้ทั้งสองฝ่าย
    chatRoomInfoMap['userIds'] = [
      chatRoomInfoMap['userIds'][0],
      chatRoomInfoMap['userIds'][1]
    ];

    // ตรวจสอบว่าห้องแชทมีอยู่แล้วหรือไม่
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

  // เพิ่มข้อความในห้องแชท
  Future addMessage(String chatRoomId, String messageId,
      Map<String, dynamic> messageInfoMap) async {
    return FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .collection("chats")
        .doc(messageId)
        .set(messageInfoMap);
  }

  // อัพเดทข้อความล่าสุด
  updateLastMessageSend(
      String chatRoomId, Map<String, dynamic> lastMessageInfoMap) {
    return FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .update(lastMessageInfoMap);
  }

  // ดึงข้อความทั้งหมดในห้องแชท
  Future<Stream<QuerySnapshot>> getChatRoomMessages(chatRoomId) async {
    return FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .collection("chats")
        .orderBy("time", descending: true)
        .snapshots();
  }

  // ดึงรายการห้องแชททั้งหมดของผู้ใช้
  Future<Stream<QuerySnapshot>> getChatRooms(
      String myUsername, String myRole) async {
    return FirebaseFirestore.instance
        .collection("chatrooms")
        .orderBy("time", descending: true)
        .where("users", arrayContains: myUsername)
        .snapshots();
  }

  Future<QuerySnapshot> getUserInfo(String username) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .where("username", isEqualTo: username)
        .get();
  }
}
