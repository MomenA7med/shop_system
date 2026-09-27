import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/barcode_service.dart';
import '../../core/utils/number_parser.dart';
import '../../models/product_model.dart';
import '../../models/product_variant_model.dart';
import '../../providers/inventory_provider.dart';

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
  final TextEditingController barcodeCtrl;

  _VariantEntry({
    this.id,
    String size = '',
    String color = '',
    String cost = '',
    String price = '',
    String stock = '',
    String barcode = '',
  })  : sizeCtrl = TextEditingController(text: size),
        colorCtrl = TextEditingController(text: color),
        costCtrl = TextEditingController(text: cost),
        priceCtrl = TextEditingController(text: price),
        stockCtrl = TextEditingController(text: stock),
        barcodeCtrl = TextEditingController(text: barcode.isNotEmpty ? barcode : BarcodeService.generateUniqueBarcode());

  void dispose() {
    sizeCtrl.dispose();
    colorCtrl.dispose();
    costCtrl.dispose();
    priceCtrl.dispose();
    stockCtrl.dispose();
    barcodeCtrl.dispose();
  }
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
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

      for (final v in p.variants) {
        _variants.add(_VariantEntry(
          id: v.id,
          size: v.size,
          color: v.color,
          cost: v.costPrice.toStringAsFixed(0),
          price: v.sellingPrice.toStringAsFixed(0),
          stock: v.stockQuantity.toString(),
          barcode: v.skuBarcode,
        ));
      }
    } else {
      // Default initial variant row
      _addVariantRow();
    }
  }

  void _addVariantRow() {
    setState(() {
      _variants.add(_VariantEntry(
        size: 'M',
        color: 'أسود',
        cost: '100',
        price: '180',
        stock: '10',
      ));
    });
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
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  void _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار التصنيف'), backgroundColor: AppColors.error),
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
          sellingPrice: NumberParser.tryParseDouble(v.priceCtrl.text.trim(), 0.0),
          stockQuantity: NumberParser.tryParseInt(v.stockCtrl.text.trim(), 0),
          minStockAlert: 2,
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
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e'), backgroundColor: AppColors.error),
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
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 700),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
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
                  Text(
                    widget.existingProduct != null ? AppStrings.editProduct : AppStrings.addNewProduct,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
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
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.productName,
                        hintText: 'مثال: قميص كتان كاجوال',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال اسم المنتج' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: AppStrings.category),
                      items: categories.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat.id,
                          child: Text(cat.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedCategoryId = val);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Variants Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مصفوفة المتغيرات (المقاسات والألوان والأسعار والباركود)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.primaryLight),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.cardSurface,
                      foregroundColor: colors.primaryLight,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('إضافة مقاس/لون', style: TextStyle(fontSize: 12)),
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
                    Expanded(flex: 2, child: Text('المقاس (Size)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: Text('اللون (Color)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: Text('سعر الشراء', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: Text('سعر البيع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: Text('الكمية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary))),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: Text('الباركود SKU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary))),
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
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: v.sizeCtrl,
                            decoration: const InputDecoration(hintText: 'M, L, 32...'),
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: v.colorCtrl,
                            decoration: const InputDecoration(hintText: 'أسود, أبيض...'),
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: v.stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'العدد'),
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                  v.barcodeCtrl.text = BarcodeService.generateUniqueBarcode();
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                          onPressed: _variants.length > 1 ? () => _removeVariantRow(index) : null,
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
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
