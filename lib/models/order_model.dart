import 'order_item_model.dart';

class OrderModel {
  final int? id;
  final String invoiceNumber;
  final int cashierId;
  final String? cashierName;
  final int? shiftId;
  final double totalAmount;
  final double amountPaid;
  final double changeDue;
  final String paymentMethod; // 'cash'
  final String status; // 'completed' | 'refunded' | 'partially_refunded'
  final DateTime createdAt;
  final List<OrderItemModel> items;

  OrderModel({
    this.id,
    required this.invoiceNumber,
    required this.cashierId,
    this.cashierName,
    this.shiftId,
    required this.totalAmount,
    required this.amountPaid,
    required this.changeDue,
    this.paymentMethod = 'cash',
    this.status = 'completed',
    DateTime? createdAt,
    this.items = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalProfit => items.fold(0.0, (sum, item) => sum + item.profit);
  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'cashier_id': cashierId,
      'shift_id': shiftId,
      'total_amount': totalAmount,
      'amount_paid': amountPaid,
      'change_due': changeDue,
      'payment_method': paymentMethod,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, {List<OrderItemModel>? items, String? cashierName}) {
    return OrderModel(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      cashierId: map['cashier_id'] as int,
      cashierName: cashierName ?? map['cashier_name'] as String?,
      shiftId: map['shift_id'] as int?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      amountPaid: (map['amount_paid'] as num).toDouble(),
      changeDue: (map['change_due'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      status: map['status'] as String? ?? 'completed',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      items: items ?? [],
    );
  }
}
