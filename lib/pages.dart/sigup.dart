import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myproject/pages.dart/login.dart';
import 'package:myproject/services/shared_pref.dart';
import 'package:myproject/widget/widget_support.dart';
import 'package:random_string/random_string.dart';
import 'package:url_launcher/url_launcher.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  String email = '', password = '', name = '';
  String role = 'user'; // บทบาทเริ่มต้น
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController =
      TextEditingController(); // เพิ่มเบอร์โทร
  TextEditingController facebookController =
      TextEditingController(); // เพิ่ม Facebook
  TextEditingController instagramController =
      TextEditingController(); // เพิ่ม Instagram
  TextEditingController lineController =
      TextEditingController(); // เพิ่ม Line ID
  TextEditingController catExpController =
      TextEditingController(); // เพิ่มประวัติการเลี้ยงแมว
  TextEditingController catAgeController =
      TextEditingController(); // เพิ่มอายุแมวที่รับเลี้ยง
  TextEditingController serviceRateController =
      TextEditingController(); // เพิ่มอัตราค่าบริการ
  TextEditingController petPerDayController =
      TextEditingController(); // จำนวนแมวที่รับต่อวัน
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _acceptTerms = false; // เพิ่มการยอมรับเงื่อนไข
  File? _profileImage; // เพิ่มสำหรับรูปโปรไฟล์
  List<File> _servicePictures = []; // รูปภาพสถานที่ให้บริการ

  final _formKey = GlobalKey<FormState>();

  // ฟังก์ชันเปิด URL
  Future<void> _launchUrl(String url) async {
    final Uri _url = Uri.parse(url);
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }

  // ฟังก์ชันเลือกรูปภาพ
  Future getImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    setState(() {
      if (pickedFile != null) {
        _profileImage = File(pickedFile.path);
      }
    });
  }

  // ฟังก์ชันเลือกรูปภาพสถานที่ให้บริการ
  Future getServicePicture() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    setState(() {
      if (pickedFile != null && _servicePictures.length < 5) {
        _servicePictures.add(File(pickedFile.path));
      }
    });
  }

  // ฟังก์ชันลบรูปภาพสถานที่ให้บริการ
  void removeServicePicture(int index) {
    setState(() {
      _servicePictures.removeAt(index);
    });
  }

  // ฟังก์ชันลงทะเบียน
  registration() async {
    // ตรวจสอบการยอมรับนโยบาย
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กรุณายอมรับข้อตกลงและนโยบายความเป็นส่วนตัว'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ตรวจสอบข้อมูลเพิ่มเติมสำหรับ sitter
    if (role == 'sitter') {
      if (_servicePictures.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('กรุณาอัพโหลดรูปภาพสถานที่ให้บริการอย่างน้อย 1 รูป'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // สร้างผู้ใช้ใน Firebase Authentication
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: emailController.text.trim(),
                password: passwordController.text.trim());

        String uid = userCredential.user!.uid; // ID ของผู้ใช้

        // อัพโหลดรูปโปรไฟล์ (ถ้ามี)
        String profileImageUrl = 'images/User.png'; // ค่าเริ่มต้น
        if (_profileImage != null) {
          // สร้าง reference ไปยัง storage
          Reference storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child('$uid.jpg');

          // อัพโหลดไฟล์
          await storageRef.putFile(_profileImage!);

          // รับ URL
          profileImageUrl = await storageRef.getDownloadURL();
        }

        // อัพโหลดรูปภาพสถานที่ให้บริการ (สำหรับ sitter)
        List<String> servicePictureUrls = [];
        if (role == 'sitter' && _servicePictures.isNotEmpty) {
          for (int i = 0; i < _servicePictures.length; i++) {
            Reference pictureRef = FirebaseStorage.instance
                .ref()
                .child('service_places')
                .child('$uid-$i.jpg');

            await pictureRef.putFile(_servicePictures[i]);
            String url = await pictureRef.getDownloadURL();
            servicePictureUrls.add(url);
          }
        }

        // สร้างข้อมูลพื้นฐานของผู้ใช้
        Map<String, dynamic> userInfoMap = {
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'username': nameController.text.trim(),
          'phone': phoneController.text.trim(), // เพิ่มเบอร์โทร
          'photo': profileImageUrl,
          'id': uid,
          'role': role,
          'wallet': "0",
          'SearchKey': nameController.text.substring(0, 1).toUpperCase(),
          'status': role == 'sitter'
              ? 'pending'
              : 'approved', // สถานะรอการอนุมัติสำหรับ sitter
          'registrationDate':
              FieldValue.serverTimestamp(), // เพิ่มวันที่ลงทะเบียน
        };

        // เพิ่มข้อมูลเฉพาะสำหรับผู้รับเลี้ยงแมว
        if (role == 'sitter') {
          userInfoMap['facebook'] = facebookController.text.trim();
          userInfoMap['instagram'] = instagramController.text.trim();
          userInfoMap['line'] = lineController.text.trim();
          userInfoMap['catExperience'] = catExpController.text.trim();
          userInfoMap['acceptedCatAge'] = catAgeController.text.trim();
          userInfoMap['serviceRate'] = serviceRateController.text.trim();
          userInfoMap['petsPerDay'] = petPerDayController.text.trim();
          userInfoMap['servicePictures'] = servicePictureUrls;
          userInfoMap['verificationStatus'] = 'pending';
          userInfoMap['adminComment'] = '';
          userInfoMap['rating'] = 0;
          userInfoMap['totalReviews'] = 0;
          userInfoMap['avgRating'] = 0.0;
          userInfoMap['availability'] = true; // พร้อมรับเลี้ยง
          userInfoMap['services'] = {
            'อาบน้ำ': true,
            'ตัดเล็บ': true,
            'ตัดขน': false,
            'รับ-ส่ง': false,
          };

          // เพิ่มการแจ้งเตือนไปยัง admin สำหรับการตรวจสอบ
          await FirebaseFirestore.instance
              .collection('admin_notifications')
              .add({
            'type': 'new_sitter',
            'userId': uid,
            'userName': nameController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false
          });
        }

        // บันทึกข้อมูลผู้ใช้
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userInfoMap);

        // เก็บข้อมูลใน SharedPreferences
        await SharedPreferenceHelper().saveUserDisplayName(nameController.text);
        await SharedPreferenceHelper().saveUserPic(profileImageUrl);
        await SharedPreferenceHelper().saveUserRole(role);

        // แสดงข้อความตามบทบาท
        if (role == 'sitter') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'สมัครสมาชิกสำเร็จ รอการอนุมัติจากผู้ดูแลระบบ (1-2 วันทำการ)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('สมัครสมาชิกสำเร็จ กรุณาเข้าสู่ระบบ'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // นำไปยังหน้า Login
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => LogIn()));
      } catch (e) {
        // จัดการข้อผิดพลาด
        String errorMessage = 'เกิดข้อผิดพลาดในการสมัครสมาชิก';

        if (e is FirebaseAuthException) {
          if (e.code == 'email-already-in-use') {
            errorMessage = 'อีเมลนี้ถูกใช้งานแล้ว';
          } else if (e.code == 'weak-password') {
            errorMessage = 'รหัสผ่านไม่ปลอดภัย';
          } else if (e.code == 'invalid-email') {
            errorMessage = 'รูปแบบอีเมลไม่ถูกต้อง';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.orange.shade700,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ส่วนหัว
              Center(
                child: Image.asset(
                  'images/logo.png',
                  height: 120,
                ),
              ),
              SizedBox(height: 30),
              Text(
                'สมัครสมาชิก',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
              Text(
                'สร้างบัญชีผู้ใช้เพื่อใช้บริการฝากเลี้ยงแมว',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 30),

              // เลือกบทบาท (ย้ายขึ้นมาอยู่ข้างบน)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_pin, color: Colors.orange.shade400),
                    SizedBox(width: 10),
                    Text(
                      'คุณคือ:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: role,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down,
                              color: Colors.orange.shade700),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          items: <String>['user', 'sitter'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value == 'user'
                                    ? 'ผู้ใช้ทั่วไป (ฝากเลี้ยงแมว)'
                                    : 'ผู้รับเลี้ยงแมว (ผู้ให้บริการ)',
                                style: TextStyle(
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              role = newValue!;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // ข้อความแจ้งเตือนเกี่ยวกับการตรวจสอบข้อมูลสำหรับผู้รับเลี้ยง
              if (role == 'sitter')
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange.shade700),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'การสมัครเป็นผู้รับเลี้ยงแมวต้องผ่านการตรวจสอบและอนุมัติจากทีมงาน (1-2 วันทำการ)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'กรุณากรอกข้อมูลที่เป็นความจริงและครบถ้วน เพื่อเพิ่มโอกาสในการได้รับอนุมัติ การให้ข้อมูลเท็จอาจส่งผลให้บัญชีถูกระงับการใช้งาน',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 20),

              // แบบฟอร์มสมัครสมาชิก
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ส่วนอัพโหลดรูปโปรไฟล์
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade200,
                              image: _profileImage != null
                                  ? DecorationImage(
                                      image: FileImage(_profileImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : DecorationImage(
                                      image: AssetImage('images/User.png'),
                                      fit: BoxFit.cover,
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: getImage,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.orange.shade600,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 5,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'รูปโปรไฟล์',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 30),

                    // ชื่อ
                    TextFormField(
                      controller: nameController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกชื่อผู้ใช้';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'ชื่อ-นามสกุล',
                        floatingLabelStyle:
                            TextStyle(color: Colors.orange.shade700),
                        prefixIcon: Icon(Icons.person_outline,
                            color: Colors.orange.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                              color: Colors.orange.shade400, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    SizedBox(height: 20),

                    // อีเมล
                    TextFormField(
                      controller: emailController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกอีเมล';
                        } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'รูปแบบอีเมลไม่ถูกต้อง';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'อีเมล',
                        floatingLabelStyle:
                            TextStyle(color: Colors.orange.shade700),
                        prefixIcon: Icon(Icons.email_outlined,
                            color: Colors.orange.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                              color: Colors.orange.shade400, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    SizedBox(height: 20),

                    // รหัสผ่าน
                    TextFormField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกรหัสผ่าน';
                        } else if (value.length < 8) {
                          return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
                        } else if (!RegExp(r'[A-Z]').hasMatch(value)) {
                          return 'รหัสผ่านต้องมีตัวอักษรตัวใหญ่อย่างน้อย 1 ตัว';
                        } else if (!RegExp(r'[0-9]').hasMatch(value)) {
                          return 'รหัสผ่านต้องมีตัวเลขอย่างน้อย 1 ตัว';
                        } else if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]')
                            .hasMatch(value)) {
                          return 'รหัสผ่านต้องมีอักขระพิเศษอย่างน้อย 1 ตัว';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน',
                        floatingLabelStyle:
                            TextStyle(color: Colors.orange.shade700),
                        prefixIcon: Icon(Icons.lock_outline,
                            color: Colors.orange.shade400),
                        suffixIcon: GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          child: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                              color: Colors.orange.shade400, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        helperText:
                            'รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร ประกอบด้วยตัวอักษรตัวใหญ่ ตัวเลข และอักขระพิเศษ',
                        helperStyle: TextStyle(fontSize: 12),
                      ),
                    ),
                    SizedBox(height: 20),

                    // เบอร์โทรศัพท์
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกเบอร์โทรศัพท์';
                        } else if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                          return 'กรุณากรอกเบอร์โทรศัพท์ 10 หลัก';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'เบอร์โทรศัพท์',
                        floatingLabelStyle:
                            TextStyle(color: Colors.orange.shade700),
                        prefixIcon:
                            Icon(Icons.phone, color: Colors.orange.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                              color: Colors.orange.shade400, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    SizedBox(height: 20),

                    // ข้อมูลเพิ่มเติมสำหรับผู้รับเลี้ยงแมว (sitter)
                    if (role == 'sitter')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ช่องทางการติดต่อ
                          Container(
                            margin: EdgeInsets.only(bottom: 20),
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ช่องทางการติดต่อ (เลือกกรอกอย่างน้อย 1 ช่องทาง)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                SizedBox(height: 15),
                                // Facebook
                                TextFormField(
                                  controller: facebookController,
                                  decoration: InputDecoration(
                                    labelText: 'Facebook URL',
                                    hintText: 'https://facebook.com/username',
                                    floatingLabelStyle:
                                        TextStyle(color: Colors.blue.shade700),
                                    prefixIcon: Icon(Icons.facebook,
                                        color: Colors.blue.shade700),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                          color: Colors.blue.shade400,
                                          width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 15),

                                // Instagram
                                TextFormField(
                                  controller: instagramController,
                                  decoration: InputDecoration(
                                    labelText: 'Instagram URL',
                                    hintText: 'https://instagram.com/username',
                                    floatingLabelStyle:
                                        TextStyle(color: Colors.pink.shade400),
                                    prefixIcon: Icon(Icons.camera_alt,
                                        color: Colors.pink.shade400),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                          color: Colors.pink.shade400,
                                          width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 15),

                                // Line ID
                                TextFormField(
                                  controller: lineController,
                                  decoration: InputDecoration(
                                    labelText: 'Line ID',
                                    hintText: 'your-line-id',
                                    floatingLabelStyle:
                                        TextStyle(color: Colors.green.shade600),
                                    prefixIcon: Icon(Icons.chat_bubble_outline,
                                        color: Colors.green.shade600),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                          color: Colors.green.shade600,
                                          width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  '* แสดงเฉพาะช่องทางที่คุณต้องการให้ผู้ใช้ติดต่อ',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ประวัติการเลี้ยงแมว
                          TextFormField(
                            controller: catExpController,
                            maxLines: 4,
                            validator: (value) {
                              if (role == 'sitter' &&
                                  (value == null || value.isEmpty)) {
                                return 'กรุณากรอกประวัติการเลี้ยงแมว';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'ประวัติและประสบการณ์การเลี้ยงแมว',
                              hintText:
                                  'กรุณาระบุประสบการณ์การเลี้ยงแมว จำนวนแมวที่เคยเลี้ยง ทักษะพิเศษในการดูแลแมว ฯลฯ',
                              floatingLabelStyle:
                                  TextStyle(color: Colors.orange.shade700),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                    color: Colors.orange.shade400, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                          SizedBox(height: 20),

                          // อัพโหลดรูปภาพสถานที่ให้บริการ
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'รูปภาพสถานที่ให้บริการ (อย่างน้อย 1 รูป)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                padding: EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  children: [
                                    // แสดงรูปภาพที่อัพโหลดแล้ว
                                    if (_servicePictures.isNotEmpty)
                                      Container(
                                        height: 120,
                                        margin: EdgeInsets.only(bottom: 15),
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _servicePictures.length,
                                          itemBuilder: (context, index) {
                                            return Stack(
                                              children: [
                                                Container(
                                                  margin: EdgeInsets.only(
                                                      right: 10),
                                                  width: 100,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    image: DecorationImage(
                                                      image: FileImage(
                                                          _servicePictures[
                                                              index]),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 5,
                                                  right: 15,
                                                  child: GestureDetector(
                                                    onTap: () =>
                                                        removeServicePicture(
                                                            index),
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.all(5),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),

                                    // ปุ่มเพิ่มรูปภาพ
                                    ElevatedButton.icon(
                                      onPressed: _servicePictures.length < 5
                                          ? getServicePicture
                                          : null,
                                      icon: Icon(Icons.add_photo_alternate),
                                      label: Text(_servicePictures.isEmpty
                                          ? 'เพิ่มรูปภาพสถานที่ให้บริการ'
                                          : 'เพิ่มรูปภาพ (${_servicePictures.length}/5)'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange.shade600,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'แนะนำให้อัพโหลดรูปภาพบริเวณที่แมวจะอยู่ กรง พื้นที่เล่น มุมพักผ่อน และสิ่งอำนวยความสะดวกต่างๆ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),

                          // คำเตือนเกี่ยวกับการตรวจสอบข้อมูล
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.verified_user,
                                    color: Colors.blue.shade700),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'ข้อมูลของคุณจะถูกตรวจสอบโดยทีมงานก่อนเปิดให้บริการ เพื่อความปลอดภัยของผู้ใช้ทุกท่าน',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),

                    // ส่วนยอมรับนโยบาย
                    Row(
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          onChanged: (bool? value) {
                            setState(() {
                              _acceptTerms = value ?? false;
                            });
                          },
                          activeColor: Colors.orange.shade600,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // แสดงหน้าข้อตกลงและเงื่อนไข (สามารถเพิ่มเป็นหน้าแยกได้)
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text(
                                      'ข้อตกลงและนโยบายความเป็นส่วนตัว',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: SingleChildScrollView(
                                      child: Text(
                                        'ข้อตกลงในการใช้บริการและนโยบายความเป็นส่วนตัว\n\n'
                                        '1. การใช้บริการแอปพลิเคชัน: ผู้ใช้ยอมรับที่จะใช้บริการตามข้อกำหนดและเงื่อนไขที่ระบุไว้\n\n'
                                        '2. ข้อมูลส่วนบุคคล: เราจะเก็บรวบรวมข้อมูลส่วนบุคคลเพื่อวัตถุประสงค์ในการให้บริการเท่านั้น\n\n'
                                        '3. ความรับผิดชอบ: ผู้ใช้ยอมรับความรับผิดชอบในการใช้บริการและข้อมูลที่ให้ไว้\n\n'
                                        '4. การชำระเงิน: ผู้ใช้ยอมรับเงื่อนไขการชำระเงินตามที่ระบุในแอปพลิเคชัน\n\n'
                                        '5. การยกเลิกบริการ: เราขอสงวนสิทธิ์ในการยกเลิกบริการหากพบการละเมิดข้อตกลง\n\n'
                                        'การใช้บริการของเราถือว่าท่านได้อ่านและยอมรับข้อตกลงและนโยบายความเป็นส่วนตัวทั้งหมด',
                                        style: TextStyle(
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text(
                                          'ตกลง',
                                          style: TextStyle(
                                            color: Colors.orange.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: Text(
                              'ฉันได้อ่านและยอมรับข้อตกลงและนโยบายความเป็นส่วนตัว',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30),

                    // ปุ่มสมัครสมาชิก
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : registration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 3,
                          shadowColor: Colors.orange.withOpacity(0.5),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : Text(
                                'สมัครสมาชิก',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 30),

                    // ลิงก์ไปหน้า Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'มีบัญชีอยู่แล้ว? ',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => LogIn()));
                          },
                          child: Text(
                            'เข้าสู่ระบบ',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
