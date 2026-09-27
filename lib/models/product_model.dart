import 'product_variant_model.dart';

class ProductModel {
  final int? id;
  final int categoryId;
  final String? categoryName;
  final String name;
  final String description;
  final DateTime createdAt;
  final List<ProductVariantModel> variants;

  ProductModel({
    this.id,
    required this.categoryId,
    this.categoryName,
    required this.name,
    this.description = '',
    DateTime? createdAt,
    this.variants = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalStock => variants.fold(0, (sum, v) => sum + v.stockQuantity);
  double get minPrice => variants.isEmpty
      ? 0.0
      : variants.map((v) => v.sellingPrice).reduce((a, b) => a < b ? a : b);
  double get maxPrice => variants.isEmpty
      ? 0.0
      : variants.map((v) => v.sellingPrice).reduce((a, b) => a > b ? a : b);

  bool get hasLowStock => variants.any((v) => v.isLowStock);
  bool get isAllOutOfStock => variants.isNotEmpty && variants.every((v) => v.isOutOfStock);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, {List<ProductVariantModel>? variants, String? categoryName}) {
    return ProductModel(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      categoryName: categoryName ?? map['category_name'] as String?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      variants: variants ?? [],
    );
  }

  ProductModel copyWith({
    int? id,
    int? categoryId,
    String? categoryName,
    String? name,
    String? description,
    DateTime? createdAt,
    List<ProductVariantModel>? variants,
  }) {
    return ProductModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      variants: variants ?? this.variants,
    );
  }
}
