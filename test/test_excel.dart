// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_system/core/services/import_service.dart';

void main() {
  test('Full integration test on user downloads productsrep.xlsx', () async {
    final file = File('/Users/moamenahmed/Downloads/productsrep.xlsx');
    if (!file.existsSync()) return;

    final items = await ImportService.parseFileForPreview(file);

    expect(items.length, 15);
    expect(items[0].productName, 'شويبس اناناس كانز 240 ملي');
    expect(items[0].barcode, '5449000321602');
    expect(items[0].quantity, 69);
    expect(items[0].unit, 'علبة');
    expect(items[0].costPrice, 12.7);
    expect(items[0].sellingPrice, 15.0);
    expect(items[0].categoryName, 'مشروبات');

    expect(items[13].productName, 'شويبس اكشن');
    expect(items[13].barcode, '54025714');
    expect(items[13].quantity, 30);
    expect(items[13].unit, 'قطعة'); // fallback for empty unit
    expect(items[13].costPrice, 9.0);
    expect(items[13].sellingPrice, 12.0);
  });
}
