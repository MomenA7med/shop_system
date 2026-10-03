import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/pos_provider.dart';

class CategoriesManagementDialog extends StatefulWidget {
  const CategoriesManagementDialog({super.key});

  @override
  State<CategoriesManagementDialog> createState() => _CategoriesManagementDialogState();
}

class _CategoriesManagementDialogState extends State<CategoriesManagementDialog> {
  final TextEditingController _addCategoryController = TextEditingController();
  int? _editingCategoryId;
  final TextEditingController _editCategoryController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _categoriesWithCount = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _addCategoryController.dispose();
    _editCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final list = await context.read<InventoryProvider>().getCategoriesWithCount();
    if (mounted) {
      setState(() {
        _categoriesWithCount = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _onAddCategory() async {
    final name = _addCategoryController.text.trim();
    if (name.isEmpty) return;

    final inventory = context.read<InventoryProvider>();
    final success = await inventory.addCategory(name);
    if (success) {
      _addCategoryController.clear();
      // Reload POS categories as well
      if (mounted) {
        context.read<POSProvider>().loadPOSData();
        await _loadCategories();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء إضافة التصنيف'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _onSaveEditCategory(int id) async {
    final newName = _editCategoryController.text.trim();
    if (newName.isEmpty) return;

    final inventory = context.read<InventoryProvider>();
    final success = await inventory.updateCategory(id, newName);
    if (success) {
      setState(() {
        _editingCategoryId = null;
        _editCategoryController.clear();
      });
      if (mounted) {
        context.read<POSProvider>().loadPOSData();
        await _loadCategories();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء تعديل اسم التصنيف'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _onConfirmDeleteCategory(Map<String, dynamic> category) {
    final id = (category['id'] as num).toInt();
    final name = category['name'] as String;
    final productCount = (category['product_count'] as num?)?.toInt() ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text(productCount > 0 ? 'تحذير: حذف تصنيف مرتبط بمنتجات' : 'تأكيد حذف التصنيف'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من حذف تصنيف "$name"؟'),
            if (productCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'تنبيه: هذا التصنيف يحتوي على $productCount منتجات! حذفه سيؤدي إلى حذف جميع هذه المنتجات ومتغيراتها من النظام.',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final inventoryProvider = context.read<InventoryProvider>();
              final posProvider = context.read<POSProvider>();
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              final success = await inventoryProvider.deleteCategory(id);
              if (mounted) {
                if (success) {
                  posProvider.loadPOSData();
                  await _loadCategories();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('تم حذف تصنيف "$name" بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  setState(() => _isLoading = false);
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('حدث خطأ أثناء حذف التصنيف'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 650),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.category_rounded, color: colors.primaryLight, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'إدارة تصنيفات المنتجات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: colors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Add New Category Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addCategoryController,
                      decoration: InputDecoration(
                        hintText: 'أدخل اسم التصنيف الجديد (مثال: فساتين، أحذية، إكسسوارات...)',
                        isDense: true,
                        prefixIcon: const Icon(Icons.add_box_outlined, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                      onSubmitted: (_) => _onAddCategory(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة تصنيف'),
                    onPressed: _onAddCategory,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Categories List Title & Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'قائمة التصنيفات الحالية (${_categoriesWithCount.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.textSecondary,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Categories ListView
            Expanded(
              child: _isLoading && _categoriesWithCount.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _categoriesWithCount.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category_outlined, size: 40, color: colors.textMuted.withValues(alpha: 0.5)),
                              const SizedBox(height: 8),
                              Text('لا توجد تصنيفات حالياً', style: TextStyle(color: colors.textMuted)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _categoriesWithCount.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final cat = _categoriesWithCount[index];
                            final catId = (cat['id'] as num).toInt();
                            final catName = cat['name'] as String;
                            final count = (cat['product_count'] as num?)?.toInt() ?? 0;
                            final isEditing = _editingCategoryId == catId;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: colors.cardSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isEditing ? colors.primaryLight : colors.border,
                                  width: isEditing ? 1.5 : 1,
                                ),
                              ),
                              child: isEditing
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _editCategoryController,
                                            autofocus: true,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              hintText: 'اسم التصنيف',
                                            ),
                                            onSubmitted: (_) => _onSaveEditCategory(catId),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.check, color: AppColors.success, size: 20),
                                          tooltip: 'حفظ التعديل',
                                          onPressed: () => _onSaveEditCategory(catId),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                                          tooltip: 'إلغاء',
                                          onPressed: () {
                                            setState(() {
                                              _editingCategoryId = null;
                                              _editCategoryController.clear();
                                            });
                                          },
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Icon(Icons.folder_outlined, size: 18, color: colors.primaryLight),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            catName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        // Product Count Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: count > 0
                                                ? colors.primary.withValues(alpha: 0.12)
                                                : colors.textMuted.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            count > 0 ? '$count منتج' : '0 منتج',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: count > 0 ? colors.primaryLight : colors.textMuted,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Edit Button
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.secondary),
                                          tooltip: 'تعديل اسم التصنيف',
                                          onPressed: () {
                                            setState(() {
                                              _editingCategoryId = catId;
                                              _editCategoryController.text = catName;
                                            });
                                          },
                                        ),
                                        // Delete Button
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                          tooltip: 'حذف التصنيف',
                                          onPressed: () => _onConfirmDeleteCategory(cat),
                                        ),
                                      ],
                                    ),
                            );
                          },
                        ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Footer Close Button
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
