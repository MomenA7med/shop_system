import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/product_model.dart';
import '../../../providers/pos_provider.dart';
import '../../../providers/settings_provider.dart';

class ProductCardGrid extends StatelessWidget {
  const ProductCardGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pos = context.watch<POSProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final products = pos.products;

    if (pos.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: colors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'لا توجد منتجات مطابقة',
              style: TextStyle(color: colors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 185,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(context, product, settings.currencySymbol, pos, colors);
      },
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    ProductModel product,
    String currencySymbol,
    POSProvider pos,
    AppColorsExtension colors,
  ) {
    final hasStock = product.totalStock > 0;
    final isDark = colors.isDark;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: product.hasLowStock ? colors.warning.withValues(alpha: 0.5) : colors.border,
          width: product.hasLowStock ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
            blurRadius: isDark ? 6 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Badge & Stock Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (product.categoryName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.secondary.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.categoryName!,
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hasStock
                      ? (product.hasLowStock ? colors.warning.withValues(alpha: 0.15) : colors.primary.withValues(alpha: 0.15))
                      : colors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasStock ? 'المخزون: ${product.totalStock}' : AppStrings.outOfStock,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: hasStock
                        ? (product.hasLowStock ? colors.warning : (isDark ? colors.primaryLight : colors.primaryDark))
                        : colors.error,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Product Name
          Text(
            product.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // Variant Selection Chips (Sizes/Colors)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: product.variants.map((variant) {
                final isOutOfStock = variant.stockQuantity <= 0;
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: '${variant.color} - السعر: ${variant.sellingPrice} - متبقي: ${variant.stockQuantity}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: isOutOfStock
                          ? null
                          : () {
                              pos.addVariantToCart(product, variant);
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? colors.cardSurface
                              : (isDark ? colors.surfaceLight : colors.surfaceLight.withValues(alpha: 0.7)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isOutOfStock
                                ? colors.border
                                : colors.primary.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '${variant.size} - ${variant.color}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isOutOfStock ? colors.textMuted : colors.textPrimary,
                            decoration: isOutOfStock ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Price Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                product.minPrice == product.maxPrice
                    ? CurrencyFormatter.format(product.minPrice, symbol: currencySymbol)
                    : '${CurrencyFormatter.format(product.minPrice, symbol: "")} - ${CurrencyFormatter.format(product.maxPrice, symbol: currencySymbol)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? colors.primaryLight : colors.primaryDark,
                ),
              ),
              Icon(Icons.add_shopping_cart_rounded, size: 16, color: isDark ? colors.primaryLight : colors.primary),
            ],
          ),
        ],
      ),
    );
  }
}
