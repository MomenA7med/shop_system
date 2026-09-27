import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/number_parser.dart';
import '../../../models/order_item_model.dart';
import '../../../models/order_model.dart';
import '../../../providers/invoices_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/shift_provider.dart';
import '../../../providers/auth_provider.dart';

class EditInvoiceDialog extends StatefulWidget {
  final OrderModel order;

  const EditInvoiceDialog({super.key, required this.order});

  @override
  State<EditInvoiceDialog> createState() => _EditInvoiceDialogState();
}

class _EditInvoiceDialogState extends State<EditInvoiceDialog> {
  late List<OrderItemModel> _editableItems;
  late TextEditingController _paidCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Clone items
    _editableItems = widget.order.items.map((item) {
      return OrderItemModel(
        id: item.id,
        orderId: item.orderId,
        variantId: item.variantId,
        productId: item.productId,
        productName: item.productName,
        size: item.size,
        color: item.color,
        skuBarcode: item.skuBarcode,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        costPrice: item.costPrice,
        returnedQuantity: item.returnedQuantity,
      );
    }).toList();

    _paidCtrl = TextEditingController(
      text: widget.order.amountPaid % 1 == 0
          ? widget.order.amountPaid.toInt().toString()
          : widget.order.amountPaid.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
  }

  double get _currentTotal => _editableItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get _currentPaid => NumberParser.tryParseDouble(_paidCtrl.text.trim(), _currentTotal);
  double get _currentChange => _currentPaid > _currentTotal ? _currentPaid - _currentTotal : 0.0;

  void _incrementQuantity(int index) {
    setState(() {
      _editableItems[index].quantity += 1;
      // Auto adjust paid if it was exact match before
      if (_currentPaid == widget.order.totalAmount) {
        _paidCtrl.text = _currentTotal % 1 == 0
            ? _currentTotal.toInt().toString()
            : _currentTotal.toStringAsFixed(2);
      }
    });
  }

  void _decrementQuantity(int index) {
    final item = _editableItems[index];
    // Cannot reduce below already returned quantity
    if (item.quantity <= (item.returnedQuantity > 0 ? item.returnedQuantity : 1)) {
      if (item.returnedQuantity > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يمكن تقليل الكمية لأقل من الكمية المرتجعة بالفعل (${item.returnedQuantity})'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    setState(() {
      _editableItems[index].quantity -= 1;
      if (_currentPaid == widget.order.totalAmount) {
        _paidCtrl.text = _currentTotal % 1 == 0
            ? _currentTotal.toInt().toString()
            : _currentTotal.toStringAsFixed(2);
      }
    });
  }

  void _removeItem(int index) {
    final item = _editableItems[index];
    if (item.returnedQuantity > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف عنصر تم إرجاع جزء منه مسبقاً'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_editableItems.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب أن تحتوي الفاتورة على عنصر واحد على الأقل، أو قم بحذف الفاتورة بالكامل'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _editableItems.removeAt(index);
      if (_currentPaid == widget.order.totalAmount) {
        _paidCtrl.text = _currentTotal % 1 == 0
            ? _currentTotal.toInt().toString()
            : _currentTotal.toStringAsFixed(2);
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_editableItems.isEmpty) return;
    if (_currentPaid < _currentTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المبلغ المدفوع أقل من إجمالي الفاتورة الجديد!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final invoicesProv = context.read<InvoicesProvider>();
    final inventoryProv = context.read<InventoryProvider>();
    final shift = context.read<ShiftProvider>();
    final auth = context.read<AuthProvider>();

    final success = await invoicesProv.updateInvoice(
      orderId: widget.order.id!,
      items: _editableItems,
      totalAmount: _currentTotal,
      amountPaid: _currentPaid,
      changeDue: _currentChange,
    );

    if (success) {
      // Reload inventory & active shift
      await inventoryProv.loadInventory();
      final cashierId = auth.currentUser?.id ?? 1;
      await shift.checkActiveShift(cashierId);

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ تعديلات الفاتورة وتحديث المخزون بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(invoicesProv.errorMessage ?? 'حدث خطأ أثناء تعديل الفاتورة'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = context.watch<SettingsProvider>().settings;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
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
                child: Icon(Icons.edit_note_rounded, color: colors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تعديل الفاتورة #${widget.order.invoiceNumber}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.textPrimary),
                  ),
                  Text(
                    'تعديل الكميات والعناصر والمبالغ المسددة',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close, color: colors.textMuted),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
      content: SizedBox(
        width: 680,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),

            // Items List
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _editableItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _editableItems[index];

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.cardSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        // Product info
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.size} - ${item.color} | باركود: ${item.skuBarcode}',
                                style: TextStyle(fontSize: 11, color: colors.textMuted),
                              ),
                            ],
                          ),
                        ),

                        // Unit Price
                        Expanded(
                          flex: 2,
                          child: Text(
                            CurrencyFormatter.format(item.unitPrice, symbol: settings.currencySymbol),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),

                        // Quantity +/-
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline, size: 18, color: colors.textPrimary),
                              onPressed: () => _decrementQuantity(index),
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 28),
                              alignment: Alignment.center,
                              child: Text(
                                '${item.quantity}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline, size: 18, color: colors.primary),
                              onPressed: () => _incrementQuantity(index),
                            ),
                          ],
                        ),

                        const SizedBox(width: 8),

                        // Total Price for item
                        SizedBox(
                          width: 85,
                          child: Text(
                            CurrencyFormatter.format(item.totalPrice, symbol: settings.currencySymbol),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: colors.isDark ? colors.primaryLight : colors.primaryDark,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Delete button
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: colors.error),
                          onPressed: () => _removeItem(index),
                          tooltip: 'حذف من الفاتورة',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Financial Summary & Paid Amount inputs
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي الفاتورة الجديد (${_editableItems.fold(0, (s, i) => s + i.quantity)} قطع):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary),
                      ),
                      Text(
                        CurrencyFormatter.format(_currentTotal, symbol: settings.currencySymbol),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colors.isDark ? colors.primaryLight : colors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              'المبلغ المستلم:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textSecondary),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 120,
                              height: 38,
                              child: TextField(
                                controller: _paidCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  isDense: true,
                                  suffixText: settings.currencySymbol,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'الباقي للعميل: ${CurrencyFormatter.format(_currentChange, symbol: settings.currencySymbol)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _currentChange > 0 ? colors.info : colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(AppStrings.cancel, style: TextStyle(color: colors.textSecondary)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: 18),
          label: const Text('حفظ التعديلات وتحديث المخزون', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _isSaving ? null : _saveChanges,
        ),
      ],
    );
  }
}
