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
  int get remainingQuantity => quantity - returnedQuantity;

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
      id: map['id'] as int?,
      orderId: map['order_id'] as int?,
      variantId: map['variant_id'] as int,
      productId: map['product_id'] as int? ?? 0,
      productName: map['product_name'] as String,
      size: map['size'] as String? ?? '',
      color: map['color'] as String? ?? '',
      skuBarcode: map['sku_barcode'] as String? ?? '',
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      returnedQuantity: (map['returned_quantity'] as int?) ?? 0,
    );
  }
}
