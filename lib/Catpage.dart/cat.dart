import 'package:cloud_firestore/cloud_firestore.dart';

class Cat {
  String name;
  String breed;
  String imagePath;
  Timestamp? birthDate;
  String vaccinations; // เพิ่มฟิลด์ vaccinations

  // ปรับปรุงคอนสตรัคเตอร์
  Cat({
    required this.name,
    required this.breed,
    required this.imagePath,
    this.birthDate,
    required this.vaccinations, // เพิ่ม vaccinations เป็น required parameter
  });

  // ปรับปรุง factory constructor
  factory Cat.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Cat(
      name: data['name'] ?? '',
      breed: data['breed'] ?? '',
      imagePath: data['imagePath'] ?? '',
      birthDate: data['birthDate'],
      vaccinations: data['vaccinations'] ?? '', // อ่านข้อมูล vaccinations
    );
  }

  // ปรับปรุงเมธอด toMap
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'breed': breed,
      'imagePath': imagePath,
      'birthDate': birthDate,
      'vaccinations': vaccinations, // เพิ่มการบันทึกข้อมูล vaccinations
    };
  }
}
