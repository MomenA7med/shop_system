import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/product_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';
import 'barcode_print_dialog.dart';
import 'product_form_dialog.dart';

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadInventory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة تصنيف جديد'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم التصنيف'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await context.read<InventoryProvider>().addCategory(nameCtrl.text.trim());
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inventory = context.watch<InventoryProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final products = inventory.products;

    return Scaffold(
      backgroundColor: colors.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.productsList,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إجمالي المنتجات: ${products.length} موديل',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.category_outlined, size: 18),
                      label: const Text('إضافة تصنيف'),
                      onPressed: _showAddCategoryDialog,
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(AppStrings.addNewProduct),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const ProductFormDialog(),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Search Bar & Filters
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'البحث عن منتج، باركود، مقاس أو لون...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  inventory.setSearchQuery('');
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) => inventory.setSearchQuery(val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Category Dropdown Filter
                  DropdownButton<int?>(
                    value: inventory.selectedCategoryId,
                    dropdownColor: colors.surface,
                    underline: const SizedBox(),
                    hint: Text('جميع التصنيفات', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('جميع التصنيفات'),
                      ),
                      ...inventory.categories.map((c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name),
                      )),
                    ],
                    onChanged: (val) => inventory.selectCategory(val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Inventory Data Table
            Expanded(
              child: inventory.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: colors.textMuted.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text('لا توجد منتجات مطابقة', style: TextStyle(color: colors.textMuted)),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ListView.separated(
                              itemCount: products.length + 1,
                              separatorBuilder: (_, _) => const Divider(),
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return _buildTableHeader(context);
                                }
                                final product = products[index - 1];
                                return _buildTableRow(context, product, settings.currencySymbol, index);
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.cardSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary))),
          Expanded(flex: 3, child: Text(AppStrings.productName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary))),
          Expanded(flex: 2, child: Text(AppStrings.category, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary))),
          Expanded(flex: 4, child: Text('المقاسات والألوان المتاحة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary))),
          Expanded(flex: 2, child: Text('نطاق السعر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary))),
          Expanded(flex: 2, child: Text(AppStrings.stockQuantity, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary))),
          SizedBox(width: 140, child: Text('الإجراءات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, ProductModel product, String currencySymbol, int index) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('$index', style: TextStyle(color: colors.textMuted, fontSize: 12))),
          
          // Product Name
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary),
                ),
                if (product.description.isNotEmpty)
                  Text(
                    product.description,
                    style: TextStyle(fontSize: 10, color: colors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Category
          Expanded(
            flex: 2,
            child: Text(
              product.categoryName ?? '-',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),

          // Variants chips with Barcode Print Quick Trigger
          Expanded(
            flex: 4,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: product.variants.map((v) {
                return InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => BarcodePrintDialog(
                        productName: product.name,
                        variant: v,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: v.isLowStock
                          ? AppColors.warning.withValues(alpha: 0.15)
                          : (v.isOutOfStock ? AppColors.error.withValues(alpha: 0.15) : colors.cardSurface),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: v.isLowStock
                            ? AppColors.warning
                            : (v.isOutOfStock ? AppColors.error : colors.border),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${v.size} - ${v.color} (${v.stockQuantity})',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: v.isLowStock
                                ? AppColors.warning
                                : (v.isOutOfStock ? AppColors.error : colors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.qr_code, size: 12, color: colors.textMuted),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Price Range
          Expanded(
            flex: 2,
            child: Text(
              product.minPrice == product.maxPrice
                  ? CurrencyFormatter.format(product.minPrice, symbol: currencySymbol)
                  : '${CurrencyFormatter.formatSimple(product.minPrice)} - ${CurrencyFormatter.format(product.maxPrice, symbol: currencySymbol)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.primaryLight),
            ),
          ),

          // Total Stock Badge
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: product.totalStock > 0
                        ? (product.hasLowStock ? AppColors.warning.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15))
                        : AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${product.totalStock} قطعة',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: product.totalStock > 0
                          ? (product.hasLowStock ? AppColors.warning : colors.primaryLight)
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Actions
          SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.secondary),
                  tooltip: AppStrings.edit,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => ProductFormDialog(existingProduct: product),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  tooltip: AppStrings.delete,
                  onPressed: () {
                    _confirmDeleteProduct(context, product);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل أنت متأكد من رغبتك في حذف "${product.name}" مع جميع مقاساته وألوانه؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              if (product.id != null) {
                await context.read<InventoryProvider>().deleteProduct(product.id!);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }
}
