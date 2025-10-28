import 'package:cloud_firestore/cloud_firestore.dart';

class Washer {
  final String id;
  final String name;
  final String? phone; // Make phone optional
  final double percentage;
  final bool isActive;
  final DateTime createdAt;

  Washer({
    required this.id,
    required this.name,
    this.phone, // Now optional
    required this.percentage,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone, // Can be null
      'percentage': percentage,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Washer.fromMap(Map<String, dynamic> map) {
    try {
      return Washer(
        id: map['id']?.toString() ?? '', // Ensure ID is never null
        name: map['name']?.toString() ?? '',
        phone: map['phone']?.toString(), // Can be null
        percentage: (map['percentage'] as num?)?.toDouble() ?? 50.0,
        isActive: map['isActive'] as bool? ?? true,
        createdAt: (map['createdAt'] is Timestamp)
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    } catch (e) {
      return Washer(
        id: map['id']?.toString() ?? 'error',
        name: 'Unknown Washer',
        percentage: 50.0,
        isActive: false,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  String toString() {
    return 'Washer(id: $id, name: $name, phone: $phone, percentage: $percentage, isActive: $isActive)';
  }
}
