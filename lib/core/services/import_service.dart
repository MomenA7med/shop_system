import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../database/database_helper.dart';

class ImportedItemPreview {
  final String barcode;
  final String productName;
  final String categoryName;
  final String unit;
  final double costPrice;
  final double sellingPrice;
  final int quantity;
  final String? expiryDate;
  final bool isValid;
  final String? error;

  ImportedItemPreview({
    required this.barcode,
    required this.productName,
    required this.categoryName,
    this.unit = 'قطعة',
    required this.costPrice,
    required this.sellingPrice,
    required this.quantity,
    this.expiryDate,
    this.isValid = true,
    this.error,
  });
}

class ImportResult {
  final int totalRows;
  final int insertedProducts;
  final int updatedVariants;
  final int createdCategories;
  final List<String> errors;

  ImportResult({
    required this.totalRows,
    required this.insertedProducts,
    required this.updatedVariants,
    required this.createdCategories,
    required this.errors,
  });
}

class ImportService {
  /// Reads Excel (.xlsx / .xls) or CSV file and extracts items for preview
  static Future<List<ImportedItemPreview>> parseFileForPreview(File file) async {
    final path = file.path.toLowerCase();
    if (path.endsWith('.csv')) {
      return _parseCsv(file);
    } else if (path.endsWith('.xlsx') || path.endsWith('.xls')) {
      return _parseExcel(file);
    } else {
      throw Exception('صيغة الملف غير مدعومة! يرجى اختيار ملف Excel (.xlsx) أو ملف (.csv)');
    }
  }

  static Future<List<ImportedItemPreview>> _parseCsv(File file) async {
    final bytes = await file.readAsBytes();
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    // Strip BOM if present
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }

    final rows = const CsvToListConverter(shouldParseNumbers: false).convert(content);
    if (rows.isEmpty) return [];

    return _processRows(rows);
  }

  static Future<List<ImportedItemPreview>> _parseExcel(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) return [];

    final sheetName = excel.tables.keys.first;
    final table = excel.tables[sheetName];
    if (table == null || table.rows.isEmpty) return [];

    final rawRows = <List<dynamic>>[];
    for (final row in table.rows) {
      final cells = row.map((c) => c?.value?.toString() ?? '').toList();
      rawRows.add(cells);
    }

    return _processRows(rawRows);
  }

  static List<ImportedItemPreview> _processRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) return [];

    // 1. Find Header Row
    int headerIndex = -1;
    int barcodeCol = -1;
    int nameCol = -1;
    int qtyCol = -1;
    int unitCol = -1;
    int costCol = -1;
    int priceCol = -1;
    int catCol = -1;
    int expiryCol = -1;

    for (int i = 0; i < rows.length && i < 5; i++) {
      final row = rows[i].map((c) => c.toString().trim()).toList();

      for (int c = 0; c < row.length; c++) {
        final cell = row[c].toLowerCase();

        // Barcode / رقم المادة
        if (_matches(cell, ['رقم المادة', 'رقم الماده', 'الباركود', 'باركود', 'كود الصنف', 'كود', 'barcode', 'sku', 'code', 'item code'])) {
          barcodeCol = c;
        }
        // Name / اسم المادة
        else if (_matches(cell, ['اسم المادة', 'اسم الماده', 'اسم الصنف', 'اسم المنتج', 'الصنف', 'المنتج', 'name', 'product', 'item name', 'item'])) {
          nameCol = c;
        }
        // Quantity / الكمية
        else if (_matches(cell, ['الكمية', 'الكميه', 'الرصيد', 'المخزون', 'العدد', 'qty', 'quantity', 'stock', 'count'])) {
          qtyCol = c;
        }
        // Unit / الوحدة
        else if (_matches(cell, ['الوحدة', 'الوحده', 'العبوة', 'المقاس', 'الحجم', 'unit', 'package', 'size'])) {
          unitCol = c;
        }
        // Cost Price / سعر الجملة الإفرادي
        else if (_matches(cell, ['سعر الجملة الإفرادي', 'سعر الجملة الافرادي', 'سعر الجملة', 'سعر الشراء', 'سعر التكلفة', 'التكلفة', 'cost', 'cost_price', 'wholesale'])) {
          costCol = c;
        }
        // Selling Price / سعر البيع الإفرادي
        else if (_matches(cell, ['سعر البيع الإفرادي', 'سعر البيع الافرادي', 'سعر البيع', 'سعر المستهلك', 'البيع', 'price', 'selling_price', 'retail'])) {
          priceCol = c;
        }
        // Category / التصنيف
        else if (_matches(cell, ['التصنيف', 'القسم', 'المجموعة', 'المجموعه', 'category', 'group', 'dept'])) {
          catCol = c;
        }
        // Expiry Date / تاريخ الإنتهاء
        else if (_matches(cell, ['تاريخ الإنتهاء', 'تاريخ الانتهاء', 'الصلاحية', 'تاريخ الصلاحية', 'expiry', 'exp_date'])) {
          expiryCol = c;
        }
      }

      if (nameCol != -1 || barcodeCol != -1) {
        headerIndex = i;
        break;
      }
    }

    // Default column fallback if headers not named clearly
    if (headerIndex == -1) {
      headerIndex = 0;
      barcodeCol = 0;
      nameCol = 1;
      qtyCol = 2;
      unitCol = 3;
      costCol = 4;
      priceCol = 5;
      catCol = 6;
    }

    final items = <ImportedItemPreview>[];

    for (int r = headerIndex + 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      String getVal(int colIndex) {
        if (colIndex >= 0 && colIndex < row.length) {
          return row[colIndex]?.toString().trim() ?? '';
        }
        return '';
      }

      final rawName = getVal(nameCol);
      final rawBarcode = getVal(barcodeCol);
      final rawQty = getVal(qtyCol);
      final rawUnit = getVal(unitCol);
      final rawCost = getVal(costCol);
      final rawPrice = getVal(priceCol);
      final rawCat = getVal(catCol);
      final rawExpiry = getVal(expiryCol);

      // Skip completely empty lines
      if (rawName.isEmpty && rawBarcode.isEmpty) continue;

      final barcode = rawBarcode.isNotEmpty ? rawBarcode : 'GEN_${DateTime.now().millisecondsSinceEpoch}_$r';
      final name = rawName.isNotEmpty ? rawName : 'صنف غير مسمى ($barcode)';
      final category = rawCat.isNotEmpty ? rawCat : 'عام / غير مصنف';
      final unit = rawUnit.isNotEmpty ? rawUnit : 'قطعة';

      final qty = _parseInt(rawQty, 0);
      final cost = _parseDouble(rawCost, 0.0);
      final price = _parseDouble(rawPrice, cost > 0 ? cost * 1.25 : 0.0);

      items.add(ImportedItemPreview(
        barcode: barcode,
        productName: name,
        categoryName: category,
        unit: unit,
        costPrice: cost,
        sellingPrice: price,
        quantity: qty,
        expiryDate: rawExpiry.isNotEmpty ? rawExpiry : null,
      ));
    }

    return items;
  }

  static bool _matches(String cellText, List<String> aliases) {
    final clean = cellText.trim().toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    for (final alias in aliases) {
      final cleanAlias = alias.trim().toLowerCase().replaceAll(' ', '').replaceAll('_', '');
      if (clean == cleanAlias || clean.contains(cleanAlias)) {
        return true;
      }
    }
    return false;
  }

  static int _parseInt(String val, int fallback) {
    if (val.isEmpty) return fallback;
    final cleaned = val.replaceAll(',', '').replaceAll(' ', '');
    return int.tryParse(cleaned) ?? double.tryParse(cleaned)?.toInt() ?? fallback;
  }

  static double _parseDouble(String val, double fallback) {
    if (val.isEmpty) return fallback;
    final cleaned = val.replaceAll(',', '').replaceAll(' ', '');
    return double.tryParse(cleaned) ?? fallback;
  }

  /// Commits the imported items into SQLite database safely inside a transaction
  static Future<ImportResult> commitImport(List<ImportedItemPreview> items) async {
    final db = await DatabaseHelper.instance.database;

    int insertedProducts = 0;
    int updatedVariants = 0;
    int createdCategories = 0;
    final errors = <String>[];

    await db.transaction((txn) async {
      // 1. Load existing categories
      final catRows = await txn.query('categories');
      final catMap = <String, int>{};
      for (final r in catRows) {
        catMap[(r['name'] as String).trim().toLowerCase()] = r['id'] as int;
      }

      for (final item in items) {
        try {
          // A. Category check / insert
          final catKey = item.categoryName.trim().toLowerCase();
          int categoryId;
          if (catMap.containsKey(catKey)) {
            categoryId = catMap[catKey]!;
          } else {
            categoryId = await txn.insert('categories', {'name': item.categoryName.trim()});
            catMap[catKey] = categoryId;
            createdCategories++;
          }

          // B. Check if variant with this barcode already exists
          final existingVariants = await txn.query(
            'product_variants',
            where: 'sku_barcode = ?',
            whereArgs: [item.barcode.trim()],
            limit: 1,
          );

          if (existingVariants.isNotEmpty) {
            // Update existing variant price and add/set quantity
            final variantId = existingVariants.first['id'] as int;
            final currentStock = (existingVariants.first['stock_quantity'] as num?)?.toInt() ?? 0;
            final newStock = item.quantity > 0 ? currentStock + item.quantity : currentStock;

            await txn.update(
              'product_variants',
              {
                'size': item.unit,
                'cost_price': item.costPrice > 0 ? item.costPrice : existingVariants.first['cost_price'],
                'selling_price': item.sellingPrice > 0 ? item.sellingPrice : existingVariants.first['selling_price'],
                'stock_quantity': newStock,
              },
              where: 'id = ?',
              whereArgs: [variantId],
            );
            updatedVariants++;
          } else {
            // Insert new product
            final productId = await txn.insert('products', {
              'category_id': categoryId,
              'name': item.productName.trim(),
              'description': 'تم الاستيراد من ملف إكسيل/CSV',
              'created_at': DateTime.now().toIso8601String(),
            });

            // Insert variant
            await txn.insert('product_variants', {
              'product_id': productId,
              'sku_barcode': item.barcode.trim(),
              'size': item.unit,
              'color': 'افتراضي',
              'cost_price': item.costPrice,
              'selling_price': item.sellingPrice,
              'stock_quantity': item.quantity,
              'min_stock_alert': 5,
            });

            insertedProducts++;
          }
        } catch (e) {
          errors.add('خطأ في صنف (${item.productName}): $e');
        }
      }
    });

    return ImportResult(
      totalRows: items.length,
      insertedProducts: insertedProducts,
      updatedVariants: updatedVariants,
      createdCategories: createdCategories,
      errors: errors,
    );
  }

  /// Generates a standard Excel template (.xlsx bytes) matching the user's supermarket table
  static List<int> generateTemplateExcel() {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    // Header matching user's exact columns
    final headers = [
      'رقم المادة',
      'اسم المادة',
      'الكمية',
      'الوحدة',
      'سعر الجملة الإفرادي',
      'سعر البيع الإفرادي',
      'التصنيف',
      'تاريخ الإنتهاء',
    ];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    // Sample rows
    final sampleRows = [
      ['5449000321602', 'شويبس اناناس كانز 240 ملي', '69', 'علبة', '13', '15', 'مشروبات', '2027-12-31'],
      ['5449000255600', 'شويبس رمان كانز 240', '38', 'علبة', '13', '15', 'مشروبات', '2027-12-31'],
      ['5449000005540', 'شويبس اناناس 1 لتر', '12', 'زجاجة', '26', '35', 'مشروبات', '2027-12-31'],
      ['6223000551122', 'جبنة دومتي فيتا 500 جم', '50', 'علبة', '30', '38', 'ألبان وجبن', '2026-10-01'],
      ['6221004123456', 'شيبسي عائلي بالجبنة المتبلة', '100', 'كيس', '8.5', '10', 'شيبسي ومقرمشات', '2026-08-15'],
      ['7613035123456', 'نسكافيه بلاك كلاسيك 100 جم', '25', 'برطمان', '85', '110', 'مشروبات ساخنة', '2028-05-01'],
    ];

    for (final row in sampleRows) {
      sheet.appendRow(row.map((c) => TextCellValue(c)).toList());
    }

    return excel.encode() ?? [];
  }
}
