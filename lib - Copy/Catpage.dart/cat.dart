import 'package:cloud_firestore/cloud_firestore.dart';

class Cat {
  String name;
  String breed;
  String imagePath;
  Timestamp? birthDate; // เพิ่มวันเกิดเป็น Timestamp

  // คอนสตรัคเตอร์สำหรับสร้าง Cat
  Cat({
    required this.name,
    required this.breed,
    required this.imagePath,
    this.birthDate,
  });

  // สร้าง Cat จาก Firestore document
  factory Cat.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Cat(
      name: data['name'] ?? '',
      breed: data['breed'] ?? '',
      imagePath: data['imagePath'] ?? '',
      birthDate: data['birthDate'], // ดึงข้อมูล birthDate
    );
  }

  // แปลง Cat เป็นข้อมูลเพื่อบันทึกใน Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'breed': breed,
      'imagePath': imagePath,
      'birthDate': birthDate, // เก็บข้อมูล birthDate ถ้ามี
    };
  }
}
