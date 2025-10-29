import 'package:cloud_firestore/cloud_firestore.dart';

class EquipmentUsage {
  final String id;
  final String washerId;
  final String washerName;
  final String storeItemId;
  final String storeItemName;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final DateTime date;
  final bool isPaid;
  final DateTime? paidDate;

  EquipmentUsage({
    required this.id,
    required this.washerId,
    required this.washerName,
    required this.storeItemId,
    required this.storeItemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.date,
    this.isPaid = false,
    this.paidDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'washerId': washerId,
      'washerName': washerName,
      'storeItemId': storeItemId,
      'storeItemName': storeItemName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalAmount': totalAmount,
      'date': Timestamp.fromDate(date),
      'isPaid': isPaid,
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
    };
  }

  factory EquipmentUsage.fromMap(Map<String, dynamic> map) {
    return EquipmentUsage(
      id: map['id'],
      washerId: map['washerId'],
      washerName: map['washerName'],
      storeItemId: map['storeItemId'],
      storeItemName: map['storeItemName'],
      quantity: map['quantity'],
      unitPrice: map['unitPrice'] is double
          ? map['unitPrice']
          : map['unitPrice'].toDouble(),
      totalAmount: map['totalAmount'] is double
          ? map['totalAmount']
          : map['totalAmount'].toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      isPaid: map['isPaid'] ?? false,
      paidDate: map['paidDate'] != null
          ? (map['paidDate'] as Timestamp).toDate()
          : null,
    );
  }
}
