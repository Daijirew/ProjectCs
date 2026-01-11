import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceHelper {
  static String userIdKey = 'USERKEY';
  static String userNameKey = 'USERNAMEKEY';
  static String userEmailKey = 'USEREMAILKEY';
  static String userPicKey = 'USERPICKEY';
  static String displaynameKey = 'USERDISPLAYNAME';
  static String roleKey = 'USERROLEKEY'; // Added missing role key
  static String userWalletKey = 'USERWALLETKEY';
  static String userStatusKey = 'USERSTATUSKEY'; // เพิ่มคีย์สำหรับสถานะ

  // Save user data to SharedPreferences
  Future<bool> saveUserId(String getUserId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(userIdKey, getUserId);
  }

  Future<bool> saveUserEmail(String getUserEmail) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(userEmailKey, getUserEmail);
  }

  Future<bool> saveUserName(String getUserName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(userNameKey, getUserName);
  }

  Future<bool> saveUserPic(String getUserPic) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(userPicKey, getUserPic);
  }

  Future<bool> saveUserDisplayName(String getUserDisplayName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(displaynameKey, getUserDisplayName);
  }

  Future<bool> saveUserRole(String getUserRole) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(roleKey, getUserRole);
  }

  // Getter methods to retrieve user data
  Future<String?> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userIdKey);
  }

  Future<String?> getUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userNameKey);
  }

  Future<String?> getUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userEmailKey);
  }

  Future<String?> getUserPic() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userPicKey);
  }

  Future<String?> getDisplayName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(displaynameKey);
  }

  // ตรวจสอบว่าฟังก์ชัน getUserRole ทำงานถูกต้อง
  Future<String?> getUserRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? role = prefs.getString(roleKey);
    print('Current user role: $role'); // เพิ่ม log เพื่อตรวจสอบ
    return role;
  }

  // Additional utility methods to check if data exists
  Future<bool> isUserLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(userIdKey);
  }

  Future<bool> clearUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return await prefs.clear(); // Clear all data
  }

  // ตำแหน่งที่ต้องแก้ไข: ฟังก์ชัน saveUserWallet และ getUserWallet

  Future<bool> saveUserWallet(String amount) async {
    print('SharedPreferenceHelper: กำลังบันทึกยอดเงิน: $amount');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool result = await prefs.setString(userWalletKey, amount);
    print('SharedPreferenceHelper: บันทึกยอดเงินสำเร็จ: $result');
    return result;
  }

  Future<String?> getUserWallet() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? wallet = prefs.getString(userWalletKey);

    // ถ้า wallet เป็น null หรือว่าง ให้กำหนดค่าเป็น "0"
    if (wallet == null || wallet.isEmpty) {
      await saveUserWallet("0");
      return "0";
    }

    return wallet;
  }

  Future<void> updateUserWallet(String userId, String amount) async {
    return await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'wallet': amount,
    });
  }

// เพิ่มฟังก์ชันบันทึกสถานะ
  Future<bool> saveUserStatus(String status) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(userStatusKey, status);
  }

// เพิ่มฟังก์ชันดึงสถานะ
  Future<String?> getUserStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userStatusKey);
  }
}
