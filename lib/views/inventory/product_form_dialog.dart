import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/barcode_service.dart';
import '../../core/utils/number_parser.dart';
import '../../models/product_model.dart';
import '../../models/product_variant_model.dart';
import '../../providers/inventory_provider.dart';
import 'categories_management_dialog.dart';

class ProductFormDialog extends StatefulWidget {
  final ProductModel? existingProduct;

  const ProductFormDialog({super.key, this.existingProduct});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _VariantEntry {
  int? id;
  final TextEditingController sizeCtrl;
  final TextEditingController colorCtrl;
  final TextEditingController costCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController minAlertCtrl;
  final TextEditingController barcodeCtrl;

  _VariantEntry({
    this.id,
    String size = 'قطعة',
    String color = 'افتراضي',
    String cost = '',
    String price = '',
    String stock = '',
    String minAlert = '2',
    String barcode = '',
  }) : sizeCtrl = TextEditingController(text: size),
       colorCtrl = TextEditingController(text: color),
       costCtrl = TextEditingController(text: cost),
       priceCtrl = TextEditingController(text: price),
       stockCtrl = TextEditingController(text: stock),
       minAlertCtrl = TextEditingController(text: minAlert),
       barcodeCtrl = TextEditingController(
         text: barcode.isNotEmpty
             ? barcode
             : BarcodeService.generateUniqueBarcode(),
       );

  void dispose() {
    sizeCtrl.dispose();
    colorCtrl.dispose();
    costCtrl.dispose();
    priceCtrl.dispose();
    stockCtrl.dispose();
    minAlertCtrl.dispose();
    barcodeCtrl.dispose();
  }
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _defaultMinAlertController =
      TextEditingController(text: '2');
  int? _selectedCategoryId;
  final List<_VariantEntry> _variants = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      final p = widget.existingProduct!;
      _nameController.text = p.name;
      _descController.text = p.description;
      _selectedCategoryId = p.categoryId;

      if (p.variants.isNotEmpty) {
        _defaultMinAlertController.text = p.variants.first.minStockAlert
            .toString();
      }

      for (final v in p.variants) {
        _variants.add(
          _VariantEntry(
            id: v.id,
            size: v.size,
            color: v.color,
            cost: v.costPrice.toStringAsFixed(0),
            price: v.sellingPrice.toStringAsFixed(0),
            stock: v.stockQuantity.toString(),
            minAlert: v.minStockAlert.toString(),
            barcode: v.skuBarcode,
          ),
        );
      }
    } else {
      // Default initial variant row
      _addVariantRow();
    }
  }

  void _addVariantRow() {
    setState(() {
      final alertVal = _defaultMinAlertController.text.trim().isNotEmpty
          ? _defaultMinAlertController.text.trim()
          : '2';

      if (_variants.isNotEmpty) {
        final last = _variants.last;
        _variants.add(
          _VariantEntry(
            size: last.sizeCtrl.text.isNotEmpty ? last.sizeCtrl.text : 'قطعة',
            color: last.colorCtrl.text.isNotEmpty
                ? last.colorCtrl.text
                : 'افتراضي',
            cost: last.costCtrl.text,
            price: last.priceCtrl.text,
            stock: last.stockCtrl.text,
            minAlert: last.minAlertCtrl.text.isNotEmpty
                ? last.minAlertCtrl.text
                : alertVal,
            barcode: BarcodeService.generateUniqueBarcode(),
          ),
        );
      } else {
        _variants.add(
          _VariantEntry(
            size: 'قطعة',
            color: 'افتراضي',
            cost: '10',
            price: '15',
            stock: '20',
            minAlert: alertVal,
            barcode: BarcodeService.generateUniqueBarcode(),
          ),
        );
      }
    });
  }

  void _applyDefaultMinAlertToAll() {
    final alertVal = _defaultMinAlertController.text.trim().isNotEmpty
        ? _defaultMinAlertController.text.trim()
        : '2';
    setState(() {
      for (final v in _variants) {
        v.minAlertCtrl.text = alertVal;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تطبيق حد التنبيه ($alertVal) على جميع المتغيرات'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeVariantRow(int index) {
    if (_variants.length > 1) {
      setState(() {
        _variants[index].dispose();
        _variants.removeAt(index);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _defaultMinAlertController.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  void _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار التصنيف'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final inventory = context.read<InventoryProvider>();

    try {
      final product = ProductModel(
        id: widget.existingProduct?.id,
        categoryId: _selectedCategoryId!,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
      );

      final variantsList = _variants.map((v) {
        return ProductVariantModel(
          id: v.id,
          productId: widget.existingProduct?.id ?? 0,
          skuBarcode: v.barcodeCtrl.text.trim().isNotEmpty
              ? v.barcodeCtrl.text.trim()
              : BarcodeService.generateUniqueBarcode(),
          size: v.sizeCtrl.text.trim(),
          color: v.colorCtrl.text.trim(),
          costPrice: NumberParser.tryParseDouble(v.costCtrl.text.trim(), 0.0),
          sellingPrice: NumberParser.tryParseDouble(
            v.priceCtrl.text.trim(),
            0.0,
          ),
          stockQuantity: NumberParser.tryParseDouble(
            v.stockCtrl.text.trim(),
            0.0,
          ),
          minStockAlert: NumberParser.tryParseDouble(
            v.minAlertCtrl.text.trim(),
            2.0,
          ),
        );
      }).toList();

      bool success;
      if (widget.existingProduct != null) {
        success = await inventory.updateProduct(product, variantsList);
      } else {
        success = await inventory.addProduct(product, variantsList);
      }

      if (success && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحفظ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inventory = context.watch<InventoryProvider>();
    final categories = inventory.categories;

    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 720),
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
        child: Form(
          key: _formKey,
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
                        child: Icon(
                          widget.existingProduct != null
                              ? Icons.edit_note_rounded
                              : Icons.add_business_rounded,
                          color: colors.primaryLight,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.existingProduct != null
                            ? AppStrings.editProduct
                            : AppStrings.addNewProduct,
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
              const Divider(height: 20),

              // Product Main Info (Row 1)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.productName,
                        hintText: 'مثال: شويبس رمان كانز 240 مل',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'يرجى إدخال اسم الصنف'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Category Selector with inline Manage button
                  Expanded(
                    flex: 3,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue:
                                categories.any(
                                  (c) => c.id == _selectedCategoryId,
                                )
                                ? _selectedCategoryId
                                : (categories.isNotEmpty
                                      ? categories.first.id
                                      : null),
                            decoration: const InputDecoration(
                              labelText: AppStrings.category,
                            ),
                            items: categories.map((cat) {
                              return DropdownMenuItem<int>(
                                value: cat.id,
                                child: Text(
                                  cat.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedCategoryId = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.settings_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          tooltip: 'إدارة وتعديل التصنيفات',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) =>
                                  const CategoriesManagementDialog(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Default Low Stock Alert Input
                  Expanded(
                    flex: 2,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _defaultMinAlertController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'تنبيه النقص الافتراضي',
                              hintText: '2',
                              helperText: 'الحد الأدنى للتنبيه',
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'مطلوب'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.playlist_add_check_rounded,
                            size: 20,
                            color: AppColors.secondary,
                          ),
                          tooltip: 'تطبيق حد التنبيه على كل الصفوف',
                          onPressed: _applyDefaultMinAlertToAll,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Variants Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'متغيرات الصنف والوحدات والأسعار والأرصدة والباركود',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryLight,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.cardSurface,
                      foregroundColor: colors.primaryLight,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'إضافة متغير / وحدة',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: _addVariantRow,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Variants Dynamic List Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.cardSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'الوحدة (Unit)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'البيان / الحجم / النكهة',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'سعر التكلفة',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'سعر البيع',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'الكمية الحالية',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'حد تنبيه النقص',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'الباركود (رقم المادة)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Variants Rows
              Expanded(
                child: ListView.separated(
                  itemCount: _variants.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final v = _variants[index];
                    return Row(
                      children: [
                        // Unit / Size
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: v.sizeCtrl,
                            decoration: const InputDecoration(
                              hintText: 'قطعة، علبة، كرتونة...',
                            ),
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Variant note / Flavor / Volume
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: v.colorCtrl,
                            decoration: const InputDecoration(
                              hintText: '240 مل، سادة...',
                            ),
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Cost Price
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: v.costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '0.0'),
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Selling Price
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: v.priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '0.0'),
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Current Stock Quantity
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: v.stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'العدد',
                            ),
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Min Stock Alert Threshold
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: v.minAlertCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '2',
                              prefixIcon: const Icon(
                                Icons.notifications_active_outlined,
                                size: 14,
                                color: AppColors.warning,
                              ),
                            ),
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Barcode SKU
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: v.barcodeCtrl,
                            decoration: InputDecoration(
                              hintText: 'باركود',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.refresh, size: 16),
                                tooltip: 'توليد باركود جديد',
                                onPressed: () {
                                  v.barcodeCtrl.text =
                                      BarcodeService.generateUniqueBarcode();
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Delete Row Button
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          tooltip: 'حذف هذا المتغير',
                          onPressed: _variants.length > 1
                              ? () => _removeVariantRow(index)
                              : null,
                        ),
                      ],
                    );
                  },
                ),
              ),

              const Divider(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(AppStrings.cancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: Text(_isSaving ? 'جاري الحفظ...' : AppStrings.save),
                    onPressed: _isSaving ? null : _onSave,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
