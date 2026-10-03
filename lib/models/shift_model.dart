class ShiftModel {
  final int? id;
  final int cashierId;
  final String? cashierName;
  final double openingFloat;
  double cashSales;
  double cashReturns;
  double actualCash;
  String status; // 'open' | 'closed'
  final DateTime startTime;
  DateTime? endTime;

  ShiftModel({
    this.id,
    required this.cashierId,
    this.cashierName,
    required this.openingFloat,
    this.cashSales = 0.0,
    this.cashReturns = 0.0,
    this.actualCash = 0.0,
    this.status = 'open',
    DateTime? startTime,
    this.endTime,
  }) : startTime = startTime ?? DateTime.now();

  double get expectedCash => openingFloat + cashSales - cashReturns;
  double get discrepancy => actualCash - expectedCash;
  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  bool get isBalanced => discrepancy.abs() < 0.01;
  bool get hasShortage => discrepancy < -0.01;
  bool get hasOverage => discrepancy > 0.01;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cashier_id': cashierId,
      'opening_float': openingFloat,
      'cash_sales': cashSales,
      'cash_returns': cashReturns,
      'expected_cash': expectedCash,
      'actual_cash': actualCash,
      'discrepancy': discrepancy,
      'status': status,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map, {String? cashierName}) {
    return ShiftModel(
      id: (map['id'] as num?)?.toInt(),
      cashierId: (map['cashier_id'] as num).toInt(),
      cashierName: cashierName ?? map['cashier_name'] as String?,
      openingFloat: (map['opening_float'] as num).toDouble(),
      cashSales: (map['cash_sales'] as num?)?.toDouble() ?? 0.0,
      cashReturns: (map['cash_returns'] as num?)?.toDouble() ?? 0.0,
      actualCash: (map['actual_cash'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'open',
      startTime: DateTime.tryParse(map['start_time']?.toString() ?? '') ?? DateTime.now(),
      endTime: map['end_time'] != null ? DateTime.tryParse(map['end_time'].toString()) : null,
    );
  }
}
