import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/barcode_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/number_parser.dart';
import '../../models/product_variant_model.dart';
import '../../providers/settings_provider.dart';

class BarcodePrintDialog extends StatefulWidget {
  final String productName;
  final ProductVariantModel variant;

  const BarcodePrintDialog({
    super.key,
    required this.productName,
    required this.variant,
  });

  @override
  State<BarcodePrintDialog> createState() => _BarcodePrintDialogState();
}

class _BarcodePrintDialogState extends State<BarcodePrintDialog> {
  final TextEditingController _copiesController = TextEditingController(text: '10');
  bool _isPrinting = false;

  @override
  void dispose() {
    _copiesController.dispose();
    super.dispose();
  }

  void _onPrint() async {
    final copies = NumberParser.tryParseInt(_copiesController.text.trim(), 1);
    if (copies <= 0) return;

    setState(() => _isPrinting = true);
    final settings = context.read<SettingsProvider>().settings;

    try {
      await BarcodeService.printBarcodeLabels(
        productName: widget.productName,
        variant: widget.variant,
        settings: settings,
        copies: copies,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الطباعة: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = context.watch<SettingsProvider>().settings;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.print_outlined, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.printBarcodes,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: colors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const Divider(height: 24),

            // Live Label Preview (Physical sticker mockup)
            Center(
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      settings.storeName,
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.productName,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('المقاس: ${widget.variant.size}', style: const TextStyle(color: Colors.black54, fontSize: 10)),
                        const SizedBox(width: 8),
                        Text('اللون: ${widget.variant.color}', style: const TextStyle(color: Colors.black54, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Visual Barcode Bars Representation
                    Container(
                      height: 35,
                      width: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.view_column_rounded, size: 28, color: Colors.black87),
                            const SizedBox(width: 4),
                            Text(
                              widget.variant.skuBarcode,
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'السعر: ${CurrencyFormatter.format(widget.variant.sellingPrice, symbol: settings.currencySymbol)}',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Number of copies input
            Text(
              AppStrings.barcodeCopies,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _copiesController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'أدخل عدد الملصقات (مثلاً 50)',
                      hintStyle: TextStyle(color: colors.textMuted),
                      prefixIcon: Icon(Icons.copy, size: 18, color: colors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Quick Copy Buttons
                ...[10, 25, 50, 100].map((c) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _copiesController.text = c.toString(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        '$c',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                      ),
                    ),
                  ),
                )),
              ],
            ),

            const SizedBox(height: 24),

            // Dialog Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(AppStrings.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: _isPrinting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.print, size: 18),
                    label: Text(_isPrinting ? 'جاري التجهيز...' : AppStrings.printBarcodes),
                    onPressed: _isPrinting ? null : _onPrint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
