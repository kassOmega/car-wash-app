// models/car_wash.dart - UPDATED
import 'package:cloud_firestore/cloud_firestore.dart';

class CarWash {
  final String id;
  final String? customerId;
  final String washerId;
  final List<String> participantWasherIds;
  final String vehicleType;
  final double amount;
  final DateTime date; // Registration/Start time
  final DateTime? completedAt; // Completion time
  final String? notes;
  final String? recordedBy;
  final String? plateNumber;
  final String status; // 'in_progress', 'completed'

  CarWash({
    required this.id,
    this.customerId,
    required this.washerId,
    required this.participantWasherIds,
    required this.vehicleType,
    required this.amount,
    required this.date,
    this.completedAt,
    this.notes,
    this.recordedBy,
    this.plateNumber,
    this.status = 'in_progress',
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
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'notes': notes,
      'recordedBy': recordedBy,
      'plateNumber': plateNumber,
      'status': status,
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
        completedAt: map['completedAt'] != null
            ? (map['completedAt'] as Timestamp).toDate()
            : null,
        notes: map['notes']?.toString(),
        recordedBy: map['recordedBy']?.toString(),
        plateNumber: map['plateNumber']?.toString(),
        status: map['status']?.toString() ?? 'in_progress',
      );
    } catch (e) {
      return CarWash(
        id: map['id']?.toString() ?? 'error',
        washerId: map['washerId']?.toString() ?? '',
        participantWasherIds: [],
        vehicleType: 'Car',
        amount: 0.0,
        date: DateTime.now(),
        status: 'in_progress',
      );
    }
  }

  CarWash copyWith({
    String? id,
    String? customerId,
    String? washerId,
    List<String>? participantWasherIds,
    String? vehicleType,
    double? amount,
    DateTime? date,
    DateTime? completedAt,
    String? notes,
    String? recordedBy,
    String? plateNumber,
    String? status,
  }) {
    return CarWash(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      washerId: washerId ?? this.washerId,
      participantWasherIds: participantWasherIds ?? this.participantWasherIds,
      vehicleType: vehicleType ?? this.vehicleType,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      recordedBy: recordedBy ?? this.recordedBy,
      plateNumber: plateNumber ?? this.plateNumber,
      status: status ?? this.status,
    );
  }

  bool get isCompleted => status == 'completed';
  Duration? get duration =>
      completedAt != null ? completedAt!.difference(date) : null;
}
