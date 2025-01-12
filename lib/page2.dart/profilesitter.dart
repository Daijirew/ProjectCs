import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileSitter extends StatefulWidget {
  const ProfileSitter({super.key});

  @override
  State<ProfileSitter> createState() => _ProfileSitterState();
}

class _ProfileSitterState extends State<ProfileSitter> {
  String? profile, name, email, phone;
  bool isLoading = true; // ตัวแปร isLoading ที่เพิ่มเข้ามา
  final ImagePicker _picker = ImagePicker();
  File? selectedImage;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  Future<void> getUserInfo() async {
    setState(() => isLoading = true); // เริ่มโหลดข้อมูล
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;

        setState(() {
          name = userData?['name'] ?? user.displayName ?? 'No name';
          email = userData?['email'] ?? user.email ?? 'No email';
          phone = userData?['phone'] ?? 'No phone';
          profile = userData?['profilePic'] ?? user.photoURL;

          nameController.text = name ?? '';
          emailController.text = email ?? '';
          phoneController.text = phone ?? '';
        });
      }
    } catch (e) {
      print("Error fetching user info: $e");
    }
    setState(() => isLoading = false); // หยุดโหลดข้อมูล
  }

  Future<void> getImage() async {
    try {
      final XFile? pickedImage =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedImage == null) return;

      setState(() => selectedImage = File(pickedImage.path));

      Reference firebaseStorageRef = FirebaseStorage.instance
          .ref()
          .child("profileImages/${DateTime.now().millisecondsSinceEpoch}");
      UploadTask uploadTask = firebaseStorageRef.putFile(selectedImage!);
      String downloadUrl = await (await uploadTask).ref.getDownloadURL();

      await FirebaseAuth.instance.currentUser?.updatePhotoURL(downloadUrl);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'profilePic': downloadUrl});

      setState(() => profile = downloadUrl);
    } catch (e) {
      print("Error uploading image: $e");
    }
  }

  Future<void> updateProfile() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (emailController.text != user.email) {
        await user.updateEmail(emailController.text);
      }
      await user.updateDisplayName(nameController.text);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': nameController.text,
        'email': emailController.text,
        'phone': phoneController.text,
      });

      setState(() {
        name = nameController.text;
        email = emailController.text;
        phone = phoneController.text;
      });

      print("Profile updated successfully.");
    } catch (e) {
      print("Error updating profile: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    getUserInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) // แสดงวงล้อโหลด
          : SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        height: MediaQuery.of(context).size.height / 4.3,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.elliptical(
                                MediaQuery.of(context).size.width, 105),
                          ),
                        ),
                      ),
                      Center(
                        child: GestureDetector(
                          onTap: getImage,
                          child: Container(
                            margin: EdgeInsets.only(
                              top: MediaQuery.of(context).size.height / 6.5,
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundImage: profile != null
                                  ? NetworkImage(profile!)
                                  : const AssetImage('images/User.png')
                                      as ImageProvider,
                              onBackgroundImageError: (_, __) {
                                setState(() => profile = null);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  buildProfileInfoRow('Name', name ?? 'No name', Icons.person),
                  buildProfileInfoRow(
                      'E-mail', email ?? 'No email', Icons.mail),
                  buildProfileInfoRow(
                      'Phone', phone ?? 'No phone', Icons.phone),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: updateProfile,
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget buildProfileInfoRow(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Material(
        borderRadius: BorderRadius.circular(10),
        elevation: 2.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.blue, // สีของกรอบ
              width: 1.5, // ความหนาของกรอบ
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.black),
                  const SizedBox(width: 20),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () {
                  TextEditingController controller = title == 'Name'
                      ? nameController
                      : title == 'Phone'
                          ? phoneController
                          : emailController;

                  showEditDialog(
                    context: context,
                    title: title,
                    controller: controller,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showEditDialog({
    required BuildContext context,
    required String title,
    required TextEditingController controller,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit $title'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter $title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                updateProfile();
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด Dialog
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pop(context); // ปิด Dialog
              Navigator.pushReplacementNamed(context, '/login'); // ไปหน้า Login
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
