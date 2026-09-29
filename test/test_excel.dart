import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_system/core/services/import_service.dart';

void main() {
  test('Parses supermarket report matching user screenshot', () async {
    final excel = Excel.createExcel();
    final sheet = excel['productsrep'];

    // Top Title rows (like in the screenshot)
    sheet.appendRow([TextCellValue('هايبر ماركت الأمين')]);
    sheet.appendRow([TextCellValue('قائمة المواد | جرد المواد')]);
    sheet.appendRow([TextCellValue('')]);

    // Table Header Row
    sheet.appendRow([
      TextCellValue('رقم المادة'),
      TextCellValue('اسم المادة'),
      TextCellValue('الكمية'),
      TextCellValue('الوحدة'),
      TextCellValue('سعر الجملة الإفرادي'),
      TextCellValue('سعر البيع الإفرادي'),
      TextCellValue('التصنيف'),
      TextCellValue('تاريخ الإنتهاء'),
    ]);

    // Data rows
    sheet.appendRow([
      TextCellValue('5449000321602'),
      TextCellValue('شويبس اناناس كانز 240 ملي'),
      IntCellValue(69),
      TextCellValue('علبة'),
      DoubleCellValue(13.0),
      DoubleCellValue(15.0),
      TextCellValue('مشروبات'),
      TextCellValue('2090/12/01 12:00:00'),
    ]);

    sheet.appendRow([
      TextCellValue('5449000255600'),
      TextCellValue('شويبس رمان كانز 240'),
      IntCellValue(38),
      TextCellValue('علبة'),
      DoubleCellValue(13.0),
      DoubleCellValue(15.0),
      TextCellValue('مشروبات'),
      TextCellValue('2090/12/01 12:00:00'),
    ]);

    sheet.appendRow([
      TextCellValue('54025714'),
      TextCellValue('شويبس اكشن'),
      IntCellValue(30),
      TextCellValue(''),
      DoubleCellValue(9.0),
      DoubleCellValue(12.0),
      TextCellValue('مشروبات'),
      TextCellValue('2090/12/01 12:00:00'),
    ]);

    // Summary footer rows
    sheet.appendRow([TextCellValue('مجموع سعر الجملة: 0')]);
    sheet.appendRow([TextCellValue('مجموع سعر البيع: 0')]);

    final bytes = excel.encode()!;
    final tempFile = File('${Directory.systemTemp.path}/test_productsrep.xlsx');
    await tempFile.writeAsBytes(bytes);

    final items = await ImportService.parseFileForPreview(tempFile);

    expect(items.length, 3);
    expect(items[0].barcode, '5449000321602');
    expect(items[0].productName, 'شويبس اناناس كانز 240 ملي');
    expect(items[0].quantity, 69);
    expect(items[0].unit, 'علبة');
    expect(items[0].costPrice, 13.0);
    expect(items[0].sellingPrice, 15.0);
    expect(items[0].categoryName, 'مشروبات');

    expect(items[1].barcode, '5449000255600');
    expect(items[1].productName, 'شويبس رمان كانز 240');
    expect(items[1].quantity, 38);

    expect(items[2].barcode, '54025714');
    expect(items[2].productName, 'شويبس اكشن');
    expect(items[2].quantity, 30);
    expect(items[2].unit, 'قطعة'); // fallback for empty unit

    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }
  });
}
