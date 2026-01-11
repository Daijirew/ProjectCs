import 'package:cloud_firestore/cloud_firestore.dart';

class ChecklistItem {
  final String id;
  final String bookingId;
  final String sitterId;
  final String userId;
  final String catId;
  final String description;
  final DateTime timestamp;
  final bool isCompleted;
  final String? imageUrl;
  final String? note;

  ChecklistItem({
    required this.id,
    required this.bookingId,
    required this.sitterId,
    required this.userId,
    required this.catId,
    required this.description,
    required this.timestamp,
    required this.isCompleted,
    this.imageUrl,
    this.note,
  });

  // สร้างจาก Firestore
  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] ?? '',
      bookingId: json['bookingId'] ?? '',
      sitterId: json['sitterId'] ?? '',
      userId: json['userId'] ?? '',
      catId: json['catId'] ?? '',
      description: json['description'] ?? '',
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      isCompleted: json['isCompleted'] ?? false,
      imageUrl: json['imageUrl'],
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'sitterId': sitterId,
      'userId': userId,
      'catId': catId,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'isCompleted': isCompleted,
      'imageUrl': imageUrl,
      'note': note,
    };
  }

  // Getter สำหรับใช้ใน UI
  DateTime? get completedAt => isCompleted ? timestamp : null;

  String? get photoUrl => imageUrl;

  String? get notes => note;

  String get title => description;
}
