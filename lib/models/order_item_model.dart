class OrderItemModel {
  final int? id;
  final int? orderId;
  final int variantId;
  final int productId;
  final String productName;
  final String size;
  final String color;
  final String skuBarcode;
  int quantity;
  final double unitPrice;
  final double costPrice;
  int returnedQuantity;

  OrderItemModel({
    this.id,
    this.orderId,
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.size,
    required this.color,
    required this.skuBarcode,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    this.returnedQuantity = 0,
  });

  double get totalPrice => quantity * unitPrice;
  double get totalCost => quantity * costPrice;
  double get profit => totalPrice - totalCost;
  int get remainingQuantity => (quantity - returnedQuantity).clamp(0, quantity);
  double get netTotalPrice => remainingQuantity * unitPrice;
  double get netCost => remainingQuantity * costPrice;
  double get netProfit => netTotalPrice - netCost;
  double get refundedAmount => returnedQuantity * unitPrice;
  bool get isFullyReturned => remainingQuantity <= 0 && quantity > 0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      'variant_id': variantId,
      'product_id': productId,
      'product_name': productName,
      'size': size,
      'color': color,
      'sku_barcode': skuBarcode,
      'quantity': quantity,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'returned_quantity': returnedQuantity,
    };
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: (map['id'] as num?)?.toInt(),
      orderId: (map['order_id'] as num?)?.toInt(),
      variantId: (map['variant_id'] as num).toInt(),
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      productName: map['product_name'] as String,
      size: map['size'] as String? ?? '',
      color: map['color'] as String? ?? '',
      skuBarcode: map['sku_barcode'] as String? ?? '',
      quantity: (map['quantity'] as num).toInt(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      returnedQuantity: (map['returned_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}
