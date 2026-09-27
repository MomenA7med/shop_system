import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/order_model.dart';
import '../../../providers/invoices_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/returns_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/shift_provider.dart';

class InvoiceReturnDialog extends StatefulWidget {
  final OrderModel order;

  const InvoiceReturnDialog({super.key, required this.order});

  @override
  State<InvoiceReturnDialog> createState() => _InvoiceReturnDialogState();
}

class _InvoiceReturnDialogState extends State<InvoiceReturnDialog> {
  final Map<int, int> _returnQuantities = {};
  final Map<int, String> _returnReasons = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.order.items) {
      if (item.id != null) {
        final remaining = item.remainingQuantity;
        _returnQuantities[item.id!] = remaining > 0 ? 1 : 0;
        _returnReasons[item.id!] = 'مقاس غير مناسب';
      }
    }
  }

  double _calculateTotalRefund() {
    double total = 0.0;
    for (final item in widget.order.items) {
      if (item.id != null) {
        final qty = _returnQuantities[item.id!] ?? 0;
        total += item.unitPrice * qty;
      }
    }
    return total;
  }

  int _calculateTotalReturnItems() {
    int count = 0;
    for (final item in widget.order.items) {
      if (item.id != null) {
        count += _returnQuantities[item.id!] ?? 0;
      }
    }
    return count;
  }

  Future<void> _processAllSelectedReturns() async {
    final totalCount = _calculateTotalReturnItems();
    if (totalCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد كمية قطعة واحدة على الأقل للإرجاع'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final returnsProv = context.read<ReturnsProvider>();
    final invoicesProv = context.read<InvoicesProvider>();
    final inventoryProv = context.read<InventoryProvider>();
    final shift = context.read<ShiftProvider>();
    final shiftId = shift.activeShift?.id;

    int successCount = 0;

    for (final item in widget.order.items) {
      if (item.id != null) {
        final qty = _returnQuantities[item.id!] ?? 0;
        if (qty > 0) {
          final reason = _returnReasons[item.id!] ?? 'رغبة العميل';
          final success = await returnsProv.returnItem(
            item: item,
            returnQty: qty,
            reason: reason,
            shiftId: shiftId,
          );
          if (success) {
            successCount += qty;
          }
        }
      }
    }

    // Refresh active shift & inventory & invoices
    if (shift.activeShift != null) {
      await shift.checkActiveShift(shift.activeShift!.cashierId);
    }
    await inventoryProv.loadInventory();
    await invoicesProv.loadInvoices();

    if (mounted) {
      setState(() => _isProcessing = false);
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'تم إرجاع $successCount قطعة واسترداد ${CurrencyFormatter.formatSimple(_calculateTotalRefund())} بنجاح',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = context.watch<SettingsProvider>().settings;
    final returnableItems = widget.order.items.where((i) => i.remainingQuantity > 0).toList();

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
                  color: colors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment_return, color: colors.warning, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'عمل مرتجع من الفاتورة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.textPrimary),
                  ),
                  Text(
                    'رقم الفاتورة: ${widget.order.invoiceNumber}',
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

            if (returnableItems.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'جميع عناصر هذه الفاتورة تم إرجاعها مسبقاً بالكامل',
                    style: TextStyle(color: colors.textMuted, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: returnableItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = returnableItems[index];
                    final itemId = item.id!;
                    final maxReturnable = item.remainingQuantity;
                    final selectedQty = _returnQuantities[itemId] ?? 0;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.cardSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedQty > 0 ? colors.warning : colors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Checkbox / Toggle
                          Checkbox(
                            value: selectedQty > 0,
                            activeColor: colors.warning,
                            checkColor: Colors.black87,
                            onChanged: (val) {
                              setState(() {
                                _returnQuantities[itemId] = (val == true) ? 1 : 0;
                              });
                            },
                          ),

                          // Item Details
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
                                  'المقاس: ${item.size} | اللون: ${item.color} | متبقي: $maxReturnable من ${item.quantity}',
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

                          // Qty Selector
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline, size: 18, color: colors.textPrimary),
                                onPressed: selectedQty > 0
                                    ? () => setState(() => _returnQuantities[itemId] = selectedQty - 1)
                                    : null,
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 28),
                                alignment: Alignment.center,
                                child: Text(
                                  '$selectedQty',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.add_circle_outline, size: 18, color: colors.textPrimary),
                                onPressed: selectedQty < maxReturnable
                                    ? () => setState(() => _returnQuantities[itemId] = selectedQty + 1)
                                    : null,
                              ),
                            ],
                          ),

                          const SizedBox(width: 10),

                          // Reason Dropdown
                          SizedBox(
                            width: 120,
                            child: DropdownButtonFormField<String>(
                              initialValue: _returnReasons[itemId] ?? 'مقاس غير مناسب',
                              isDense: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              style: TextStyle(fontSize: 11, color: colors.textPrimary),
                              items: ['مقاس غير مناسب', 'عيب صناعة', 'رغبة العميل', 'تبديل موديل']
                                  .map((r) => DropdownMenuItem(value: r, child: Text(r, style: TextStyle(fontSize: 11, color: colors.textPrimary))))
                                  .toList(),
                              onChanged: selectedQty > 0
                                  ? (val) {
                                      if (val != null) setState(() => _returnReasons[itemId] = val);
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 14),

            // Summary box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إجمالي المبلغ المسترد للعميل (${_calculateTotalReturnItems()} قطع):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary),
                  ),
                  Text(
                    CurrencyFormatter.format(_calculateTotalRefund(), symbol: settings.currencySymbol),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colors.warning,
                    ),
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
            backgroundColor: colors.warning,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: _isProcessing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.assignment_return, size: 18),
          label: const Text('تأكيد الإرجاع واسترداد المبلغ', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _isProcessing || _calculateTotalReturnItems() <= 0
              ? null
              : _processAllSelectedReturns,
        ),
      ],
    );
  }
}
