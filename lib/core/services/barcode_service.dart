import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/product_variant_model.dart';
import '../../models/store_settings_model.dart';
import '../utils/currency_formatter.dart';

class BarcodeService {
  /// Generate a unique 8-digit barcode for a variant
  static String generateUniqueBarcode() {
    final random = Random();
    final timestampPart = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    final randomPart = (random.nextInt(90) + 10).toString();
    return '$randomPart$timestampPart';
  }

  /// Print barcode labels with customizable copy count
  static Future<void> printBarcodeLabels({
    required String productName,
    required ProductVariantModel variant,
    required StoreSettingsModel settings,
    required int copies,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    // Standard Label dimensions: ~50mm x 30mm per sticker
    const labelWidth = 50.0 * PdfPageFormat.mm;
    const labelHeight = 30.0 * PdfPageFormat.mm;

    for (int i = 0; i < copies; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(labelWidth, labelHeight, marginAll: 2 * PdfPageFormat.mm),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              padding: const pw.EdgeInsets.all(3),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Store Name
                  pw.Text(
                    settings.storeName,
                    style: pw.TextStyle(font: fontBold, fontSize: 7),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                  ),

                  // Product Name & Variant Details
                  pw.Text(
                    productName,
                    style: pw.TextStyle(font: fontBold, fontSize: 8),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text('الوحدة: ${variant.size}', style: const pw.TextStyle(fontSize: 7)),
                      if (variant.color.isNotEmpty && variant.color != 'افتراضي' && variant.color != '-') ...[
                        pw.SizedBox(width: 6),
                        pw.Text('البيان: ${variant.color}', style: const pw.TextStyle(fontSize: 7)),
                      ],
                    ],
                  ),

                  // Barcode
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: variant.skuBarcode,
                    width: 100,
                    height: 22,
                    drawText: false,
                  ),
                  pw.Text(variant.skuBarcode, style: const pw.TextStyle(fontSize: 6)),

                  // Price
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Text(
                      'السعر: ${CurrencyFormatter.format(variant.sellingPrice, symbol: settings.currencySymbol)}',
                      style: pw.TextStyle(font: fontBold, fontSize: 8),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Barcode_${variant.skuBarcode}_$copies',
    );
  }
}
