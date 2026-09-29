import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/number_parser.dart';
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
      if (pos.isQuickFilterOnly) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    size: 48,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'لم يتم تعيين أصناف سريعة بعد',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'يمكنك تفعيل خيار (صنف سريع ⭐) داخل شاشة المنتجات لتظهر هنا مباشرة للبيع بضغطة زر واحدة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 54,
              color: colors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد أصناف مطابقة للبحث أو القسم',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (pos.searchQuery.isNotEmpty || pos.selectedCategoryId != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('إعادة ضبط البحث والأقسام'),
                onPressed: () {
                  pos.clearSearch();
                  pos.selectCategory(null);
                },
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 210,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(
          context,
          product,
          settings.currencySymbol,
          pos,
          colors,
        );
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
    final variants = product.variants;
    final displayVariantsCount = variants.length > 3 ? 2 : variants.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!hasStock) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('هذا الصنف غير متوفر في المخزن حالياً'),
              ),
            );
            return;
          }
          if (variants.length == 1) {
            pos.addVariantToCart(product, variants.first);
          } else {
            _showVariantSelectionDialog(
              context,
              product,
              currencySymbol,
              pos,
              colors,
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: product.hasLowStock
                  ? colors.warning.withValues(alpha: 0.6)
                  : (product.isQuickItem
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : colors.border),
              width: product.isQuickItem || product.hasLowStock ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isDark ? 6 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Category Badge & Quick Item Badge & Stock Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (product.isQuickItem) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flash_on_rounded,
                                size: 11,
                                color: Colors.amber,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'سريع',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (product.categoryName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondary.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.categoryName!,
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark
                                  ? const Color(0xFF818CF8)
                                  : const Color(0xFF4F46E5),
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: hasStock
                          ? (product.hasLowStock
                                ? colors.warning.withValues(alpha: 0.15)
                                : colors.primary.withValues(alpha: 0.15))
                          : colors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hasStock
                          ? 'مخزون: ${NumberParser.formatQuantity(product.totalStock)}'
                          : AppStrings.outOfStock,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: hasStock
                            ? (product.hasLowStock
                                  ? colors.warning
                                  : (isDark
                                        ? colors.primaryLight
                                        : colors.primaryDark))
                            : colors.error,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Product Name (2 Lines Max)
              SizedBox(
                height: 38,
                child: Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const Spacer(),

              // Variant Direct-Tap Chips (1-tap add to cart)
              if (variants.length > 1)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ...variants.take(displayVariantsCount).map((variant) {
                      final isOutOfStock = variant.stockQuantity <= 0;
                      final hasDesc = variant.color.isNotEmpty &&
                          variant.color != '-' &&
                          variant.color != 'افتراضي';
                      final label = hasDesc
                          ? '${variant.size} (${variant.color})'
                          : variant.size;

                      return Tooltip(
                        message:
                            '$label - السعر: ${variant.sellingPrice} - متبقي: ${variant.stockQuantity}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: isOutOfStock
                              ? null
                              : () {
                                  pos.addVariantToCart(product, variant);
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isOutOfStock
                                  ? colors.cardSurface
                                  : (isDark
                                        ? colors.surfaceLight
                                        : colors.surfaceLight.withValues(
                                            alpha: 0.7,
                                          )),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isOutOfStock
                                    ? colors.border
                                    : colors.primary.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '+ $label (${variant.sellingPrice.toStringAsFixed(0)}ج)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isOutOfStock
                                    ? colors.textMuted
                                    : colors.textPrimary,
                                decoration: isOutOfStock
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (variants.length > 3)
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          _showVariantSelectionDialog(
                            context,
                            product,
                            currencySymbol,
                            pos,
                            colors,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune, size: 11, color: colors.primary),
                              const SizedBox(width: 3),
                              Text(
                                '+${variants.length - 2} المزيد',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

              const SizedBox(height: 6),

              // Price Tag & Add to Cart button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.minPrice == product.maxPrice
                        ? CurrencyFormatter.format(
                            product.minPrice,
                            symbol: currencySymbol,
                          )
                        : '${CurrencyFormatter.format(product.minPrice, symbol: "")} - ${CurrencyFormatter.format(product.maxPrice, symbol: currencySymbol)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? colors.primaryLight : colors.primaryDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      variants.length > 1
                          ? Icons.tune_rounded
                          : Icons.add_shopping_cart_rounded,
                      size: 16,
                      color: isDark ? colors.primaryLight : colors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVariantSelectionDialog(
    BuildContext context,
    ProductModel product,
    String currencySymbol,
    POSProvider pos,
    AppColorsExtension colors,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 580,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modal Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: colors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'الوحدات والخيارات المتاحة (${product.variants.length} خيار) • إجمالي المخزون: ${NumberParser.formatQuantity(product.totalStock)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: IconButton.styleFrom(
                          foregroundColor: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Divider(color: colors.border, height: 1),
                  const SizedBox(height: 14),

                  // Subtitle Instruction
                  Text(
                    'اختر الوحدة أو المتغير المطلوب إضافته للفاتورة:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Variants Full Grid / Wrap
                  Flexible(
                    child: SingleChildScrollView(
                      child: Consumer<POSProvider>(
                        builder: (ctx, posWatcher, _) {
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: product.variants.map((variant) {
                              final isOutOfStock = variant.stockQuantity <= 0;
                              final isLowStock = variant.isLowStock;
                              final hasDesc = variant.color.isNotEmpty &&
                                  variant.color != '-' &&
                                  variant.color != 'افتراضي';

                              // Check how many of this variant are already in cart
                              final cartMatches = posWatcher.cartItems.where(
                                (item) => item.variantId == variant.id,
                              );
                              final inCartCount = cartMatches.isNotEmpty
                                  ? cartMatches.first.quantity
                                  : 0;

                              return Container(
                                width: 170,
                                decoration: BoxDecoration(
                                  color: isOutOfStock
                                      ? colors.cardSurface.withValues(
                                          alpha: 0.5,
                                        )
                                      : (inCartCount > 0
                                            ? colors.primary.withValues(
                                                alpha: 0.08,
                                              )
                                            : colors.cardSurface),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isOutOfStock
                                        ? colors.border
                                        : (inCartCount > 0
                                              ? colors.primary
                                              : colors.border),
                                    width: inCartCount > 0 ? 1.5 : 1,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: isOutOfStock
                                        ? null
                                        : () {
                                            pos.addVariantToCart(
                                              product,
                                              variant,
                                            );
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Top row: Size/Unit badge & In-Cart badge
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colors.primary
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  variant.size,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: colors.isDark
                                                        ? colors.primaryLight
                                                        : colors.primaryDark,
                                                  ),
                                                ),
                                              ),
                                              if (inCartCount > 0)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: colors.primary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'في السلة: ${NumberParser.formatQuantity(inCartCount)}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),

                                          if (hasDesc) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              variant.color,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: colors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],

                                          const SizedBox(height: 6),

                                          // Price
                                          Text(
                                            CurrencyFormatter.format(
                                              variant.sellingPrice,
                                              symbol: currencySymbol,
                                            ),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: colors.isDark
                                                  ? colors.primaryLight
                                                  : colors.primaryDark,
                                            ),
                                          ),

                                          const SizedBox(height: 6),

                                          // Stock status & Add action
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                isOutOfStock
                                                    ? 'نفذ من المخزن'
                                                    : (isLowStock
                                                          ? 'متبقي: ${NumberParser.formatQuantity(variant.stockQuantity)}'
                                                          : 'المتاح: ${NumberParser.formatQuantity(variant.stockQuantity)}'),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: isOutOfStock
                                                      ? colors.error
                                                      : (isLowStock
                                                            ? colors.warning
                                                            : colors.textMuted),
                                                ),
                                              ),
                                              if (!isOutOfStock)
                                                Icon(
                                                  Icons.add_circle,
                                                  color: colors.primary,
                                                  size: 20,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Divider(color: colors.border, height: 1),
                  const SizedBox(height: 12),

                  // Bottom Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text(
                          'تم الانتهاء',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
