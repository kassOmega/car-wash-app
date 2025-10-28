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

  factory AppUser.fromMap(Map<String, dynamic> map) {
    try {
      // Handle createdAt - it could be Timestamp or DateTime
      DateTime createdAt;
      if (map['createdAt'] is Timestamp) {
        createdAt = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is DateTime) {
        createdAt = map['createdAt'] as DateTime;
      } else {
        createdAt = DateTime.now();
      }

      return AppUser(
        uid: map['uid']?.toString() ?? '',
        email: map['email']?.toString() ?? '',
        role: map['role']?.toString()?.toLowerCase() ?? 'user',
        name: map['name']?.toString(),
        phone: map['phone']?.toString(),
        createdAt: createdAt,
      );
    } catch (e) {
      print('Error parsing AppUser: $e');
      print('Map data: $map');
      // Return a default user instead of throwing to prevent app crashes
      return AppUser(
        uid: map['uid']?.toString() ?? 'unknown',
        email: map['email']?.toString() ?? 'unknown@example.com',
        role: 'user',
        createdAt: DateTime.now(),
      );
    }
  }

  bool get isOwner => role == 'owner';
  bool get isCashier => role == 'cashier';
  bool get isWasher => role == 'washer';

  @override
  String toString() {
    return 'AppUser(uid: $uid, email: $email, role: $role, name: $name, phone: $phone)';
  }
}
