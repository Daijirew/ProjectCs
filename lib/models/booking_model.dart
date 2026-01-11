import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String? id;
  final String userId;
  final String sitterId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final String status;
  final String? petId;
  final Map<String, dynamic>? serviceDetails;
  final DateTime? expirationTime;

  BookingModel({
    this.id,
    required this.userId,
    required this.sitterId,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    this.status = 'pending',
    this.petId,
    this.serviceDetails,
    this.expirationTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'sitterId': sitterId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalPrice': totalPrice,
      'status': status,
      'petId': petId,
      'serviceDetails': serviceDetails,
      'expirationTime':
          expirationTime != null ? Timestamp.fromDate(expirationTime!) : null,
    };
  }

  factory BookingModel.fromMap(Map<String, dynamic> map, String id) {
    return BookingModel(
      id: id,
      userId: map['userId'] ?? '',
      sitterId: map['sitterId'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      totalPrice: (map['totalPrice'] is int)
          ? (map['totalPrice'] as int).toDouble()
          : map['totalPrice'] ?? 0.0,
      status: map['status'] ?? 'pending',
      petId: map['petId'],
      serviceDetails: map['serviceDetails'],
      expirationTime: map['expirationTime'] != null
          ? (map['expirationTime'] as Timestamp).toDate()
          : null,
    );
  }
}
