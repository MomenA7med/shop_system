import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/print_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/order_model.dart';
import '../../../models/store_settings_model.dart';

class ReceiptPreviewModal extends StatefulWidget {
  final OrderModel order;
  final StoreSettingsModel settings;

  const ReceiptPreviewModal({
    super.key,
    required this.order,
    required this.settings,
  });

  @override
  State<ReceiptPreviewModal> createState() => _ReceiptPreviewModalState();
}

class _ReceiptPreviewModalState extends State<ReceiptPreviewModal> {
  bool _isPrinting = false;

  void _onPrint() async {
    setState(() => _isPrinting = true);
    try {
      await PrintService.printReceipt(
        order: widget.order,
        settings: widget.settings,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الطباعة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final order = widget.order;
    final settings = widget.settings;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 720),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.receipt_long, size: 20, color: colors.primary),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.invoicePreview,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'معاينة مطابقة للطباعة الحرارية (80mm)',
                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: colors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(color: colors.border, height: 1),

            // Thermal Paper Preview Area
            Expanded(
              child: Container(
                color: colors.isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      width: 320,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Store Logo (if available)
                          if (settings.logoPath != null && File(settings.logoPath!).existsSync()) ...[
                            Image.file(
                              File(settings.logoPath!),
                              width: 55,
                              height: 55,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Store Name & Info
                          Text(
                            settings.storeName,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (settings.slogan.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              settings.slogan,
                              style: const TextStyle(color: Colors.black54, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (settings.phone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'هاتف: ${settings.phone}',
                              style: const TextStyle(color: Colors.black87, fontSize: 10),
                            ),
                          ],
                          if (settings.address.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              settings.address,
                              style: const TextStyle(color: Colors.black87, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: _DashedLine(),
                          ),

                          // Metadata
                          _buildReceiptRow('رقم الفاتورة:', '#${order.invoiceNumber}', isBold: true),
                          const SizedBox(height: 2),
                          _buildReceiptRow('التاريخ والوقت:', DateFormatter.formatDateTime(order.createdAt)),
                          if (order.cashierName != null && order.cashierName!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            _buildReceiptRow('الكاشير:', order.cashierName!),
                          ],

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: _DashedLine(),
                          ),

                          // Table Header
                          const Row(
                            children: [
                              Expanded(flex: 4, child: Text('الصنف / المقاس', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black))),
                              Expanded(flex: 1, child: Text('العدد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black), textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text('السعر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black), textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black), textAlign: TextAlign.left)),
                            ],
                          ),
                          const Divider(height: 10, color: Colors.black26),

                          // Line Items (Only items with remainingQuantity > 0)
                          ...(){
                            final activeItems = order.items.where((i) => i.remainingQuantity > 0).toList();
                            if (activeItems.isEmpty) {
                              return [
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: Text(
                                      'لا توجد أصناف في الفاتورة (مسترجعة بالكامل)',
                                      style: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ];
                            }

                            return activeItems.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName,
                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '(${item.size} - ${item.color})',
                                          style: const TextStyle(color: Colors.black54, fontSize: 9),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${item.remainingQuantity}',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      item.unitPrice.toStringAsFixed(1),
                                      style: const TextStyle(color: Colors.black87, fontSize: 10),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      item.netTotalPrice.toStringAsFixed(1),
                                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                ],
                              ),
                            )).toList();
                          }(),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: _DashedLine(),
                          ),

                          // Totals Breakdown for active items
                          ...(){
                            final activeItems = order.items.where((i) => i.remainingQuantity > 0).toList();
                            final activeSubtotal = activeItems.fold(0.0, (sum, i) => sum + i.netTotalPrice);
                            final activeTotal = order.netTotalAmount;
                            final activeDiscount = (activeSubtotal > activeTotal) ? (activeSubtotal - activeTotal) : 0.0;

                            return [
                              if (activeDiscount > 0) ...[
                                _buildReceiptRow(
                                  'المجموع الفرعي:',
                                  CurrencyFormatter.format(activeSubtotal, symbol: settings.currencySymbol),
                                  fontSize: 10,
                                ),
                                const SizedBox(height: 3),
                                _buildReceiptRow(
                                  'الخصم (-):',
                                  '- ${CurrencyFormatter.format(activeDiscount, symbol: settings.currencySymbol)}',
                                  isBold: true,
                                  textColor: const Color(0xFFDC2626),
                                  fontSize: 11,
                                ),
                                const SizedBox(height: 3),
                              ],

                              _buildReceiptRow(
                                'الإجمالي المطلوب:',
                                CurrencyFormatter.format(activeTotal, symbol: settings.currencySymbol),
                                isBold: true,
                                fontSize: 14,
                              ),
                            ];
                          }(),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: _DashedLine(),
                          ),

                          // Barcode representation for easy scanner return lookup
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.view_column_rounded, size: 28, color: Colors.black87),
                                    const SizedBox(width: 4),
                                    Text(
                                      order.invoiceNumber,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Footer note
                          if (settings.receiptFooter.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              settings.receiptFooter,
                              style: const TextStyle(color: Colors.black54, fontSize: 9),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Divider(color: colors.border, height: 1),

            // Modal Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إغلاق المعاينة'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.print, size: 18),
                      label: Text(_isPrinting ? 'جاري الإرسال للطابعة...' : 'إرسال إلى الطابعة الفعلية'),
                      onPressed: _isPrinting ? null : _onPrint,
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

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 10,
    Color textColor = Colors.black,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? Colors.black : Colors.black87,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black26),
              ),
            );
          }),
        );
      },
    );
  }
}
