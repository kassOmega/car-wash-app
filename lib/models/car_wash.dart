import 'package:cloud_firestore/cloud_firestore.dart';

class CarWash {
  final String id;
  final String? customerId;
  final String washerId;
  final String vehicleType;
  final double amount;
  final DateTime date;
  final String? notes;
  final String? recordedBy;

  CarWash({
    required this.id,
    this.customerId,
    required this.washerId,
    required this.vehicleType,
    required this.amount,
    required this.date,
    this.notes,
    this.recordedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'washerId': washerId,
      'vehicleType': vehicleType,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'recordedBy': recordedBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static CarWash fromMap(Map<String, dynamic> map) {
    return CarWash(
      id: map['id'],
      customerId: map['customerId'],
      washerId: map['washerId'],
      vehicleType: map['vehicleType'],
      amount: (map['amount'] as num).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      notes: map['notes'],
      recordedBy: map['recordedBy'],
    );
  }
}
