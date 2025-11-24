import 'package:cloud_firestore/cloud_firestore.dart';

class CarWash {
  final String id;
  final String? customerId;
  final String washerId; // Responsible washer (gets commission)
  final List<String> participantWasherIds; // Other washers who helped
  final String vehicleType;
  final double amount;
  final DateTime date;
  final String? notes;
  final String? recordedBy;
  final String? plateNumber;

  CarWash({
    required this.id,
    this.customerId,
    required this.washerId,
    required this.participantWasherIds,
    required this.vehicleType,
    required this.amount,
    required this.date,
    this.notes,
    this.recordedBy,
    this.plateNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'washerId': washerId,
      'participantWasherIds': participantWasherIds,
      'vehicleType': vehicleType,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'recordedBy': recordedBy,
      'plateNumber': plateNumber,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory CarWash.fromMap(Map<String, dynamic> map) {
    try {
      return CarWash(
        id: map['id']?.toString() ?? '',
        customerId: map['customerId']?.toString(),
        washerId: map['washerId']?.toString() ?? '',
        participantWasherIds:
            List<String>.from(map['participantWasherIds'] ?? []),
        vehicleType: map['vehicleType']?.toString() ?? 'Car',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        date: (map['date'] is Timestamp)
            ? (map['date'] as Timestamp).toDate()
            : DateTime.now(),
        notes: map['notes']?.toString(),
        recordedBy: map['recordedBy']?.toString(),
        plateNumber: map['plateNumber']?.toString(),
      );
    } catch (e) {
      return CarWash(
        id: map['id']?.toString() ?? 'error',
        washerId: map['washerId']?.toString() ?? '',
        participantWasherIds: [],
        vehicleType: 'Car',
        amount: 0.0,
        date: DateTime.now(),
      );
    }
  }
}
