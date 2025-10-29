import 'package:cloud_firestore/cloud_firestore.dart';

class StoreItem {
  final String id;
  final String name;
  final String description;
  final double sellingPrice;
  final int currentStock;
  final int minimumStock;
  final DateTime createdAt;
  final DateTime updatedAt;

  StoreItem({
    required this.id,
    required this.name,
    required this.description,
    required this.sellingPrice,
    required this.currentStock,
    required this.minimumStock,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sellingPrice': sellingPrice,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory StoreItem.fromMap(Map<String, dynamic> map) {
    return StoreItem(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      sellingPrice: map['sellingPrice'] is double
          ? map['sellingPrice']
          : map['sellingPrice'].toDouble(),
      currentStock: map['currentStock'],
      minimumStock: map['minimumStock'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  StoreItem copyWith({
    String? id,
    String? name,
    String? description,
    double? sellingPrice,
    int? currentStock,
    int? minimumStock,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
