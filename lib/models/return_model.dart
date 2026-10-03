class ReturnModel {
  final int? id;
  final int orderId;
  final int orderItemId;
  final int variantId;
  final int? shiftId;
  final String productName;
  final String size;
  final String color;
  final String skuBarcode;
  final int quantity;
  final double refundAmount;
  final String reason;
  final DateTime createdAt;

  ReturnModel({
    this.id,
    required this.orderId,
    required this.orderItemId,
    required this.variantId,
    this.shiftId,
    required this.productName,
    required this.size,
    required this.color,
    required this.skuBarcode,
    required this.quantity,
    required this.refundAmount,
    this.reason = 'طلب العميل',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'order_item_id': orderItemId,
      'variant_id': variantId,
      'shift_id': shiftId,
      'product_name': productName,
      'size': size,
      'color': color,
      'sku_barcode': skuBarcode,
      'quantity': quantity,
      'refund_amount': refundAmount,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReturnModel.fromMap(Map<String, dynamic> map) {
    return ReturnModel(
      id: (map['id'] as num?)?.toInt(),
      orderId: (map['order_id'] as num).toInt(),
      orderItemId: (map['order_item_id'] as num).toInt(),
      variantId: (map['variant_id'] as num).toInt(),
      shiftId: (map['shift_id'] as num?)?.toInt(),
      productName: map['product_name'] as String? ?? '',
      size: map['size'] as String? ?? '',
      color: map['color'] as String? ?? '',
      skuBarcode: map['sku_barcode'] as String? ?? '',
      quantity: (map['quantity'] as num).toInt(),
      refundAmount: (map['refund_amount'] as num).toDouble(),
      reason: map['reason'] as String? ?? 'طلب العميل',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
