import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/order_model.dart';
import '../../../providers/invoices_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/shift_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../pos/widgets/receipt_preview_modal.dart';
import 'edit_invoice_dialog.dart';
import 'invoice_return_dialog.dart';

class InvoiceDetailsDialog extends StatelessWidget {
  final OrderModel order;

  const InvoiceDetailsDialog({super.key, required this.order});

  Color _getStatusColor(String status, AppColorsExtension colors) {
    switch (status) {
      case 'refunded':
        return colors.error;
      case 'partially_refunded':
        return colors.warning;
      case 'completed':
      default:
        return colors.success;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'refunded':
        return 'مسترجعة بالكامل';
      case 'partially_refunded':
        return 'مسترجعة جزئياً';
      case 'completed':
      default:
        return 'مكتملة وناجحة';
    }
  }

  void _confirmDeleteInvoice(BuildContext context) {
    final colors = context.colors;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.error, size: 24),
            const SizedBox(width: 8),
            Text('تأكيد حذف الفاتورة', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف الفاتورة #${order.invoiceNumber} بالكامل؟\nسيتم إعادة جميع قطع المنتجات غير المسترجعة إلى المخزون تلقائياً وضبط مبيعات الوردية.',
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppStrings.cancel, style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.error),
            onPressed: () async {
              Navigator.of(ctx).pop(); // Close confirm dialog
              final invoicesProv = context.read<InvoicesProvider>();
              final inventoryProv = context.read<InventoryProvider>();
              final shift = context.read<ShiftProvider>();
              final auth = context.read<AuthProvider>();

              final success = await invoicesProv.deleteInvoice(order.id!);
              if (success) {
                await inventoryProv.loadInventory();
                final cashierId = auth.currentUser?.id ?? 1;
                await shift.checkActiveShift(cashierId);

                if (context.mounted) {
                  Navigator.of(context).pop(); // Close details dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم حذف الفاتورة #${order.invoiceNumber} وإعادة المنتجات للمخزون'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('نعم، حذف الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = context.watch<SettingsProvider>().settings;
    final statusColor = _getStatusColor(order.status, colors);

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
                child: Icon(Icons.receipt_long_rounded, color: colors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'فاتورة #${order.invoiceNumber}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: colors.textPrimary),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          _getStatusLabel(order.status),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'التاريخ: ${DateFormatter.formatDateTime(order.createdAt)} | الكاشير: ${order.cashierName ?? "غير محدد"}',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close, color: colors.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),

            // Items Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text('المنتج والمواصفات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textSecondary))),
                  Expanded(flex: 2, child: Text('الباركود SKU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textSecondary))),
                  Expanded(flex: 2, child: Text('سعر القطعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textSecondary))),
                  Expanded(flex: 2, child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textSecondary))),
                  Expanded(flex: 2, child: Text('الإجمالي', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textSecondary))),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Items Table Body
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: order.items.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
                itemBuilder: (context, index) {
                  final item = order.items[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // Product & specs
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary),
                              ),
                              Text(
                                '${item.size} | ${item.color}',
                                style: TextStyle(fontSize: 11, color: colors.textMuted),
                              ),
                            ],
                          ),
                        ),

                        // SKU
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.skuBarcode,
                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          ),
                        ),

                        // Unit Price
                        Expanded(
                          flex: 2,
                          child: Text(
                            CurrencyFormatter.format(item.unitPrice, symbol: settings.currencySymbol),
                            style: TextStyle(fontSize: 12, color: colors.textPrimary),
                          ),
                        ),

                        // Qty + Returned badge
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Text(
                                '${item.quantity}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary),
                              ),
                              if (item.returnedQuantity > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: colors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'رجوع ${item.returnedQuantity}',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colors.warning),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Total Price
                        Expanded(
                          flex: 2,
                          child: Text(
                            CurrencyFormatter.format(item.totalPrice, symbol: settings.currencySymbol),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: colors.isDark ? colors.primaryLight : colors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // Financial Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('إجمالي الفاتورة', CurrencyFormatter.format(order.totalAmount, symbol: settings.currencySymbol), colors.primary, colors),
                  _buildStatItem('المبلغ المستلم', CurrencyFormatter.format(order.amountPaid, symbol: settings.currencySymbol), colors.textPrimary, colors),
                  _buildStatItem('الباقي للعميل', CurrencyFormatter.format(order.changeDue, symbol: settings.currencySymbol), order.changeDue > 0 ? colors.info : colors.textMuted, colors),
                  _buildStatItem('إجمالي القطع', '${order.totalItemCount} قطعة', colors.textSecondary, colors),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Delete invoice button (Admin / Cashier)
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: colors.error),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('حذف الفاتورة'),
          onPressed: () => _confirmDeleteInvoice(context),
        ),

        const Spacer(),

        // Action 1: Print / Preview Receipt
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: colors.textPrimary),
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('طباعة إيصال'),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => ReceiptPreviewModal(
                order: order,
                settings: settings,
              ),
            );
          },
        ),

        const SizedBox(width: 8),

        // Action 2: Process Return
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.warning,
            foregroundColor: Colors.black87,
          ),
          icon: const Icon(Icons.assignment_return, size: 18),
          label: const Text('عمل مرتجع', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: order.items.any((i) => i.remainingQuantity > 0)
              ? () async {
                  final returned = await showDialog<bool>(
                    context: context,
                    builder: (_) => InvoiceReturnDialog(order: order),
                  );
                  if (returned == true && context.mounted) {
                    Navigator.of(context).pop(); // Close details dialog after return
                  }
                }
              : null,
        ),

        const SizedBox(width: 8),

        // Action 3: Edit Invoice
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('تعديل الفاتورة', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () async {
            final edited = await showDialog<bool>(
              context: context,
              builder: (_) => EditInvoiceDialog(order: order),
            );
            if (edited == true && context.mounted) {
              Navigator.of(context).pop(); // Close details dialog after edit
            }
          },
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor, AppColorsExtension colors) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}
