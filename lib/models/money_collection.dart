import 'package:cloud_firestore/cloud_firestore.dart';

class MoneyCollection {
  final String id;
  final String collectedBy;
  final String collectedByName;
  final double totalAmount;
  final DateTime collectionDate;
  final DateTime createdAt;
  final String? notes;

  final double? dailyOwnerShare;
  final double? equipmentRevenue;
  final double? totalExpenses;
  final double? netAmountDue;
  final double? netProfit; // ADD THIS
  final double? remainingBalance;

  MoneyCollection({
    required this.id,
    required this.collectedBy,
    required this.collectedByName,
    required this.totalAmount,
    required this.collectionDate,
    required this.createdAt,
    this.notes,
    this.dailyOwnerShare,
    this.equipmentRevenue,
    this.totalExpenses,
    this.netAmountDue,
    this.netProfit, // ADD THIS
    this.remainingBalance,
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
      'dailyOwnerShare': dailyOwnerShare,
      'equipmentRevenue': equipmentRevenue,
      'totalExpenses': totalExpenses,
      'netAmountDue': netAmountDue,
      'netProfit': netProfit, // ADD THIS
      'remainingBalance': remainingBalance,
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
        dailyOwnerShare: (map['dailyOwnerShare'] as num?)?.toDouble(),
        equipmentRevenue: (map['equipmentRevenue'] as num?)?.toDouble(),
        totalExpenses: (map['totalExpenses'] as num?)?.toDouble(),
        netAmountDue: (map['netAmountDue'] as num?)?.toDouble(),
        netProfit: (map['netProfit'] as num?)?.toDouble(), // ADD THIS
        remainingBalance: (map['remainingBalance'] as num?)?.toDouble(),
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
