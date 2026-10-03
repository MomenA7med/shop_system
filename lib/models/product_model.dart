import 'product_variant_model.dart';

class ProductModel {
  final int? id;
  final int categoryId;
  final String? categoryName;
  final String name;
  final String description;
  final String season; // 'all', 'summer', 'winter'
  final DateTime createdAt;
  final List<ProductVariantModel> variants;

  ProductModel({
    this.id,
    required this.categoryId,
    this.categoryName,
    required this.name,
    this.description = '',
    this.season = 'all',
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

  String get seasonLabel {
    switch (season) {
      case 'summer':
        return 'صيفي';
      case 'winter':
        return 'شتوي';
      case 'all':
      default:
        return 'عام';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'season': season,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, {List<ProductVariantModel>? variants, String? categoryName}) {
    return ProductModel(
      id: (map['id'] as num?)?.toInt(),
      categoryId: (map['category_id'] as num).toInt(),
      categoryName: categoryName ?? map['category_name'] as String?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      season: map['season'] as String? ?? 'all',
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
    String? season,
    DateTime? createdAt,
    List<ProductVariantModel>? variants,
  }) {
    return ProductModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      description: description ?? this.description,
      season: season ?? this.season,
      createdAt: createdAt ?? this.createdAt,
      variants: variants ?? this.variants,
    );
  }
}
