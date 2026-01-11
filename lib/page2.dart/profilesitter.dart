import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myproject/pages.dart/login.dart';

class ProfileSitter extends StatefulWidget {
  const ProfileSitter({super.key});

  @override
  State<ProfileSitter> createState() => _ProfileSitterState();
}

class _ProfileSitterState extends State<ProfileSitter> {
  String? profile, name, email, phone;
  bool isLoading = true;
  final ImagePicker _picker = ImagePicker();
  File? selectedImage;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() => isLoading = true);
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
          name = userData?['name'] ?? user.displayName ?? 'Unknown';
          email = userData?['email'] ?? user.email ?? 'No email';
          phone = userData?['phone'] ?? 'No phone';
          profile = userData?['profilePic'] ?? user.photoURL;

          nameController.text = name ?? '';
          emailController.text = email ?? '';
          phoneController.text = phone ?? '';
        });
      }
    } catch (e) {
      _showSnackBar('Error loading profile', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateProfileImage() async {
    try {
      final XFile? pickedImage =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedImage == null) return;

      // Upload to Firebase Storage
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child("profileImages/${DateTime.now().millisecondsSinceEpoch}");

      UploadTask uploadTask = storageRef.putFile(File(pickedImage.path));
      String downloadUrl = await (await uploadTask).ref.getDownloadURL();

      // Update user profile
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'profilePic': downloadUrl});

      setState(() => profile = downloadUrl);
      _showSnackBar('Profile image updated');
    } catch (e) {
      _showSnackBar('Failed to update profile image', isError: true);
    }
  }

  Future<void> _updateProfile() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': nameController.text,
        'email': emailController.text,
        'phone': phoneController.text,
      });

      // Update Authentication email if changed
      if (emailController.text != user.email) {
        await user.updateEmail(emailController.text);
      }

      // Update display name
      await user.updateDisplayName(nameController.text);

      // Update local state
      setState(() {
        name = nameController.text;
        email = emailController.text;
        phone = phoneController.text;
      });

      _showSnackBar('Profile updated successfully');
    } catch (e) {
      _showSnackBar('Failed to update profile', isError: true);
    }
  }

  Future<void> _deleteAccount() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Reauthenticate user before deletion
      await _showReauthenticationDialog();

      // Delete Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // Delete user from Firebase Authentication
      await user.delete();

      // Navigate to login screen
      Navigator.pushReplacementNamed(context, '/login');

      _showSnackBar('Account deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete account', isError: true);
      print("Error deleting account: $e");
    }
  }

  Future<void> _showReauthenticationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบบัญชีผู้ใช้'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('กรุณายืนยันการลบบัญชีผู้ใช้โดยกรอกรหัสผ่านของคุณ'),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'รหัสผ่าน',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('ยืนยัน'),
              onPressed: () async {
                try {
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    // Reauthenticate
                    AuthCredential credential = EmailAuthProvider.credential(
                        email: user.email!, password: passwordController.text);
                    await user.reauthenticateWithCredential(credential);

                    // Close dialog
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  // Close current dialog
                  Navigator.of(context).pop();

                  // Show error
                  _showSnackBar('Reauthentication failed', isError: true);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: const [
              Icon(Icons.logout, color: Colors.orange),
              SizedBox(width: 10),
              Text('ออกจากระบบ'),
            ],
          ),
          content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'ยกเลิก',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LogIn()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('ออกจากระบบ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'โปรไฟล์',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 20),
                  _buildProfileContent(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            GestureDetector(
              onTap: _updateProfileImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundImage: profile != null
                        ? NetworkImage(profile!)
                        : const AssetImage('images/User.png') as ImageProvider,
                    onBackgroundImageError: (_, __) {
                      setState(() => profile = null);
                    },
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.indigo,
                          size: 20,
                        ),
                        onPressed: _updateProfileImage,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              name ?? 'User Name',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileField(
            icon: Icons.person,
            title: 'ชื่อ',
            value: name ?? 'Not set',
            onTap: () => _showEditDialog('Name', nameController),
          ),
          _buildProfileField(
            icon: Icons.email,
            title: 'อีเมล',
            value: email ?? 'Not set',
            onTap: () => _showEditDialog('Email', emailController),
          ),
          _buildProfileField(
            icon: Icons.phone,
            title: 'เบอร์โทร',
            value: phone ?? 'Not set',
            onTap: () => _showEditDialog('Phone', phoneController),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'ยืนยันการแก้ไขข้อมูล',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _deleteAccount,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: const Text(
              'ลบบัญชีผู้ใช้',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.indigo),
          onPressed: onTap,
        ),
      ),
    );
  }

  void _showEditDialog(String title, TextEditingController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit $title'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter $title',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateProfile();
                Navigator.of(context).pop();
              },
              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );
  }
}
