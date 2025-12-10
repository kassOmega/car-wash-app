import '../models/car_wash.dart';
import '../models/washer.dart';

class CommissionCalculator {
  // Calculate commission for a specific washer from a car wash
  static double calculateWasherCommission({
    required CarWash carWash,
    required String washerId,
    required Map<String, Washer> washersById,
  }) {
    // Get all washers involved in this car wash
    final allWasherIds =
        [carWash.washerId, ...carWash.participantWasherIds].toSet().toList();

    // Find the washer
    final washer = washersById[washerId];
    if (washer == null) return 0.0;

    // Calculate commission using your formula
    final washerShare = washer.percentage / 100.0;
    final commission = (carWash.amount * washerShare) / allWasherIds.length;

    return commission;
  }

  // Calculate commissions for all washers in a car wash
  static Map<String, double> calculateAllCommissions({
    required CarWash carWash,
    required Map<String, Washer> washersById,
  }) {
    final commissions = <String, double>{};

    // Get all washers involved
    final allWasherIds =
        [carWash.washerId, ...carWash.participantWasherIds].toSet().toList();

    for (final washerId in allWasherIds) {
      final washer = washersById[washerId];
      if (washer != null) {
        final washerShare = washer.percentage / 100.0;
        final commission = (carWash.amount * washerShare) / allWasherIds.length;
        commissions[washerId] = commission;
      }
    }

    return commissions;
  }

  // Calculate owner's share (remaining after all commissions)
  static double calculateOwnerShare({
    required CarWash carWash,
    required Map<String, double> commissions,
  }) {
    final totalCommission =
        commissions.values.fold(0.0, (sum, commission) => sum + commission);
    return carWash.amount - totalCommission;
  }
}
