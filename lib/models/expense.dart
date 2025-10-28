import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String category;
  final double amount;
  final DateTime date;
  final String description;

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'description': description,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    try {
      return Expense(
        id: map['id']?.toString() ?? '',
        category: map['category']?.toString() ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        date: (map['date'] is Timestamp)
            ? (map['date'] as Timestamp).toDate()
            : DateTime.now(),
        description: map['description']?.toString() ?? '',
      );
    } catch (e) {
      print('Error parsing Expense: $e');
      return Expense(
        id: map['id']?.toString() ?? 'error',
        category: 'Unknown',
        amount: 0.0,
        date: DateTime.now(),
        description: 'Error loading expense',
      );
    }
  }
}
