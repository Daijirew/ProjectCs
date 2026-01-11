import 'package:cloud_firestore/cloud_firestore.dart';

class SimpleChecklistItem {
  final String id;
  final String bookingId;
  final String catId;
  final String catName;
  final String task;
  bool isCompleted;
  DateTime? completedAt;

  SimpleChecklistItem({
    required this.id,
    required this.bookingId,
    required this.catId,
    required this.catName,
    required this.task,
    this.isCompleted = false,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'catId': catId,
      'catName': catName,
      'task': task,
      'isCompleted': isCompleted,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory SimpleChecklistItem.fromMap(Map<String, dynamic> map) {
    return SimpleChecklistItem(
      id: map['id'] ?? '',
      bookingId: map['bookingId'] ?? '',
      catId: map['catId'] ?? '',
      catName: map['catName'] ?? '',
      task: map['task'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
