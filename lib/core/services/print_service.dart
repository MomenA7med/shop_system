import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/store_settings_model.dart';
import '../../models/shift_model.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class PrintService {
  // Safe 80mm thermal page format with hardware margin clearance (prevents edge clipping)
  static const PdfPageFormat thermalRoll80 = PdfPageFormat(
    80 * PdfPageFormat.mm,
    double.infinity,
    marginLeft: 6 * PdfPageFormat.mm,
    marginRight: 6 * PdfPageFormat.mm,
    marginTop: 4 * PdfPageFormat.mm,
    marginBottom: 12 * PdfPageFormat.mm,
  );

  static Future<void> printReceipt({
    required OrderModel order,
    required StoreSettingsModel settings,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    doc.addPage(
      pw.Page(
        pageFormat: thermalRoll80,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // 1. Store Header (Solid Black)
                pw.Text(
                  settings.storeName,
                  style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.black),
                  textAlign: pw.TextAlign.center,
                ),
                if (settings.slogan.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    settings.slogan,
                    style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.black),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
                if (settings.phone.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'هاتف: ${settings.phone}',
                    style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.black),
                  ),
                ],
                if (settings.address.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    settings.address,
                    style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.black),
                    textAlign: pw.TextAlign.center,
                  ),
                ],

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1, color: PdfColors.black, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // 2. Order Metadata (Solid Black)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'فاتورة: #${order.invoiceNumber}',
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'التاريخ: ${DateFormatter.formatDateTime(order.createdAt)}',
                      style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.black),
                    ),
                  ],
                ),
                if (order.cashierName != null && order.cashierName!.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'الكاشير: ${order.cashierName}',
                        style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.black),
                      ),
                    ],
                  ),
                ],

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1, color: PdfColors.black, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // 3. Items Table Header (Optimized column widths to prevent text wrapping)
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text(
                        'الصنف / المقاس',
                        style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.black),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'الكمية',
                        style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.black),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'السعر',
                        style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.black),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'الإجمالي',
                        style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.black),
                        textAlign: pw.TextAlign.left,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Divider(thickness: 0.8, color: PdfColors.black),
                pw.SizedBox(height: 2),

                // 4. Line Items (Only items with remainingQuantity > 0)
                ...(){
                  final activeItems = order.items.where((i) => i.remainingQuantity > 0).toList();
                  if (activeItems.isEmpty) {
                    return [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6),
                        child: pw.Center(
                          child: pw.Text(
                            'لا توجد أصناف في الفاتورة (مسترجعة بالكامل)',
                            style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.black),
                          ),
                        ),
                      ),
                    ];
                  }

                  return activeItems.map(
                    (item) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 5,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  item.productName,
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 8.5,
                                    color: PdfColors.black,
                                  ),
                                ),
                                pw.Text(
                                  '(${item.size} - ${item.color})',
                                  style: pw.TextStyle(
                                    font: font,
                                    fontSize: 7.5,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              '${item.remainingQuantity}',
                              style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.black),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              item.unitPrice.toStringAsFixed(1),
                              style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.black),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              item.netTotalPrice.toStringAsFixed(1),
                              style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.black),
                              textAlign: pw.TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).toList();
                }(),

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1, color: PdfColors.black, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // 5. Totals & Financial Breakdown (Clean new totals)
                ...(){
                  final activeItems = order.items.where((i) => i.remainingQuantity > 0).toList();
                  final activeSubtotal = activeItems.fold(0.0, (sum, i) => sum + i.netTotalPrice);
                  final activeTotal = order.netTotalAmount;
                  final activeDiscount = (activeSubtotal + order.deliveryFee > activeTotal)
                      ? (activeSubtotal + order.deliveryFee - activeTotal)
                      : 0.0;

                  return [
                    if (activeDiscount > 0 || order.deliveryFee > 0) ...[
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'المجموع الفرعي:',
                            style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.black),
                          ),
                          pw.Text(
                            CurrencyFormatter.format(
                              activeSubtotal,
                              symbol: settings.currencySymbol,
                            ),
                            style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.black),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                    ],
                    if (order.deliveryFee > 0) ...[
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'خدمة التوصيل (+):',
                            style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.black),
                          ),
                          pw.Text(
                            '+ ${CurrencyFormatter.format(order.deliveryFee, symbol: settings.currencySymbol)}',
                            style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.black),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                    ],
                    if (activeDiscount > 0) ...[
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'الخصم (-):',
                            style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black),
                          ),
                          pw.Text(
                            '- ${CurrencyFormatter.format(activeDiscount, symbol: settings.currencySymbol)}',
                            style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                    ],

                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'الإجمالي المطلوب:',
                          style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black),
                        ),
                        pw.Text(
                          CurrencyFormatter.format(
                            activeTotal,
                            symbol: settings.currencySymbol,
                          ),
                          style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black),
                        ),
                      ],
                    ),
                  ];
                }(),

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1, color: PdfColors.black, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // 6. Return Barcode (Solid crisp black)
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: order.invoiceNumber,
                  width: 130,
                  height: 30,
                  color: PdfColors.black,
                  drawText: false,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  order.invoiceNumber,
                  style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.black),
                ),

                // 7. Footer Return Policy Note
                if (settings.receiptFooter.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    settings.receiptFooter,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 7.5,
                      color: PdfColors.black,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],

                // Extra safety bottom spacing for physical paper tear
                pw.SizedBox(height: 10),
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
        pageFormat: thermalRoll80,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  settings.storeName,
                  style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'تقرير إغلاق الوردية النقدي',
                  style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.black),
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1, color: PdfColors.black),
                pw.SizedBox(height: 4),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'رقم الوردية: #${shift.id}',
                      style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.black),
                    ),
                    pw.Text(
                      'الكاشير: ${shift.cashierName ?? ""}',
                      style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.black),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'بداية الوردية: ${DateFormatter.formatDateTime(shift.startTime)}',
                      style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.black),
                    ),
                  ],
                ),
                if (shift.endTime != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'إغلاق الوردية: ${DateFormatter.formatDateTime(shift.endTime!)}',
                        style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.black),
                      ),
                    ],
                  ),
                ],

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1, color: PdfColors.black, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                _buildShiftRow(
                  'رصيد البداية (العهدة):',
                  shift.openingFloat,
                  font,
                  settings.currencySymbol,
                ),
                _buildShiftRow(
                  'مبيعات نقدية (+):',
                  shift.cashSales,
                  font,
                  settings.currencySymbol,
                ),
                _buildShiftRow(
                  'مرتجعات نقدية (-):',
                  shift.cashReturns,
                  font,
                  settings.currencySymbol,
                ),
                pw.Divider(thickness: 0.8, color: PdfColors.black),
                _buildShiftRow(
                  'النقد المتوقع بالدرج:',
                  shift.expectedCash,
                  fontBold,
                  settings.currencySymbol,
                  isBold: true,
                ),
                _buildShiftRow(
                  'النقد الفعلي المسلم:',
                  shift.actualCash,
                  fontBold,
                  settings.currencySymbol,
                  isBold: true,
                ),
                pw.Divider(thickness: 0.8, color: PdfColors.black),
                _buildShiftRow(
                  'الفارق (العجز / الزيادة):',
                  shift.discrepancy,
                  fontBold,
                  settings.currencySymbol,
                  isBold: true,
                ),

                pw.SizedBox(height: 10),
                pw.Text(
                  'توقيع الكاشير: ........................',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.black),
                ),
                pw.SizedBox(height: 10),
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

  static pw.Widget _buildShiftRow(
    String title,
    double amount,
    pw.Font font,
    String currency, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(font: font, fontSize: isBold ? 8.5 : 8, color: PdfColors.black),
          ),
          pw.Text(
            CurrencyFormatter.format(amount, symbol: currency),
            style: pw.TextStyle(font: font, fontSize: isBold ? 8.5 : 8, color: PdfColors.black),
          ),
        ],
      ),
    );
  }

  // ================= FINANCIAL & PROFIT REPORTS (A4 PDF) =================
  static Future<Uint8List> generateFinancialReportPdf({
    required Map<String, dynamic> financialStats,
    required List<Map<String, dynamic>> topProducts,
    required List<Map<String, dynamic>> categorySales,
    required StoreSettingsModel settings,
    required String periodLabel,
  }) async {
    final doc = pw.Document();
    pw.Font font;
    pw.Font fontBold;
    try {
      font = await PdfGoogleFonts.cairoRegular();
      fontBold = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      font = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final totalSales = (financialStats['total_sales'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = (financialStats['total_orders'] as int?) ?? 0;
    final cashSales = (financialStats['cash_sales'] as num?)?.toDouble() ?? 0.0;
    final cardSales = (financialStats['card_sales'] as num?)?.toDouble() ?? 0.0;
    final totalReturns = (financialStats['total_returns'] as num?)?.toDouble() ?? 0.0;
    final returnCount = (financialStats['return_count'] as int?) ?? 0;
    final netProfit = (financialStats['net_profit'] as num?)?.toDouble() ?? 0.0;
    final totalCogs = (financialStats['total_cogs'] as num?)?.toDouble() ?? 0.0;
    final marginPct = totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      settings.storeName,
                      style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.black),
                    ),
                    if (settings.slogan.isNotEmpty)
                      pw.Text(
                        settings.slogan,
                        style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'تقرير المبيعات والأرباح المالية',
                      style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900),
                    ),
                    pw.Text(
                      'الفترة: $periodLabel',
                      style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800),
                    ),
                    pw.Text(
                      'تاريخ الاستخراج: ${DateFormatter.formatDateTime(DateTime.now())}',
                      style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${settings.address} - هاتف: ${settings.phone}',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 12),

            // 1. KPI Summary Cards Grid
            pw.Text(
              'أولاً: الملخص المالي للفترة',
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black),
            ),
            pw.SizedBox(height: 6),

            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildPdfKpiCard(
                    title: 'إجمالي المبيعات',
                    value: CurrencyFormatter.format(totalSales, symbol: settings.currencySymbol),
                    subtitle: 'عدد الفواتير: $totalOrders',
                    font: font,
                    fontBold: fontBold,
                    bgColor: PdfColors.blue50,
                    borderColor: PdfColors.blue300,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildPdfKpiCard(
                    title: 'صافي الأرباح',
                    value: CurrencyFormatter.format(netProfit, symbol: settings.currencySymbol),
                    subtitle: 'هامش الربح: ${marginPct.toStringAsFixed(1)}%',
                    font: font,
                    fontBold: fontBold,
                    bgColor: PdfColors.green50,
                    borderColor: PdfColors.green300,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildPdfKpiCard(
                    title: 'تكلفة البضاعة (COGS)',
                    value: CurrencyFormatter.format(totalCogs, symbol: settings.currencySymbol),
                    subtitle: 'سعر تكلفة المنتجات المباعة',
                    font: font,
                    fontBold: fontBold,
                    bgColor: PdfColors.purple50,
                    borderColor: PdfColors.purple300,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildPdfKpiCard(
                    title: 'إجمالي المرتجعات',
                    value: CurrencyFormatter.format(totalReturns, symbol: settings.currencySymbol),
                    subtitle: 'عدد المرتجعات: $returnCount',
                    font: font,
                    fontBold: fontBold,
                    bgColor: PdfColors.orange50,
                    borderColor: PdfColors.orange300,
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 8),

            // Payment Methods summary row
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text(
                    'مبيعات نقدية (كاش): ${CurrencyFormatter.format(cashSales, symbol: settings.currencySymbol)}',
                    style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.grey900),
                  ),
                  pw.Text(
                    '|',
                    style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey400),
                  ),
                  pw.Text(
                    'مبيعات شبكة / إلكتروني: ${CurrencyFormatter.format(cardSales, symbol: settings.currencySymbol)}',
                    style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.grey900),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // 2. Category Sales Breakdown
            if (categorySales.isNotEmpty) ...[
              pw.Text(
                'ثانياً: المبيعات حسب التصنيف',
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                headerHeight: 22,
                cellHeight: 20,
                cellStyle: pw.TextStyle(font: font, fontSize: 8),
                headers: ['#', 'اسم التصنيف', 'القطع المباعة', 'إجمالي المبيعات', 'النسبة من الإجمالي'],
                data: List.generate(categorySales.length, (i) {
                  final cat = categorySales[i];
                  final catRevenue = (cat['total_revenue'] as num?)?.toDouble() ?? 0.0;
                  final catSoldQty = cat['total_sold_qty'] as int? ?? 0;
                  final share = totalSales > 0 ? (catRevenue / totalSales) * 100 : 0.0;
                  return [
                    '${i + 1}',
                    cat['category_name'] as String? ?? 'عام',
                    '$catSoldQty قطعة',
                    CurrencyFormatter.format(catRevenue, symbol: settings.currencySymbol),
                    '${share.toStringAsFixed(1)}%',
                  ];
                }),
              ),
              pw.SizedBox(height: 16),
            ],

            // 3. Top Selling Products Table
            pw.Text(
              'ثالثاً: المنتجات والأصناف الأكثر مبيعاً في الفترة',
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black),
            ),
            pw.SizedBox(height: 6),
            if (topProducts.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'لا توجد مبيعات مسجلة في هذه الفترة',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
                headerHeight: 22,
                cellHeight: 20,
                cellStyle: pw.TextStyle(font: font, fontSize: 8),
                headers: ['#', 'اسم المنتج', 'المقاس واللون', 'الباركود', 'الكمية المباعة', 'إجمالي الإيراد'],
                data: List.generate(topProducts.length, (i) {
                  final item = topProducts[i];
                  final soldQty = item['total_sold_qty'] as int? ?? 0;
                  final revenue = (item['total_revenue'] as num?)?.toDouble() ?? 0.0;
                  return [
                    '${i + 1}',
                    item['product_name'] as String? ?? '',
                    '${item['size']} - ${item['color']}',
                    item['sku_barcode'] as String? ?? '',
                    '$soldQty قطعة',
                    CurrencyFormatter.format(revenue, symbol: settings.currencySymbol),
                  ];
                }),
              ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildPdfKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required pw.Font font,
    required pw.Font fontBold,
    required PdfColor bgColor,
    required PdfColor borderColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey800)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black)),
          pw.SizedBox(height: 3),
          pw.Text(subtitle, style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  static Future<void> printFinancialReport({
    required Map<String, dynamic> financialStats,
    required List<Map<String, dynamic>> topProducts,
    required List<Map<String, dynamic>> categorySales,
    required StoreSettingsModel settings,
    required String periodLabel,
  }) async {
    final bytes = await generateFinancialReportPdf(
      financialStats: financialStats,
      topProducts: topProducts,
      categorySales: categorySales,
      settings: settings,
      periodLabel: periodLabel,
    );

    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Financial_Report_$dateStr',
    );
  }

  static Future<String?> exportFinancialReportPdf({
    required Map<String, dynamic> financialStats,
    required List<Map<String, dynamic>> topProducts,
    required List<Map<String, dynamic>> categorySales,
    required StoreSettingsModel settings,
    required String periodLabel,
  }) async {
    final bytes = await generateFinancialReportPdf(
      financialStats: financialStats,
      topProducts: topProducts,
      categorySales: categorySales,
      settings: settings,
      periodLabel: periodLabel,
    );

    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final defaultFileName = 'تقرير_المبيعات_والارباح_$dateStr.pdf';

    return _saveFileBytes(
      dialogTitle: 'حفظ ملف تقرير الأرباح والمبيعات PDF',
      defaultFileName: defaultFileName,
      extension: 'pdf',
      bytes: bytes,
    );
  }

  /// Universal cross-platform helper to safely save files on Windows, macOS, and Linux
  static Future<String?> _saveFileBytes({
    required String dialogTitle,
    required String defaultFileName,
    required String extension,
    required Uint8List bytes,
  }) async {
    final savePath = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );

    if (savePath == null) return null;

    String pathStr;
    try {
      if (savePath.hasScheme && savePath.scheme == 'file') {
        pathStr = savePath.toFilePath();
      } else if (savePath.scheme.isEmpty) {
        pathStr = savePath.path;
      } else {
        pathStr = savePath.toFilePath();
      }
    } catch (_) {
      pathStr = savePath.path.isNotEmpty ? savePath.path : savePath.toString();
    }

    // Windows safety: ensure extension is present
    final extLower = extension.toLowerCase();
    if (!pathStr.toLowerCase().endsWith('.$extLower')) {
      pathStr = '$pathStr.$extLower';
    }

    final file = File(pathStr);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes, flush: true);
    }

    return pathStr;
  }

  // ================= INVENTORY & VARIANTS REPORTS (A4 PDF & EXCEL/CSV) =================
  static Future<Uint8List> generateInventoryReportPdf({
    required List<ProductModel> products,
    required StoreSettingsModel settings,
    String? categoryFilterName,
    String? searchQuery,
  }) async {
    final doc = pw.Document();
    pw.Font font;
    pw.Font fontBold;
    try {
      font = await PdfGoogleFonts.cairoRegular();
      fontBold = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      font = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final totalProducts = products.length;
    final totalVariants = products.fold(0, (sum, p) => sum + p.variants.length);
    final totalStockPieces = products.fold(0.0, (sum, p) => sum + p.totalStock);
    final totalCostValue = products.fold(
      0.0,
      (sum, p) => sum + p.variants.fold(0.0, (vSum, v) => vSum + (v.stockQuantity * v.costPrice)),
    );
    final totalSellingValue = products.fold(
      0.0,
      (sum, p) => sum + p.variants.fold(0.0, (vSum, v) => vSum + (v.stockQuantity * v.sellingPrice)),
    );
    final lowStockCount = products.fold(0, (sum, p) => sum + p.variants.where((v) => v.isLowStock).length);
    final outOfStockCount = products.fold(0, (sum, p) => sum + p.variants.where((v) => v.isOutOfStock).length);

    // Flatten all variants
    final List<Map<String, dynamic>> flatItems = [];
    for (final product in products) {
      for (final v in product.variants) {
        flatItems.add({
          'product_name': product.name,
          'category_name': product.categoryName ?? 'عام',
          'size': v.size,
          'color': v.color,
          'sku_barcode': v.skuBarcode,
          'stock_quantity': v.stockQuantity,
          'cost_price': v.costPrice,
          'selling_price': v.sellingPrice,
          'total_cost': v.stockQuantity * v.costPrice,
          'total_selling': v.stockQuantity * v.sellingPrice,
          'is_low': v.isLowStock,
          'is_out': v.isOutOfStock,
        });
      }
    }

    String filterBadge = 'جميع المنتجات';
    if (categoryFilterName != null && categoryFilterName.isNotEmpty) {
      filterBadge = 'التصنيف: $categoryFilterName';
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      filterBadge += ' (بحث: "$searchQuery")';
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      settings.storeName,
                      style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.black),
                    ),
                    if (settings.slogan.isNotEmpty)
                      pw.Text(
                        settings.slogan,
                        style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'تقرير جرد المخزون والأصناف',
                      style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.indigo900),
                    ),
                    pw.Text(
                      'الفلتر: $filterBadge',
                      style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800),
                    ),
                    pw.Text(
                      'تاريخ الجرد: ${DateFormatter.formatDateTime(DateTime.now())}',
                      style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${settings.address} - هاتف: ${settings.phone}',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 12),

            // 1. KPI Summary Cards Grid
            pw.Text(
              'أولاً: ملخص إحصائيات المخزون والجرد',
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black),
            ),
            pw.SizedBox(height: 6),

            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildPdfKpiCard(
                    title: 'إجمالي الموديلات والأصناف',
                    value: '$totalProducts موديل ($totalVariants صنف)',
                    subtitle: 'إجمالي الأصناف المسجلة',
                    font: font,
                    fontBold: fontBold,
                    bgColor: PdfColors.blue50,
                    borderColor: PdfColors.blue300,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildPdfKpiCard(
                    title: 'إجمالي القطع في المخزن',
                    value: '$totalStockPieces قطعة',
                    subtitle: 'الرصيد الفعلي المتوفر',
                    font: font,
                    fontBold: fontBold,
                    bgColor: PdfColors.teal50,
                    borderColor: PdfColors.teal300,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildPdfKpiCard(
                    title: 'قيمة المخزون (سعر التكلفة)',
                    value: CurrencyFormatter.format(totalCostValue, symbol: settings.currencySymbol),
                    subtitle: 'رأس المال في المخزن',
                    font: font,
                    fontBold: fontBold,
                    bgColor: PdfColors.purple50,
                    borderColor: PdfColors.purple300,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildPdfKpiCard(
                    title: 'القيمة البيعية المتوقعة',
                    value: CurrencyFormatter.format(totalSellingValue, symbol: settings.currencySymbol),
                    subtitle: 'الربح المتوقع: ${CurrencyFormatter.format(totalSellingValue - totalCostValue, symbol: settings.currencySymbol)}',
                    font: font,
                    fontBold: fontBold,
                    bgColor: PdfColors.green50,
                    borderColor: PdfColors.green300,
                  ),
                ),
              ],
            ),

            if (lowStockCount > 0 || outOfStockCount > 0) ...[
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.amber300, width: 0.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'تنبيهات المخزون: $lowStockCount صنف قارب على النفاد | $outOfStockCount صنف نفد تماماً (رصيد 0)',
                      style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.amber900),
                    ),
                  ],
                ),
              ),
            ],

            pw.SizedBox(height: 16),

            // 2. Inventory Items Table
            pw.Text(
              'ثانياً: بيان وتفاصيل الأصناف والمتغيرات',
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black),
            ),
            pw.SizedBox(height: 6),

            if (flatItems.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'لا توجد أصناف مسجلة في المخزن مطابقة للبحث أو الفلتر المحدد',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                headerHeight: 22,
                cellHeight: 20,
                cellStyle: pw.TextStyle(font: font, fontSize: 7.5),
                headers: ['#', 'اسم المنتج', 'التصنيف', 'المقاس واللون', 'الباركود', 'الكمية', 'التكلفة', 'سعر البيع', 'إجمالي التكلفة', 'الحالة'],
                data: List.generate(flatItems.length, (i) {
                  final item = flatItems[i];
                  final isLow = item['is_low'] as bool;
                  final isOut = item['is_out'] as bool;
                  final statusStr = isOut ? 'نفد (0)' : (isLow ? 'منخفض (${item['stock_quantity']})' : 'متوفر');

                  return [
                    '${i + 1}',
                    item['product_name'] as String,
                    item['category_name'] as String,
                    '${item['size']} - ${item['color']}',
                    item['sku_barcode'] as String,
                    '${item['stock_quantity']}',
                    CurrencyFormatter.format(item['cost_price'] as double, symbol: settings.currencySymbol),
                    CurrencyFormatter.format(item['selling_price'] as double, symbol: settings.currencySymbol),
                    CurrencyFormatter.format(item['total_cost'] as double, symbol: settings.currencySymbol),
                    statusStr,
                  ];
                }),
              ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static Future<void> printInventoryReport({
    required List<ProductModel> products,
    required StoreSettingsModel settings,
    String? categoryFilterName,
    String? searchQuery,
  }) async {
    final bytes = await generateInventoryReportPdf(
      products: products,
      settings: settings,
      categoryFilterName: categoryFilterName,
      searchQuery: searchQuery,
    );

    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Inventory_Report_$dateStr',
    );
  }

  static Future<String?> exportInventoryReportPdf({
    required List<ProductModel> products,
    required StoreSettingsModel settings,
    String? categoryFilterName,
    String? searchQuery,
  }) async {
    final bytes = await generateInventoryReportPdf(
      products: products,
      settings: settings,
      categoryFilterName: categoryFilterName,
      searchQuery: searchQuery,
    );

    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final defaultFileName = 'تقرير_جرد_المخزون_$dateStr.pdf';

    return _saveFileBytes(
      dialogTitle: 'حفظ ملف تقرير جرد المخزون PDF',
      defaultFileName: defaultFileName,
      extension: 'pdf',
      bytes: bytes,
    );
  }

  static Future<String?> exportInventoryReportCsv({
    required List<ProductModel> products,
    required StoreSettingsModel settings,
    String? categoryFilterName,
    String? searchQuery,
  }) async {
    final buffer = StringBuffer();
    // UTF-8 BOM for Excel Arabic compatibility
    buffer.write('\uFEFF');

    // CSV Header row
    buffer.writeln(
      '"م","اسم المنتج","التصنيف","المقاس","اللون","الباركود","الكمية الحالية","سعر التكلفة","سعر البيع","إجمالي التكلفة","إجمالي البيع المتوقع","حالة المخزون"',
    );

    int index = 1;
    for (final product in products) {
      for (final v in product.variants) {
        final totalCost = v.stockQuantity * v.costPrice;
        final totalSelling = v.stockQuantity * v.sellingPrice;
        final status = v.isOutOfStock ? 'نفد' : (v.isLowStock ? 'منخفض' : 'متوفر');

        final row = [
          index.toString(),
          '"${product.name.replaceAll('"', '""')}"',
          '"${(product.categoryName ?? 'عام').replaceAll('"', '""')}"',
          '"${v.size.replaceAll('"', '""')}"',
          '"${v.color.replaceAll('"', '""')}"',
          '"${v.skuBarcode.replaceAll('"', '""')}"',
          v.stockQuantity.toString(),
          v.costPrice.toStringAsFixed(2),
          v.sellingPrice.toStringAsFixed(2),
          totalCost.toStringAsFixed(2),
          totalSelling.toStringAsFixed(2),
          '"$status"',
        ];

        buffer.writeln(row.join(','));
        index++;
      }
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final defaultFileName = 'بيانات_المخزون_والأصناف_$dateStr.csv';

    return _saveFileBytes(
      dialogTitle: 'حفظ ملف بيانات المخزون والأصناف (Excel CSV)',
      defaultFileName: defaultFileName,
      extension: 'csv',
      bytes: bytes,
    );
  }
}
