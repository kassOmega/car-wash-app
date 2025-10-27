import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String role; // 'owner', 'cashier', 'washer'
  final DateTime createdAt;
  final String? name;
  final String? phone;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.createdAt,
    this.name,
    this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'name': name,
      'phone': phone,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static AppUser fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'],
      email: map['email'],
      role: map['role'],
      name: map['name'],
      phone: map['phone'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  bool get isOwner => role == 'owner';
  bool get isCashier => role == 'cashier';
  bool get isWasher => role == 'washer';
}
