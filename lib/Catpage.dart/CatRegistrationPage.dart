import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:myproject/Catpage.dart/vaccine_selection_page.dart';
import 'cat.dart';

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
  DateTime? birthDate;
  bool isLoading = false;

  // เพิ่มตัวแปรสำหรับรูปภาพ
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Map<String, Map<String, bool>> vaccinationGroups = {
    'Core Vaccines': {
      'FPV (Feline Panleukopenia)': false,
      'FHV (Feline Viral Rhinotracheitis)': false,
      'FCV (Feline Calicivirus)': false,
    },
    'Non-Core Vaccines': {
      'FeLV (Feline Leukemia Virus)': false,
      'Rabies': false,
    },
  };

  String getSelectedVaccinations() {
    List<String> selected = [];
    vaccinationGroups.forEach((group, vaccines) {
      vaccines.forEach((vaccine, isSelected) {
        if (isSelected) selected.add(vaccine);
      });
    });
    return selected.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ลงทะเบียนแมว',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade200, Colors.white],
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildImagePicker(), // เพิ่มส่วนเลือกรูปภาพ
                            const SizedBox(height: 20),
                            _buildTextField(
                                controller: nameController,
                                label: 'ชื่อ แมว',
                                icon: Icons.pets,
                                hint: 'ใส่ชื่อแมว'),
                            const SizedBox(height: 20),
                            _buildTextField(
                                controller: breedController,
                                label: 'สายพันธุ์ แมว',
                                icon: Icons.category,
                                hint: 'ใส่สายพันธุ์แมว'),
                            const SizedBox(height: 20),
                            _buildTextField(
                                controller: descriptionController,
                                label: 'อธิบายลักษณะนิสัยแมวหรืออื่นๆ',
                                icon: Icons.description,
                                hint: 'ใส่คำอธิบายลักษณะนิสัยแมวหรืออื่นๆ',
                                maxLines: 3),
                            const SizedBox(height: 20),
                            _buildDatePicker(),
                            const SizedBox(height: 20),
                            _buildVaccinationSection(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: saveCat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'ลงทะเบียนแมว',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // สร้าง Widget สำหรับเลือกรูปภาพ
  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo, color: Colors.orange),
            const SizedBox(width: 10),
            const Text(
              'รูปภาพแมว',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _selectedImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'แตะเพื่อเลือกรูปภาพ',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ฟังก์ชันสำหรับเลือกรูปภาพจากแกลเลอรี่
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e')),
      );
    }
  }

  // ฟังก์ชันสำหรับอัปโหลดรูปภาพไปยัง Firebase Storage
  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      // สร้างชื่อไฟล์ที่ไม่ซ้ำกันโดยใช้ UUID
      final String fileName =
          '${const Uuid().v4()}${path.extension(_selectedImage!.path)}';

      // อ้างอิงไปยัง Firebase Storage
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('cat_images')
          .child(FirebaseAuth.instance.currentUser!.uid)
          .child(fileName);

      // อัปโหลดไฟล์
      await storageRef.putFile(_selectedImage!);

      // รับ URL สำหรับดาวน์โหลด
      final String downloadURL = await storageRef.getDownloadURL();
      return downloadURL;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e')),
      );
      return null;
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.orange),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.orange),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () => pickDate(context),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.orange),
            const SizedBox(width: 10),
            Text(
              birthDate == null
                  ? 'ระบุวันเกิดแมว'
                  : 'Birthdate: ${birthDate!.toLocal().toString().split(' ')[0]}',
              style: TextStyle(
                color: birthDate == null ? Colors.grey : Colors.black,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccinationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medical_services, color: Colors.orange),
            const SizedBox(width: 10),
            const Text(
              'วัคซีน',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final result = await Navigator.push<Map<String, Map<String, bool>>>(
              context,
              MaterialPageRoute(
                builder: (context) => VaccineSelectionPage(
                  initialSelections: vaccinationGroups,
                ),
              ),
            );
            if (result != null) {
              setState(() {
                vaccinationGroups = result;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    getSelectedVaccinations().isEmpty
                        ? 'เลือกวัคซีน'
                        : getSelectedVaccinations(),
                    style: TextStyle(
                      color: getSelectedVaccinations().isEmpty
                          ? Colors.grey.shade600
                          : Colors.black,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade600,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade400,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != birthDate) {
      setState(() {
        birthDate = picked;
      });
    }
  }

  Future<void> saveCat() async {
    if (nameController.text.isEmpty ||
        breedController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบทุกช่อง")),
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

      // อัปโหลดรูปภาพ (ถ้ามี)
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage();
      }

      Cat newCat = Cat(
        id: '', // กำหนดค่า id เป็นค่าว่าง
        name: nameController.text,
        breed: breedController.text,
        imagePath: imageUrl ?? '', // ใช้ URL รูปภาพที่อัปโหลด
        birthDate: Timestamp.fromDate(birthDate!),
        vaccinations: getSelectedVaccinations(),
        description: descriptionController.text, // ระบุค่า description
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
                Navigator.pop(context);
                Navigator.pop(context);
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
  }
}
