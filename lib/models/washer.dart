import 'package:cloud_firestore/cloud_firestore.dart';

class Washer {
  final String id;
  final String name;
  final String phone;
  final double percentage;
  final bool isActive;
  final DateTime createdAt;

  Washer({
    required this.id,
    required this.name,
    required this.phone,
    required this.percentage,
    this.isActive = true, // Default to active
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'percentage': percentage,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Washer.fromMap(Map<String, dynamic> map) {
    try {
      return Washer(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        phone: map['phone']?.toString() ?? '',
        percentage: (map['percentage'] as num?)?.toDouble() ?? 50.0,
        isActive: map['isActive'] as bool? ?? true,
        createdAt: (map['createdAt'] is Timestamp)
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    } catch (e) {
      print('Error parsing Washer: $e');
      return Washer(
        id: map['id']?.toString() ?? 'error',
        name: map['name']?.toString() ?? 'Unknown',
        phone: map['phone']?.toString() ?? '',
        percentage: 50.0,
        isActive: true,
        createdAt: DateTime.now(),
      );
    }
  }
}
