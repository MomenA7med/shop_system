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
  final double deliveryFee;
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
    this.deliveryFee = 0.0,
    this.paymentMethod = 'cash',
    this.status = 'completed',
    DateTime? createdAt,
    this.items = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalProfit => items.fold(0.0, (sum, item) => sum + item.profit);
  double get netProfit => items.fold(0.0, (sum, item) => sum + item.netProfit);
  double get totalItemCount => items.fold(0.0, (sum, item) => sum + item.quantity);
  double get totalPieces => totalItemCount;
  double get remainingItemCount => items.fold(0.0, (sum, item) => sum + item.remainingQuantity);
  double get remainingPieces => remainingItemCount;
  double get totalReturnedCount => items.fold(0.0, (sum, item) => sum + item.returnedQuantity);
  double get totalReturnedPieces => totalReturnedCount;
  int get activeItemsCount => items.where((i) => i.remainingQuantity > 0).length;
  int get returnedItemsCount => items.where((i) => i.returnedQuantity > 0).length;
  double get itemsSubtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get netItemsSubtotal => items.fold(0.0, (sum, item) => sum + item.netTotalPrice);
  double get refundedAmount => items.fold(0.0, (sum, item) => sum + item.refundedAmount);
  double get netTotalAmount => (totalAmount - refundedAmount).clamp(0.0, double.infinity);
  double get discountAmount => (itemsSubtotal + deliveryFee > totalAmount) ? (itemsSubtotal + deliveryFee - totalAmount) : 0.0;
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
      'delivery_fee': deliveryFee,
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
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      status: map['status'] as String? ?? 'completed',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      items: items ?? [],
    );
  }

  OrderModel copyWith({
    int? id,
    String? invoiceNumber,
    int? cashierId,
    String? cashierName,
    int? shiftId,
    double? totalAmount,
    double? amountPaid,
    double? changeDue,
    double? deliveryFee,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
    List<OrderItemModel>? items,
  }) {
    return OrderModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      shiftId: shiftId ?? this.shiftId,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      changeDue: changeDue ?? this.changeDue,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}
