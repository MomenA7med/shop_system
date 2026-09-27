import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/order_model.dart';
import '../../models/store_settings_model.dart';
import '../../models/shift_model.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class PrintService {
  static Future<void> printReceipt({
    required OrderModel order,
    required StoreSettingsModel settings,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Store Header
                pw.Text(
                  settings.storeName,
                  style: pw.TextStyle(font: fontBold, fontSize: 16),
                  textAlign: pw.TextAlign.center,
                ),
                if (settings.slogan.isNotEmpty)
                  pw.Text(
                    settings.slogan,
                    style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
                    textAlign: pw.TextAlign.center,
                  ),
                if (settings.phone.isNotEmpty)
                  pw.Text('هاتف: ${settings.phone}', style: const pw.TextStyle(fontSize: 8)),
                if (settings.address.isNotEmpty)
                  pw.Text(settings.address, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                // Order Meta
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('فاتورة: ${order.invoiceNumber}', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('التاريخ: ${DateFormatter.formatDateTime(order.createdAt)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                if (order.cashierName != null)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('الكاشير: ${order.cashierName}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),

                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                // Items Table Header
                pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('الصنف / المقاس', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                    pw.Expanded(flex: 1, child: pw.Text('الكمية', style: pw.TextStyle(font: fontBold, fontSize: 8), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text('السعر', style: pw.TextStyle(font: fontBold, fontSize: 8), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text('الإجمالي', style: pw.TextStyle(font: fontBold, fontSize: 8), textAlign: pw.TextAlign.left)),
                  ],
                ),
                pw.Divider(thickness: 0.5),

                // Line Items
                ...order.items.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.productName, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                            pw.Text('(${item.size} - ${item.color})', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                      pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 2, child: pw.Text(item.unitPrice.toStringAsFixed(1), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 2, child: pw.Text(item.totalPrice.toStringAsFixed(1), style: pw.TextStyle(font: fontBold, fontSize: 8), textAlign: pw.TextAlign.left)),
                    ],
                  ),
                )),

                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                // Totals
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الإجمالي المطلوب:', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                    pw.Text(
                      CurrencyFormatter.format(order.totalAmount, symbol: settings.currencySymbol),
                      style: pw.TextStyle(font: fontBold, fontSize: 11),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('المبلغ المستلم (نقداً):', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(CurrencyFormatter.format(order.amountPaid, symbol: settings.currencySymbol), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الباقي للعميل:', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    pw.Text(CurrencyFormatter.format(order.changeDue, symbol: settings.currencySymbol), style: pw.TextStyle(font: fontBold, fontSize: 9)),
                  ],
                ),

                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                // Barcode representation for returns
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: order.invoiceNumber,
                  width: 140,
                  height: 35,
                  drawText: false,
                ),
                pw.Text(order.invoiceNumber, style: const pw.TextStyle(fontSize: 7)),

                pw.SizedBox(height: 6),
                if (settings.receiptFooter.isNotEmpty)
                  pw.Text(
                    settings.receiptFooter,
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
                    textAlign: pw.TextAlign.center,
                  ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_${order.invoiceNumber}',
    );
  }

  static Future<void> printShiftSummary({
    required ShiftModel shift,
    required StoreSettingsModel settings,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(settings.storeName, style: pw.TextStyle(font: fontBold, fontSize: 14)),
                pw.Text('تقرير إغلاق الوردية النقدي', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                pw.Divider(thickness: 1),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('رقم الوردية: #${shift.id}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('الكاشير: ${shift.cashierName ?? ""}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('بداية الوردية: ${DateFormatter.formatDateTime(shift.startTime)}', style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
                if (shift.endTime != null)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('إغلاق الوردية: ${DateFormatter.formatDateTime(shift.endTime!)}', style: const pw.TextStyle(fontSize: 7)),
                    ],
                  ),

                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                _buildShiftRow('رصيد البداية (العهدة):', shift.openingFloat, font, settings.currencySymbol),
                _buildShiftRow('مبيعات نقدية (+):', shift.cashSales, font, settings.currencySymbol),
                _buildShiftRow('مرتجعات نقدية (-):', shift.cashReturns, font, settings.currencySymbol),
                pw.Divider(thickness: 0.5),
                _buildShiftRow('النقد المتوقع بالدرج:', shift.expectedCash, fontBold, settings.currencySymbol, isBold: true),
                _buildShiftRow('النقد الفعلي المسلم:', shift.actualCash, fontBold, settings.currencySymbol, isBold: true),
                pw.Divider(thickness: 0.5),
                _buildShiftRow('الفارق (العجز / الزيادة):', shift.discrepancy, fontBold, settings.currencySymbol, isBold: true),

                pw.SizedBox(height: 10),
                pw.Text('توقيع الكاشير: ........................', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Shift_${shift.id}',
    );
  }

  static pw.Widget _buildShiftRow(String title, double amount, pw.Font font, String currency, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: isBold ? 9 : 8)),
          pw.Text(
            CurrencyFormatter.format(amount, symbol: currency),
            style: pw.TextStyle(font: font, fontSize: isBold ? 9 : 8),
          ),
        ],
      ),
    );
  }
}
