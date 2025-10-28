class Price {
  final String vehicleType;
  final double amount;

  Price({
    required this.vehicleType,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'vehicleType': vehicleType,
      'amount': amount,
    };
  }

  factory Price.fromMap(Map<String, dynamic> map) {
    return Price(
      vehicleType: map['vehicleType'],
      amount:
          map['amount'] is double ? map['amount'] : map['amount'].toDouble(),
    );
  }

  @override
  String toString() {
    return 'Price(vehicleType: $vehicleType, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Price &&
        other.vehicleType == vehicleType &&
        other.amount == amount;
  }

  @override
  int get hashCode => vehicleType.hashCode ^ amount.hashCode;
}
