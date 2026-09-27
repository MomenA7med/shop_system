class ProductVariantModel {
  final int? id;
  final int productId;
  final String skuBarcode;
  final String size;
  final String color;
  final double costPrice;
  final double sellingPrice;
  final int stockQuantity;
  final int minStockAlert;

  ProductVariantModel({
    this.id,
    required this.productId,
    required this.skuBarcode,
    required this.size,
    required this.color,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    this.minStockAlert = 2,
  });

  bool get isLowStock => stockQuantity <= minStockAlert && stockQuantity > 0;
  bool get isOutOfStock => stockQuantity <= 0;
  double get profitMargin => sellingPrice - costPrice;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'sku_barcode': skuBarcode,
      'size': size,
      'color': color,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'stock_quantity': stockQuantity,
      'min_stock_alert': minStockAlert,
    };
  }

  factory ProductVariantModel.fromMap(Map<String, dynamic> map) {
    return ProductVariantModel(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      skuBarcode: map['sku_barcode'] as String,
      size: map['size'] as String,
      color: map['color'] as String,
      costPrice: (map['cost_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      stockQuantity: map['stock_quantity'] as int,
      minStockAlert: (map['min_stock_alert'] as int?) ?? 2,
    );
  }

  ProductVariantModel copyWith({
    int? id,
    int? productId,
    String? skuBarcode,
    String? size,
    String? color,
    double? costPrice,
    double? sellingPrice,
    int? stockQuantity,
    int? minStockAlert,
  }) {
    return ProductVariantModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      skuBarcode: skuBarcode ?? this.skuBarcode,
      size: size ?? this.size,
      color: color ?? this.color,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockAlert: minStockAlert ?? this.minStockAlert,
    );
  }
}
