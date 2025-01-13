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
    // ตรวจสอบว่าใส่ทุกช่อง
    if (nameController.text.isEmpty ||
        breedController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        vaccinationController.text.isEmpty ||
        birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบทุกช่อง")),
      );
      return;
    }

    // ตรวจสอบว่าข้อมูลเป็นตัวอักษรภาษาไทยหรืออังกฤษเท่านั้น
    final validPattern = RegExp(
        r'^[a-zA-Zก-๙\s]+$'); // อนุญาตตัวอักษรภาษาไทย, a-z, A-Z และช่องว่าง
    final descriptionPattern = RegExp(
        r'^[a-zA-Zก-๙0-9\s]+$'); // อนุญาตตัวอักษรภาษาไทย, a-z, A-Z, ตัวเลข และช่องว่าง

    if (!validPattern.hasMatch(nameController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("ชื่อแมวต้องเป็นตัวอักษรภาษาไทยหรือภาษาอังกฤษเท่านั้น")),
      );
      return;
    }
    if (!validPattern.hasMatch(breedController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("สายพันธุ์ต้องเป็นตัวอักษรภาษาไทยหรือภาษาอังกฤษเท่านั้น")),
      );
      return;
    }
    if (!descriptionPattern.hasMatch(descriptionController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "คำอธิบายต้องเป็นตัวอักษรภาษาไทย ภาษาอังกฤษ หรือมีตัวเลขเท่านั้น")),
      );
      return;
    }
    if (!validPattern.hasMatch(vaccinationController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "สถานะการฉีดวัคซีนต้องเป็นตัวอักษรภาษาไทยหรือภาษาอังกฤษเท่านั้น")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("กรุณาเข้าสู่ระบบเพื่อลงทะเบียนแมว")),
        );
        return;
      }

      Cat newCat = Cat(
        name: nameController.text,
        breed: breedController.text,
        imagePath: "",
        birthDate: Timestamp.fromDate(birthDate!),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cats')
          .add(newCat.toMap());

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("สำเร็จ"),
          content: const Text("ลงทะเบียนแมวเรียบร้อยแล้ว!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // ปิดหน้าต่าง dialog
                Navigator.pop(context); // ย้อนกลับหลังจากบันทึก
              },
              child: const Text("ตกลง"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาดในการบันทึก: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please log in to register a cat")),
        );
        return;
      }

      Cat newCat = Cat(
        name: nameController.text,
        breed: breedController.text,
        imagePath: "",
        birthDate: Timestamp.fromDate(birthDate!),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cats')
          .add(newCat.toMap());

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
