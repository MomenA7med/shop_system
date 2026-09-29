import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/number_parser.dart';
import '../../../models/order_item_model.dart';
import '../../../models/order_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/invoices_provider.dart';
import '../../../providers/pos_provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/shift_provider.dart';

class EditInvoiceDialog extends StatefulWidget {
  final OrderModel order;

  const EditInvoiceDialog({super.key, required this.order});

  @override
  State<EditInvoiceDialog> createState() => _EditInvoiceDialogState();
}

class _EditInvoiceDialogState extends State<EditInvoiceDialog> {
  late List<OrderItemModel> _editableItems;
  late TextEditingController _paidCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _deliveryCtrl;
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

    final initialDiscount = widget.order.discountAmount;
    final initialDelivery = widget.order.deliveryFee;

    _discountCtrl = TextEditingController(
      text: initialDiscount > 0
          ? (initialDiscount % 1 == 0
              ? initialDiscount.toInt().toString()
              : initialDiscount.toStringAsFixed(2))
          : '',
    );

    _deliveryCtrl = TextEditingController(
      text: initialDelivery > 0
          ? (initialDelivery % 1 == 0
              ? initialDelivery.toInt().toString()
              : initialDelivery.toStringAsFixed(2))
          : '',
    );

    _paidCtrl = TextEditingController(
      text: widget.order.amountPaid % 1 == 0
          ? widget.order.amountPaid.toInt().toString()
          : widget.order.amountPaid.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _discountCtrl.dispose();
    _deliveryCtrl.dispose();
    super.dispose();
  }

  double get _itemsSubtotal =>
      _editableItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get _currentDiscount =>
      NumberParser.tryParseDouble(_discountCtrl.text.trim(), 0.0);
  double get _currentDelivery =>
      NumberParser.tryParseDouble(_deliveryCtrl.text.trim(), 0.0);

  double get _currentTotal {
    final net = _itemsSubtotal - _currentDiscount + _currentDelivery;
    return net > 0 ? net : 0.0;
  }

  double get _currentPaid =>
      NumberParser.tryParseDouble(_paidCtrl.text.trim(), _currentTotal);
  double get _currentChange =>
      _currentPaid > _currentTotal ? _currentPaid - _currentTotal : 0.0;

  void _syncPaidIfExact(double oldTotal) {
    if (_currentPaid == oldTotal || _paidCtrl.text.trim().isEmpty) {
      _paidCtrl.text = _currentTotal % 1 == 0
          ? _currentTotal.toInt().toString()
          : _currentTotal.toStringAsFixed(2);
    }
  }

  void _incrementQuantity(int index) {
    final oldTotal = _currentTotal;
    setState(() {
      _editableItems[index].quantity += 1;
      _syncPaidIfExact(oldTotal);
    });
  }

  void _decrementQuantity(int index) {
    final item = _editableItems[index];
    // Cannot reduce below already returned quantity
    if (item.quantity <= (item.returnedQuantity > 0 ? item.returnedQuantity : 1)) {
      if (item.returnedQuantity > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'لا يمكن تقليل الكمية لأقل من الكمية المرتجعة بالفعل (${item.returnedQuantity})'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    final oldTotal = _currentTotal;
    setState(() {
      _editableItems[index].quantity -= 1;
      _syncPaidIfExact(oldTotal);
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
          content: Text(
              'يجب أن تحتوي الفاتورة على عنصر واحد على الأقل، أو قم بحذف الفاتورة بالكامل'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final oldTotal = _currentTotal;
    setState(() {
      _editableItems.removeAt(index);
      _syncPaidIfExact(oldTotal);
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
      deliveryFee: _currentDelivery,
    );

    if (success) {
      // Reload inventory & active shift & reports & pos
      await inventoryProv.loadInventory();
      final cashierId = auth.currentUser?.id ?? 1;
      await shift.checkActiveShift(cashierId);
      if (mounted) {
        context.read<ReportsProvider>().loadReports();
        context.read<POSProvider>().loadPOSData();
      }

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
          Expanded(
            child: Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تعديل الفاتورة #${widget.order.invoiceNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'تعديل الكميات والعناصر، الدليفري، الخصم، والمبالغ المسددة',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colors.textMuted),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),

            // Items List
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
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
                            CurrencyFormatter.format(item.unitPrice,
                                symbol: settings.currencySymbol),
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
                              icon: Icon(Icons.remove_circle_outline,
                                  size: 18, color: colors.textPrimary),
                              onPressed: () => _decrementQuantity(index),
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 28),
                              alignment: Alignment.center,
                              child: Text(
                                NumberParser.formatQuantity(item.quantity),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline,
                                  size: 18, color: colors.primary),
                              onPressed: () => _incrementQuantity(index),
                            ),
                          ],
                        ),

                        const SizedBox(width: 8),

                        // Total Price for item
                        SizedBox(
                          width: 85,
                          child: Text(
                            CurrencyFormatter.format(item.totalPrice,
                                symbol: settings.currencySymbol),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: colors.isDark
                                  ? colors.primaryLight
                                  : colors.primaryDark,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Delete button
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: colors.error),
                          onPressed: () => _removeItem(index),
                          tooltip: 'حذف من الفاتورة',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Delivery & Discount Inputs Row
            Row(
              children: [
                // Delivery input
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.cardSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.delivery_dining_rounded,
                            size: 18,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'الدليفري:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 34,
                            child: TextField(
                              controller: _deliveryCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                    color: colors.textMuted, fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 0),
                                isDense: true,
                                suffixText: settings.currencySymbol,
                                suffixIcon: _deliveryCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 14),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          final oldTotal = _currentTotal;
                                          setState(() {
                                            _deliveryCtrl.clear();
                                            _syncPaidIfExact(oldTotal);
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (_) {
                                final oldTotal = _currentTotal;
                                setState(() {
                                  _syncPaidIfExact(oldTotal);
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Discount input
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.cardSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.discount_outlined,
                            size: 18,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'الخصم:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 34,
                            child: TextField(
                              controller: _discountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                    color: colors.textMuted, fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 0),
                                isDense: true,
                                suffixText: settings.currencySymbol,
                                suffixIcon: _discountCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 14),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          final oldTotal = _currentTotal;
                                          setState(() {
                                            _discountCtrl.clear();
                                            _syncPaidIfExact(oldTotal);
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (_) {
                                final oldTotal = _currentTotal;
                                setState(() {
                                  _syncPaidIfExact(oldTotal);
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

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
                  // Breakdown if delivery or discount applied
                  if (_currentDiscount > 0 || _currentDelivery > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'إجمالي الأصناف (${NumberParser.formatQuantity(_editableItems.fold(0.0, (s, i) => s + i.quantity))} وحدة):',
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        ),
                        Text(
                          CurrencyFormatter.format(_itemsSubtotal,
                              symbol: settings.currencySymbol),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (_currentDelivery > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.delivery_dining_rounded,
                                  size: 14, color: AppColors.accent),
                              const SizedBox(width: 4),
                              Text('خدمة التوصيل (دليفري):',
                                  style: TextStyle(
                                      fontSize: 11, color: colors.textSecondary)),
                            ],
                          ),
                          Text(
                            '+ ${CurrencyFormatter.format(_currentDelivery, symbol: settings.currencySymbol)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_currentDiscount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.discount_outlined,
                                  size: 14, color: AppColors.warning),
                              const SizedBox(width: 4),
                              Text('الخصم:',
                                  style: TextStyle(
                                      fontSize: 11, color: colors.textSecondary)),
                            ],
                          ),
                          Text(
                            '- ${CurrencyFormatter.format(_currentDiscount, symbol: settings.currencySymbol)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Divider(height: 1),
                    ),
                  ],

                  // Grand total row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي الفاتورة الجديد:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: colors.textPrimary),
                      ),
                      Text(
                        CurrencyFormatter.format(_currentTotal,
                            symbol: settings.currencySymbol),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colors.isDark
                              ? colors.primaryLight
                              : colors.primaryDark,
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
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textSecondary),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 120,
                              height: 38,
                              child: TextField(
                                controller: _paidCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 0),
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
                          color: _currentChange > 0
                              ? colors.info
                              : colors.textPrimary,
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
          child:
              Text(AppStrings.cancel, style: TextStyle(color: colors.textSecondary)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: 18),
          label: const Text('حفظ التعديلات وتحديث المخزون',
              style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _isSaving ? null : _saveChanges,
        ),
      ],
    );
  }
}
