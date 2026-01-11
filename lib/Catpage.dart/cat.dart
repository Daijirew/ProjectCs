import 'package:cloud_firestore/cloud_firestore.dart';

class Cat {
  final String id;
  final String name;
  final String breed;
  final String imagePath;
  final Timestamp? birthDate;
  final String vaccinations;
  final String description;
  final bool isForSitting; // เพิ่มฟิลด์สำหรับติดตามสถานะการฝากเลี้ยง
  final String? sittingStatus; // เพิ่มฟิลด์สำหรับติดตามสถานะการจับคู่
  final Timestamp? lastSittingDate; // เพิ่มฟิลด์สำหรับเก็บวันที่ฝากเลี้ยงล่าสุด

  Cat({
    required this.id,
    required this.name,
    required this.breed,
    required this.imagePath,
    this.birthDate,
    required this.vaccinations,
    required this.description,
    this.isForSitting = false, // ค่าเริ่มต้นเป็น false
    this.sittingStatus, // สถานะเช่น 'pending', 'matched', 'completed'
    this.lastSittingDate,
  });

  factory Cat.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Cat(
      id: doc.id,
      name: data['name'] ?? '',
      breed: data['breed'] ?? '',
      imagePath: data['imagePath'] ?? '',
      birthDate: data['birthDate'],
      vaccinations: data['vaccinations'] ?? '',
      description: data['description'] ?? '',
      isForSitting: data['isForSitting'] ?? false,
      sittingStatus: data['sittingStatus'],
      lastSittingDate: data['lastSittingDate'],
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
      'isForSitting': isForSitting,
      'sittingStatus': sittingStatus,
      'lastSittingDate': lastSittingDate,
    };
  }

  // สร้าง Cat ตัวใหม่โดยอัพเดทฟิลด์บางตัว
  Cat copyWith({
    bool? isForSitting,
    String? sittingStatus,
    Timestamp? lastSittingDate,
  }) {
    return Cat(
      id: id,
      name: name,
      breed: breed,
      imagePath: imagePath,
      birthDate: birthDate,
      vaccinations: vaccinations,
      description: description,
      isForSitting: isForSitting ?? this.isForSitting,
      sittingStatus: sittingStatus ?? this.sittingStatus,
      lastSittingDate: lastSittingDate ?? this.lastSittingDate,
    );
  }
}
