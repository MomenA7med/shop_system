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
  double get netProfit => items.fold(0.0, (sum, item) => sum + item.netProfit);
  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);
  int get totalPieces => totalItemCount;
  int get remainingItemCount => items.fold(0, (sum, item) => sum + item.remainingQuantity);
  int get remainingPieces => remainingItemCount;
  int get totalReturnedCount => items.fold(0, (sum, item) => sum + item.returnedQuantity);
  int get totalReturnedPieces => totalReturnedCount;
  int get activeItemsCount => items.where((i) => i.remainingQuantity > 0).length;
  int get returnedItemsCount => items.where((i) => i.returnedQuantity > 0).length;
  double get itemsSubtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get netItemsSubtotal => items.fold(0.0, (sum, item) => sum + item.netTotalPrice);
  double get refundedAmount => items.fold(0.0, (sum, item) => sum + item.refundedAmount);
  double get netTotalAmount => (totalAmount - refundedAmount).clamp(0.0, double.infinity);
  double get discountAmount => itemsSubtotal > totalAmount ? (itemsSubtotal - totalAmount) : 0.0;
  bool get hasReturns => totalReturnedCount > 0 || status == 'refunded' || status == 'partially_refunded';
  bool get isFullyRefunded => status == 'refunded' || (remainingPieces == 0 && totalPieces > 0);
  bool get isPartiallyRefunded => status == 'partially_refunded' || (hasReturns && !isFullyRefunded);

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
      id: (map['id'] as num?)?.toInt(),
      invoiceNumber: map['invoice_number'] as String,
      cashierId: (map['cashier_id'] as num).toInt(),
      cashierName: cashierName ?? map['cashier_name'] as String?,
      shiftId: (map['shift_id'] as num?)?.toInt(),
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
