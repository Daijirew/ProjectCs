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
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .set(userInfoMap);
  }

  Future addUserDetails(Map<String, dynamic> userInfoMap, String uid) async {
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

  Future<QuerySnapshot> Search(String username) async {
    // ปรับเป็นการค้นหาแบบไม่ต้องตรงทั้งหมด
    return await FirebaseFirestore.instance
        .collection("users")
        .orderBy("username")
        .startAt([username.toLowerCase()]).endAt(
            [username.toLowerCase() + '\uf8ff']).get();
  }

  Future<QuerySnapshot> SearchAlternative(String searchTerm) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .where("username", isGreaterThanOrEqualTo: searchTerm)
        .where("username", isLessThanOrEqualTo: searchTerm + '\uf8ff')
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
    return await FirebaseFirestore.instance
        .collection("users")
        .where("username", isEqualTo: username)
        .get();
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
