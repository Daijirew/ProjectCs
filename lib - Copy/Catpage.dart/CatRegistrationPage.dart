import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:random_string/random_string.dart';
import 'cat.dart'; // Import the Cat class

class CatRegistrationPage extends StatefulWidget {
  const CatRegistrationPage({Key? key, this.cat}) : super(key: key);

  final Cat? cat;

  @override
  _CatRegistrationPageState createState() => _CatRegistrationPageState();
}

class _CatRegistrationPageState extends State<CatRegistrationPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController breedController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController vaccinationController = TextEditingController();
  DateTime? birthDate;
  bool isLoading = false;

  // บันทึกข้อมูลแมว
  Future<void> saveCat() async {
    if (birthDate == null) {
      print("Birthdate is not selected");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a birthdate for the cat")),
      );
      return;
    }

    if (nameController.text.isEmpty) {
      print("Cat name is empty");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cat name is required")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // ตรวจสอบผู้ใช้ที่ล็อกอิน
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No user is logged in!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please log in to register a cat")),
        );
        return;
      }
      print("User ID: ${user.uid}");

      // สร้างข้อมูลแมว
      Cat newCat = Cat(
        name: nameController.text,
        breed: breedController.text,
        imagePath: "", // ไม่จำเป็นต้องใช้รูปภาพ
        birthDate: Timestamp.fromDate(birthDate!),
      );

      // บันทึกข้อมูลแมวใน Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cats')
          .add(newCat.toMap());
      print("Cat data successfully written!");

      // แสดงข้อความสำเร็จ
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Success"),
          content: const Text("Cat has been registered successfully!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back after saving
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      print("Error saving cat: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving cat: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // เลือกวันเกิด
  Future<void> pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != birthDate) {
      setState(() {
        birthDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Cat')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Cat Name'),
                  ),
                  TextField(
                    controller: breedController,
                    decoration: const InputDecoration(labelText: 'Cat Breed'),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextField(
                    controller: vaccinationController,
                    decoration:
                        const InputDecoration(labelText: 'Vaccination Status'),
                  ),
                  ListTile(
                    title: Text(birthDate == null
                        ? 'Select Birthdate'
                        : 'Birthdate: ${birthDate!.toLocal()}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => pickDate(context),
                  ),
                  ElevatedButton(
                    onPressed: saveCat,
                    child: const Text('Save Cat'),
                  ),
                ],
              ),
            ),
    );
  }
}
