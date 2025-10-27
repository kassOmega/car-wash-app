import 'package:cloud_firestore/cloud_firestore.dart';

class Washer {
  final String id;
  final String name;
  final String phone;
  final double percentage;
  final bool isActive;

  Washer({
    required this.id,
    required this.name,
    required this.phone,
    required this.percentage,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'percentage': percentage,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Washer fromMap(Map<String, dynamic> map) {
    return Washer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      percentage: (map['percentage'] as num).toDouble(),
      isActive: map['isActive'] ?? true,
    );
  }
}
