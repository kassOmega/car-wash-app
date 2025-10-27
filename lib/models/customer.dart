import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String phone;
  final String customerType;
  final DateTime registrationDate;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.customerType,
    required this.registrationDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'customerType': customerType,
      'registrationDate': Timestamp.fromDate(registrationDate),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Customer fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      customerType: map['customerType'],
      registrationDate: (map['registrationDate'] as Timestamp).toDate(),
    );
  }
}
