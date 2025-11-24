import 'package:cloud_firestore/cloud_firestore.dart';

class MoneyCollection {
  final String id;
  final String collectedBy; // Owner UID who collected the money
  final String collectedByName; // Owner name for display
  final double totalAmount;
  final DateTime collectionDate;
  final DateTime createdAt;
  final String? notes;

  MoneyCollection({
    required this.id,
    required this.collectedBy,
    required this.collectedByName,
    required this.totalAmount,
    required this.collectionDate,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collectedBy': collectedBy,
      'collectedByName': collectedByName,
      'totalAmount': totalAmount,
      'collectionDate': Timestamp.fromDate(collectionDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
    };
  }

  factory MoneyCollection.fromMap(Map<String, dynamic> map) {
    try {
      return MoneyCollection(
        id: map['id']?.toString() ?? '',
        collectedBy: map['collectedBy']?.toString() ?? '',
        collectedByName: map['collectedByName']?.toString() ?? '',
        totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
        collectionDate: (map['collectionDate'] is Timestamp)
            ? (map['collectionDate'] as Timestamp).toDate()
            : DateTime.now(),
        createdAt: (map['createdAt'] is Timestamp)
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        notes: map['notes']?.toString(),
      );
    } catch (e) {
      return MoneyCollection(
        id: 'error',
        collectedBy: '',
        collectedByName: 'Unknown',
        totalAmount: 0.0,
        collectionDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
    }
  }
}
