import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/print_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/number_parser.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';
import 'barcode_print_dialog.dart';
import 'categories_management_dialog.dart';
import 'product_form_dialog.dart';

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isExportingPdf = false;
  bool _isExportingCsv = false;
  bool _isPrinting = false;

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

  void _showCategoriesManagementDialog() {
    showDialog(
      context: context,
      builder: (_) => const CategoriesManagementDialog(),
    );
  }

  String? _getSelectedCategoryName(InventoryProvider inventory) {
    if (inventory.selectedCategoryId == null) return null;
    try {
      return inventory.categories.firstWhere((c) => c.id == inventory.selectedCategoryId).name;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onPrintInventory() async {
    setState(() => _isPrinting = true);
    final inventory = context.read<InventoryProvider>();
    final settings = context.read<SettingsProvider>().settings;

    try {
      await PrintService.printInventoryReport(
        products: inventory.products,
        settings: settings,
        categoryFilterName: _getSelectedCategoryName(inventory),
        searchQuery: inventory.searchQuery.isNotEmpty ? inventory.searchQuery : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء طباعة تقرير المخزون: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _onExportPdf() async {
    setState(() => _isExportingPdf = true);
    final inventory = context.read<InventoryProvider>();
    final settings = context.read<SettingsProvider>().settings;

    try {
      final savedPath = await PrintService.exportInventoryReportPdf(
        products: inventory.products,
        settings: settings,
        categoryFilterName: _getSelectedCategoryName(inventory),
        searchQuery: inventory.searchQuery.isNotEmpty ? inventory.searchQuery : null,
      );

      if (mounted && savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير ملف تقرير المخزون PDF بنجاح: $savedPath'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تصدير ملف PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _onExportCsv() async {
    setState(() => _isExportingCsv = true);
    final inventory = context.read<InventoryProvider>();
    final settings = context.read<SettingsProvider>().settings;

    try {
      final savedPath = await PrintService.exportInventoryReportCsv(
        products: inventory.products,
        settings: settings,
        categoryFilterName: _getSelectedCategoryName(inventory),
        searchQuery: inventory.searchQuery.isNotEmpty ? inventory.searchQuery : null,
      );

      if (mounted && savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير ملف بيانات المخزون (Excel CSV) بنجاح: $savedPath'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تصدير ملف Excel: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  void _showVariantSelectionForPrint(BuildContext context, ProductModel product) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.print_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('اختر مقاس/لون للطباعة', style: TextStyle(fontSize: 16, color: colors.textPrimary)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المنتج: ${product.name}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                'اختر المقاس واللون لفتح نافذة طباعة ملصق الباركود:',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: product.variants.map((v) {
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.cardSurface,
                      foregroundColor: colors.textPrimary,
                      elevation: 0,
                      side: BorderSide(color: colors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.qr_code, size: 16, color: AppColors.primary),
                    label: Text('${v.size} - ${v.color} (المخزون: ${v.stockQuantity})', style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      showDialog(
                        context: context,
                        builder: (_) => BarcodePrintDialog(
                          productName: product.name,
                          variant: v,
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppStrings.cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
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
                      'إجمالي المنتجات: ${products.length} موديل | ${inventory.totalStockPieces} قطعة',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
                if (isAdmin)
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: _isExportingPdf
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text('تصدير PDF'),
                        onPressed: _isExportingPdf ? null : _onExportPdf,
                      ),
                      OutlinedButton.icon(
                        icon: _isExportingCsv
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.table_chart_outlined, size: 18),
                        label: const Text('تصدير Excel'),
                        onPressed: _isExportingCsv ? null : _onExportCsv,
                      ),
                      ElevatedButton.icon(
                        icon: _isPrinting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.print_outlined, size: 18),
                        label: const Text('طباعة الجرد'),
                        onPressed: _isPrinting ? null : _onPrintInventory,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.category_rounded, size: 18),
                        label: Text('إدارة التصنيفات (${inventory.categories.length})'),
                        onPressed: _showCategoriesManagementDialog,
                      ),
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
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.cardSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_outlined, size: 16, color: colors.primaryLight),
                        const SizedBox(width: 8),
                        Text(
                          'وضع العرض وطباعة الباركود (الكاشير)',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 700;
                  final categoryDropdown = DropdownButton<int?>(
                    value: inventory.categories.any((c) => c.id == inventory.selectedCategoryId)
                        ? inventory.selectedCategoryId
                        : null,
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
                  );

                  final seasonDropdown = DropdownButton<String>(
                    value: inventory.selectedSeason,
                    dropdownColor: colors.surface,
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem<String>(
                        value: 'active',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text('النشط (${settings.activeCollectionLabel})'),
                          ],
                        ),
                      ),
                      const DropdownMenuItem<String>(
                        value: 'summer',
                        child: Text('صيفي ☀️'),
                      ),
                      const DropdownMenuItem<String>(
                        value: 'winter',
                        child: Text('شتوي ❄️'),
                      ),
                      const DropdownMenuItem<String>(
                        value: 'general',
                        child: Text('عام 🌐'),
                      ),
                      const DropdownMenuItem<String>(
                        value: 'all',
                        child: Text('الكل'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) inventory.selectSeason(val);
                    },
                  );

                  final searchField = TextField(
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
                    onChanged: (val) => inventory.setSearchQuery(NumberParser.normalize(val)),
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        searchField,
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: categoryDropdown),
                            const SizedBox(width: 12),
                            Expanded(child: seasonDropdown),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: searchField,
                      ),
                      const SizedBox(width: 16),
                      categoryDropdown,
                      const SizedBox(width: 16),
                      seasonDropdown,
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Mini Stats & Valuations Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Text('الموديلات: ', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                      Text('${products.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                      Text(' (${inventory.totalVariantsCount} صنف)', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers_outlined, size: 16, color: colors.secondary),
                      const SizedBox(width: 6),
                      Text('إجمالي القطع: ', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                      Text('${inventory.totalStockPieces} قطعة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                    ],
                  ),
                  if (isAdmin) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text('قيمة التكلفة: ', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        Text(
                          CurrencyFormatter.format(inventory.totalInventoryCostValue, symbol: settings.currencySymbol),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sell_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('القيمة البيعية: ', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        Text(
                          CurrencyFormatter.format(inventory.totalInventorySellingValue, symbol: settings.currencySymbol),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ],
                  if (inventory.lowStockVariantsCount > 0 || inventory.outOfStockVariantsCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          'نواقص المخزون: ${inventory.lowStockVariantsCount} منخفض | ${inventory.outOfStockVariantsCount} نفد',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

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
                                  return _buildTableHeader(context, isAdmin);
                                }
                                final product = products[index - 1];
                                return _buildTableRow(context, product, settings.currencySymbol, index, isAdmin);
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

  Widget _buildTableHeader(BuildContext context, bool isAdmin) {
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
          SizedBox(
            width: 140,
            child: Text(
              isAdmin ? 'الإجراءات' : 'طباعة باركود',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, ProductModel product, String currencySymbol, int index, bool isAdmin) {
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

          // Category & Season
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.categoryName ?? '-',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: product.season == 'summer'
                        ? Colors.orange.withValues(alpha: 0.15)
                        : (product.season == 'winter'
                            ? Colors.lightBlue.withValues(alpha: 0.15)
                            : colors.primary.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.seasonLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: product.season == 'summer'
                          ? Colors.orangeAccent
                          : (product.season == 'winter' ? Colors.lightBlueAccent : colors.primaryLight),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Variants chips with Barcode Print Quick Trigger
          Expanded(
            flex: 4,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: product.variants.map((v) {
                return Tooltip(
                  message: 'اضغط لطباعة باركود (${v.size} - ${v.color})',
                  child: InkWell(
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
            child: isAdmin
                ? Row(
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
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.qr_code_scanner, size: 15),
                        label: const Text('طباعة', style: TextStyle(fontSize: 11)),
                        onPressed: product.variants.isEmpty
                            ? null
                            : () {
                                if (product.variants.length == 1) {
                                  showDialog(
                                    context: context,
                                    builder: (_) => BarcodePrintDialog(
                                      productName: product.name,
                                      variant: product.variants.first,
                                    ),
                                  );
                                } else {
                                  _showVariantSelectionForPrint(context, product);
                                }
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
