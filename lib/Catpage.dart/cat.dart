import 'package:cloud_firestore/cloud_firestore.dart';

class Cat {
  final String id; // เพิ่ม id
  final String name;
  final String breed;
  final String imagePath;
  final Timestamp? birthDate;
  final String vaccinations;
  final String description;

  Cat({
    required this.id, // เพิ่ม id ในคอนสตรัคเตอร์
    required this.name,
    required this.breed,
    required this.imagePath,
    this.birthDate,
    required this.vaccinations,
    required this.description,
  });

  factory Cat.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Cat(
      id: doc.id, // ดึง id จาก DocumentSnapshot
      name: data['name'] ?? '',
      breed: data['breed'] ?? '',
      imagePath: data['imagePath'] ?? '',
      birthDate: data['birthDate'],
      vaccinations: data['vaccinations'] ?? '',
      description: data['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'breed': breed,
      'imagePath': imagePath,
      'birthDate': birthDate,
      'vaccinations': vaccinations,
      'description': description,
      // ไม่ต้องใส่ id ใน map เพราะใช้เป็น document id อยู่แล้ว
    };
  }
}
