import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/print_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/order_model.dart';
import '../../../models/store_settings_model.dart';

class ReceiptPreviewModal extends StatelessWidget {
  final OrderModel order;
  final StoreSettingsModel settings;

  const ReceiptPreviewModal({
    super.key,
    required this.order,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 650),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.invoicePreview,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: colors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Thermal Paper Preview (White Paper style)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Store Name & Slogan
                      Text(
                        settings.storeName,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (settings.slogan.isNotEmpty)
                        Text(
                          settings.slogan,
                          style: const TextStyle(color: Colors.black54, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      if (settings.phone.isNotEmpty)
                        Text(
                          'هاتف: ${settings.phone}',
                          style: const TextStyle(color: Colors.black87, fontSize: 10),
                        ),
                      if (settings.address.isNotEmpty)
                        Text(
                          settings.address,
                          style: const TextStyle(color: Colors.black87, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Colors.black26, thickness: 1),
                      ),

                      // Order metadata
                      _buildReceiptRow('رقم الفاتورة:', order.invoiceNumber),
                      _buildReceiptRow('التاريخ:', DateFormatter.formatDateTime(order.createdAt)),
                      if (order.cashierName != null)
                        _buildReceiptRow('الكاشير:', order.cashierName!),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Colors.black26, thickness: 1),
                      ),

                      // Items Table
                      ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  Text(
                                    '${item.size} - ${item.color}',
                                    style: const TextStyle(color: Colors.black54, fontSize: 9),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${item.quantity} × ${item.unitPrice}',
                              style: const TextStyle(color: Colors.black87, fontSize: 10),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CurrencyFormatter.format(item.totalPrice, symbol: settings.currencySymbol),
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      )),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Colors.black26, thickness: 1),
                      ),

                      // Totals & Cash Breakdown
                      _buildReceiptRow(
                        'الإجمالي المطلوب:',
                        CurrencyFormatter.format(order.totalAmount, symbol: settings.currencySymbol),
                        isBold: true,
                        fontSize: 13,
                      ),
                      const SizedBox(height: 4),
                      _buildReceiptRow(
                        'المبلغ المستلم (نقداً):',
                        CurrencyFormatter.format(order.amountPaid, symbol: settings.currencySymbol),
                      ),
                      const SizedBox(height: 4),
                      _buildReceiptRow(
                        'الباقي للعميل:',
                        CurrencyFormatter.format(order.changeDue, symbol: settings.currencySymbol),
                        isBold: true,
                        fontSize: 12,
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Colors.black26, thickness: 1),
                      ),

                      // Footer text
                      if (settings.receiptFooter.isNotEmpty)
                        Text(
                          settings.receiptFooter,
                          style: const TextStyle(color: Colors.black54, fontSize: 9),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إغلاق'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text(AppStrings.print),
                      onPressed: () async {
                        await PrintService.printReceipt(order: order, settings: settings);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, double fontSize = 10}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black87,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.black,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}
