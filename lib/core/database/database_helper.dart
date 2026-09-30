import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/user_model.dart';
import '../../models/store_settings_model.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/product_variant_model.dart';
import '../../models/order_model.dart';
import '../../models/order_item_model.dart';
import '../../models/shift_model.dart';
import '../../models/return_model.dart';
import '../utils/arabic_search_utils.dart';
import 'seed_data.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('clothing_store_pos.db');
    return _database!;
  }

  Future<void> ensureSchemaMigrations() async {
    final db = await database;
    await _ensureSettingsColumnsExist(db);
    await _ensureLicenseTableExists(db);
    await _ensureProductsQuickItemColumnExists(db);
    await _ensureOrdersDeliveryFeeColumnExists(db);
    await _cleanupOrphanedProducts(db);
  }

  Future<Database> _initDB(String filePath) async {
    // Initialize FFI for Desktop (macOS / Windows / Linux)
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbFolder = await getApplicationDocumentsDirectory();
    final path = join(dbFolder.path, filePath);

    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
    );

    await _ensureSettingsColumnsExist(db);
    await _ensureLicenseTableExists(db);
    await _ensureProductsQuickItemColumnExists(db);
    await _ensureOrdersDeliveryFeeColumnExists(db);
    await _cleanupOrphanedProducts(db);
    return db;
  }

  Future<void> _ensureProductsQuickItemColumnExists(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info(products)');
      final hasCol = info.any((col) => (col['name']?.toString().toLowerCase()) == 'is_quick_item');
      if (!hasCol) {
        await db.execute('ALTER TABLE products ADD COLUMN is_quick_item INTEGER DEFAULT 0');
        debugPrint('[DB Migration] Added is_quick_item column to products table.');
      }
    } catch (e) {
      debugPrint('[DB Migration Warning] checking is_quick_item: $e');
      try {
        await db.execute('ALTER TABLE products ADD COLUMN is_quick_item INTEGER DEFAULT 0');
      } catch (_) {}
    }
  }

  Future<void> _ensureOrdersDeliveryFeeColumnExists(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info(orders)');
      final hasCol = info.any((col) => (col['name']?.toString().toLowerCase()) == 'delivery_fee');
      if (!hasCol) {
        await db.execute('ALTER TABLE orders ADD COLUMN delivery_fee REAL DEFAULT 0.0');
        debugPrint('[DB Migration] Added delivery_fee column to orders table.');
      }
    } catch (e) {
      debugPrint('[DB Migration Warning] checking delivery_fee: $e');
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN delivery_fee REAL DEFAULT 0.0');
      } catch (_) {}
    }
  }

  Future<void> _cleanupOrphanedProducts(Database db) async {
    try {
      await db.execute('''
        DELETE FROM product_variants 
        WHERE product_id IN (
          SELECT id FROM products WHERE category_id NOT IN (SELECT id FROM categories)
        )
      ''');
      await db.execute('''
        DELETE FROM products 
        WHERE category_id NOT IN (SELECT id FROM categories)
      ''');
    } catch (e) {
      debugPrint('Error cleaning up orphaned products: $e');
    }
  }

  Future<void> cleanupOrphanedProducts() async {
    final db = await database;
    await _cleanupOrphanedProducts(db);
  }

  Future<void> _ensureSettingsColumnsExist(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info(store_settings)');
      final hasTheme = info.any((col) => col['name'] == 'theme_mode');
      if (!hasTheme) {
        await db.execute("ALTER TABLE store_settings ADD COLUMN theme_mode TEXT DEFAULT 'dark'");
      }
      final hasLogo = info.any((col) => col['name'] == 'logo_path');
      if (!hasLogo) {
        await db.execute("ALTER TABLE store_settings ADD COLUMN logo_path TEXT");
      }
    } catch (_) {}
  }

  Future<void> _ensureLicenseTableExists(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS system_license (
          id INTEGER PRIMARY KEY,
          first_run_date TEXT NOT NULL,
          activation_key TEXT,
          is_activated INTEGER DEFAULT 0,
          last_checked_date TEXT
        )
      ''');
    } catch (_) {}
  }

  Future<String> getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return join(dbFolder.path, 'clothing_store_pos.db');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS system_license (
        id INTEGER PRIMARY KEY,
        first_run_date TEXT NOT NULL,
        activation_key TEXT,
        is_activated INTEGER DEFAULT 0,
        last_checked_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        pin_code TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE store_settings (
        id INTEGER PRIMARY KEY,
        store_name TEXT NOT NULL,
        slogan TEXT,
        phone TEXT,
        address TEXT,
        currency_symbol TEXT DEFAULT 'ج.م',
        receipt_footer TEXT,
        tax_rate_percent REAL DEFAULT 0.0,
        theme_mode TEXT DEFAULT 'dark',
        logo_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        is_quick_item INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE product_variants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        sku_barcode TEXT NOT NULL UNIQUE,
        size TEXT NOT NULL,
        color TEXT NOT NULL,
        cost_price REAL NOT NULL,
        selling_price REAL NOT NULL,
        stock_quantity INTEGER NOT NULL,
        min_stock_alert INTEGER DEFAULT 2,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cashier_id INTEGER NOT NULL,
        opening_float REAL NOT NULL,
        cash_sales REAL DEFAULT 0.0,
        cash_returns REAL DEFAULT 0.0,
        expected_cash REAL NOT NULL,
        actual_cash REAL DEFAULT 0.0,
        discrepancy REAL DEFAULT 0.0,
        status TEXT DEFAULT 'open',
        start_time TEXT NOT NULL,
        end_time TEXT,
        FOREIGN KEY (cashier_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        cashier_id INTEGER NOT NULL,
        shift_id INTEGER,
        total_amount REAL NOT NULL,
        amount_paid REAL NOT NULL,
        change_due REAL NOT NULL,
        delivery_fee REAL DEFAULT 0.0,
        payment_method TEXT DEFAULT 'cash',
        status TEXT DEFAULT 'completed',
        created_at TEXT NOT NULL,
        FOREIGN KEY (cashier_id) REFERENCES users (id),
        FOREIGN KEY (shift_id) REFERENCES shifts (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        variant_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        size TEXT NOT NULL,
        color TEXT NOT NULL,
        sku_barcode TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        cost_price REAL NOT NULL,
        returned_quantity INTEGER DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (variant_id) REFERENCES product_variants (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        order_item_id INTEGER NOT NULL,
        variant_id INTEGER NOT NULL,
        shift_id INTEGER,
        product_name TEXT NOT NULL,
        size TEXT NOT NULL,
        color TEXT NOT NULL,
        sku_barcode TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        refund_amount REAL NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id),
        FOREIGN KEY (order_item_id) REFERENCES order_items (id),
        FOREIGN KEY (variant_id) REFERENCES product_variants (id),
        FOREIGN KEY (shift_id) REFERENCES shifts (id)
      )
    ''');

    // Create Indexes for ultra fast barcode lookup and queries
    await db.execute('CREATE INDEX idx_variant_barcode ON product_variants (sku_barcode)');
    await db.execute('CREATE INDEX idx_order_invoice ON orders (invoice_number)');

    // Seed Initial Data
    await SeedData.seed(db);
  }

  // ================= USERS & AUTH =================
  Future<UserModel?> getUserByPin(String pin) async {
    final db = await database;
    final res = await db.query('users', where: 'pin_code = ?', whereArgs: [pin]);
    if (res.isNotEmpty) {
      return UserModel.fromMap(res.first);
    }
    return null;
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final res = await db.query('users', orderBy: 'id ASC');
    return res.map((e) => UserModel.fromMap(e)).toList();
  }

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<int> updateUser(UserModel user) async {
    final db = await database;
    return await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // ================= STORE SETTINGS =================
  Future<StoreSettingsModel> getStoreSettings() async {
    final db = await database;
    final res = await db.query('store_settings', where: 'id = 1');
    if (res.isNotEmpty) {
      return StoreSettingsModel.fromMap(res.first);
    }
    return StoreSettingsModel(
      storeName: 'محل الأناقة للملابس',
      slogan: 'أرقى الموديلات',
      phone: '01000000000',
      address: 'وسط البلد',
    );
  }

  Future<int> updateStoreSettings(StoreSettingsModel settings) async {
    final db = await database;
    final map = settings.toMap();
    map['id'] = 1;
    return await db.insert(
      'store_settings',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ================= CATEGORIES =================
  Future<List<CategoryModel>> getAllCategories() async {
    final db = await database;
    final res = await db.query('categories', orderBy: 'name ASC');
    return res.map((e) => CategoryModel.fromMap(e)).toList();
  }

  Future<int> insertCategory(String name) async {
    final db = await database;
    return await db.insert('categories', {'name': name.trim()});
  }

  Future<int> updateCategory(int id, String name) async {
    final db = await database;
    return await db.update(
      'categories',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    try {
      await db.execute('PRAGMA foreign_keys = OFF');
      final res = await db.transaction<int>((txn) async {
        final productRows = await txn.query(
          'products',
          columns: ['id'],
          where: 'category_id = ?',
          whereArgs: [id],
        );
        for (final row in productRows) {
          final prodId = row['id'] as int;
          await txn.delete(
            'product_variants',
            where: 'product_id = ?',
            whereArgs: [prodId],
          );
        }
        await txn.delete(
          'products',
          where: 'category_id = ?',
          whereArgs: [id],
        );
        return await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
      });
      return res;
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<int> getProductCountByCategory(int categoryId) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE category_id = ?',
      [categoryId],
    );
    if (res.isNotEmpty) {
      return (res.first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> getCategoriesWithProductCount() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT c.id, c.name, COUNT(p.id) as product_count
      FROM categories c
      LEFT JOIN products p ON c.id = p.category_id
      GROUP BY c.id, c.name
      ORDER BY c.name ASC
    ''');
  }

  // ================= PRODUCTS & VARIANTS =================
  Future<List<ProductModel>> getProducts({int? categoryId, String? search}) async {
    final db = await database;
    String query = '''
      SELECT p.*, c.name as category_name 
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
    ''';
    List<dynamic> args = [];
    List<String> conditions = [];

    if (categoryId != null && categoryId > 0) {
      conditions.add('p.category_id = ?');
      args.add(categoryId);
    }

    if (conditions.isNotEmpty) {
      query += ' WHERE ${conditions.join(' AND ')}';
    }

    query += ' ORDER BY p.id DESC';

    final productRows = await db.rawQuery(query, args);
    List<ProductModel> products = [];

    for (final row in productRows) {
      final pId = row['id'] as int;
      final variantRows = await db.query(
        'product_variants',
        where: 'product_id = ?',
        whereArgs: [pId],
        orderBy: 'id ASC',
      );
      final variants = variantRows.map((v) => ProductVariantModel.fromMap(v, productName: row['name'] as String?)).toList();

      products.add(ProductModel.fromMap(
        row,
        categoryName: row['category_name'] as String?,
        variants: variants,
      ));
    }

    if (search != null && search.trim().isNotEmpty) {
      return ArabicSearchUtils.filterAndRank(products, search);
    }

    return products;
  }

  Future<Map<String, dynamic>?> findVariantByBarcode(String barcode) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT pv.*, p.name as product_name, p.category_id, c.name as category_name
      FROM product_variants pv
      JOIN products p ON pv.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE pv.sku_barcode = ?
      LIMIT 1
    ''', [barcode.trim()]);

    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  Future<int> insertProduct(ProductModel product, List<ProductVariantModel> variants) async {
    final db = await database;
    return await db.transaction((txn) async {
      final productId = await txn.insert('products', {
        'category_id': product.categoryId,
        'name': product.name,
        'description': product.description,
        'is_quick_item': product.isQuickItem ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final variant in variants) {
        await txn.insert('product_variants', {
          'product_id': productId,
          'sku_barcode': variant.skuBarcode,
          'size': variant.size,
          'color': variant.color,
          'cost_price': variant.costPrice,
          'selling_price': variant.sellingPrice,
          'stock_quantity': variant.stockQuantity,
          'min_stock_alert': variant.minStockAlert,
        });
      }

      return productId;
    });
  }

  Future<void> updateProduct(ProductModel product, List<ProductVariantModel> variants) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'products',
        {
          'category_id': product.categoryId,
          'name': product.name,
          'description': product.description,
          'is_quick_item': product.isQuickItem ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [product.id],
      );

      // Existing variant IDs
      final existingVariants = await txn.query(
        'product_variants',
        where: 'product_id = ?',
        whereArgs: [product.id],
      );
      final existingIds = existingVariants.map((e) => e['id'] as int).toSet();
      final updatedIds = variants.where((v) => v.id != null).map((v) => v.id!).toSet();

      // Delete removed variants
      final toDelete = existingIds.difference(updatedIds);
      for (final id in toDelete) {
        await txn.delete('product_variants', where: 'id = ?', whereArgs: [id]);
      }

      // Upsert variants
      for (final variant in variants) {
        if (variant.id != null && existingIds.contains(variant.id)) {
          await txn.update(
            'product_variants',
            {
              'sku_barcode': variant.skuBarcode,
              'size': variant.size,
              'color': variant.color,
              'cost_price': variant.costPrice,
              'selling_price': variant.sellingPrice,
              'stock_quantity': variant.stockQuantity,
              'min_stock_alert': variant.minStockAlert,
            },
            where: 'id = ?',
            whereArgs: [variant.id],
          );
        } else {
          await txn.insert('product_variants', {
            'product_id': product.id,
            'sku_barcode': variant.skuBarcode,
            'size': variant.size,
            'color': variant.color,
            'cost_price': variant.costPrice,
            'selling_price': variant.sellingPrice,
            'stock_quantity': variant.stockQuantity,
            'min_stock_alert': variant.minStockAlert,
          });
        }
      }
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    try {
      await db.execute('PRAGMA foreign_keys = OFF');
      final res = await db.transaction<int>((txn) async {
        await txn.delete('product_variants', where: 'product_id = ?', whereArgs: [id]);
        return await txn.delete('products', where: 'id = ?', whereArgs: [id]);
      });
      return res;
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<List<ProductVariantModel>> getLowStockVariants() async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT pv.*, p.name as product_name
      FROM product_variants pv
      LEFT JOIN products p ON pv.product_id = p.id
      WHERE pv.stock_quantity <= pv.min_stock_alert
      ORDER BY pv.stock_quantity ASC
    ''');
    return res.map((e) => ProductVariantModel.fromMap(e)).toList();
  }

  // ================= ORDERS & CHECKOUT =================
  Future<OrderModel> createOrderWithItems({
    required int cashierId,
    required int? shiftId,
    required double totalAmount,
    required double amountPaid,
    required double changeDue,
    double deliveryFee = 0.0,
    required List<OrderItemModel> items,
  }) async {
    final db = await database;
    await _ensureOrdersDeliveryFeeColumnExists(db);
    final now = DateTime.now();
    final invoiceNumber = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    return await db.transaction((txn) async {
      // 1. Insert order
      final orderId = await txn.insert('orders', {
        'invoice_number': invoiceNumber,
        'cashier_id': cashierId,
        'shift_id': shiftId,
        'total_amount': totalAmount,
        'amount_paid': amountPaid,
        'change_due': changeDue,
        'delivery_fee': deliveryFee,
        'payment_method': 'cash',
        'status': 'completed',
        'created_at': now.toIso8601String(),
      });

      // 2. Insert order items & decrement stock
      List<OrderItemModel> savedItems = [];
      for (final item in items) {
        final itemId = await txn.insert('order_items', {
          'order_id': orderId,
          'variant_id': item.variantId,
          'product_id': item.productId,
          'product_name': item.productName,
          'size': item.size,
          'color': item.color,
          'sku_barcode': item.skuBarcode,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'cost_price': item.costPrice,
          'returned_quantity': 0,
        });

        // Deduct variant stock
        await txn.rawUpdate('''
          UPDATE product_variants 
          SET stock_quantity = stock_quantity - ? 
          WHERE id = ?
        ''', [item.quantity, item.variantId]);

        savedItems.add(OrderItemModel(
          id: itemId,
          orderId: orderId,
          variantId: item.variantId,
          productId: item.productId,
          productName: item.productName,
          size: item.size,
          color: item.color,
          skuBarcode: item.skuBarcode,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          costPrice: item.costPrice,
        ));
      }

      // 3. Update active shift cash sales
      if (shiftId != null) {
        await txn.rawUpdate('''
          UPDATE shifts 
          SET cash_sales = cash_sales + ?, 
              expected_cash = opening_float + (cash_sales + ?) - cash_returns
          WHERE id = ?
        ''', [totalAmount, totalAmount, shiftId]);
      }

      return OrderModel(
        id: orderId,
        invoiceNumber: invoiceNumber,
        cashierId: cashierId,
        shiftId: shiftId,
        totalAmount: totalAmount,
        amountPaid: amountPaid,
        changeDue: changeDue,
        deliveryFee: deliveryFee,
        status: 'completed',
        createdAt: now,
        items: savedItems,
      );
    });
  }

  Future<OrderModel?> getOrderByInvoiceNumber(String invoiceNumber) async {
    final db = await database;
    final orderRows = await db.rawQuery('''
      SELECT o.*, u.name as cashier_name 
      FROM orders o
      LEFT JOIN users u ON o.cashier_id = u.id
      WHERE o.invoice_number = ?
    ''', [invoiceNumber.trim()]);

    if (orderRows.isEmpty) return null;

    final orderRow = orderRows.first;
    final orderId = orderRow['id'] as int;

    final itemRows = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );

    final items = itemRows.map((e) => OrderItemModel.fromMap(e)).toList();

    return OrderModel.fromMap(
      orderRow,
      cashierName: orderRow['cashier_name'] as String?,
      items: items,
    );
  }

  Future<List<OrderModel>> getAllOrders({int limit = 50}) async {
    final db = await database;
    final orderRows = await db.rawQuery('''
      SELECT o.*, u.name as cashier_name 
      FROM orders o
      LEFT JOIN users u ON o.cashier_id = u.id
      ORDER BY o.id DESC
      LIMIT ?
    ''', [limit]);

    List<OrderModel> orders = [];
    for (final row in orderRows) {
      final orderId = row['id'] as int;
      final itemRows = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      final items = itemRows.map((e) => OrderItemModel.fromMap(e)).toList();
      orders.add(OrderModel.fromMap(row, cashierName: row['cashier_name'] as String?, items: items));
    }
    return orders;
  }

  Future<List<OrderModel>> getOrdersWithFilter({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    String? status,
    int limit = 200,
  }) async {
    final db = await database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClauses.add('o.created_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClauses.add('o.created_at <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      whereClauses.add('(o.invoice_number LIKE ? OR u.name LIKE ?)');
      whereArgs.add(q);
      whereArgs.add(q);
    }

    if (status != null && status != 'all' && status.isNotEmpty) {
      whereClauses.add('o.status = ?');
      whereArgs.add(status);
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT o.*, u.name as cashier_name 
      FROM orders o
      LEFT JOIN users u ON o.cashier_id = u.id
      $whereSql
      ORDER BY o.id DESC
      LIMIT ?
    ''';
    whereArgs.add(limit);

    final orderRows = await db.rawQuery(query, whereArgs);

    List<OrderModel> orders = [];
    for (final row in orderRows) {
      final orderId = row['id'] as int;
      final itemRows = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      final items = itemRows.map((e) => OrderItemModel.fromMap(e)).toList();
      orders.add(OrderModel.fromMap(row, cashierName: row['cashier_name'] as String?, items: items));
    }
    return orders;
  }

  Future<void> updateOrder({
    required int orderId,
    required List<OrderItemModel> items,
    required double totalAmount,
    required double amountPaid,
    required double changeDue,
    double deliveryFee = 0.0,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final currentOrderRows = await txn.query('orders', where: 'id = ?', whereArgs: [orderId]);
      if (currentOrderRows.isEmpty) return;
      final currentOrder = currentOrderRows.first;
      final oldTotal = (currentOrder['total_amount'] as num).toDouble();
      final shiftId = currentOrder['shift_id'] as int?;

      final existingItemRows = await txn.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      final existingItemsMap = {for (var item in existingItemRows) item['id'] as int: item};

      Set<int> updatedItemIds = {};
      for (final item in items) {
        if (item.id != null && existingItemsMap.containsKey(item.id)) {
          updatedItemIds.add(item.id!);
          final oldItem = existingItemsMap[item.id]!;
          final oldQty = oldItem['quantity'] as int;
          final diffQty = item.quantity - oldQty;

          if (diffQty != 0) {
            await txn.rawUpdate('''
              UPDATE product_variants 
              SET stock_quantity = stock_quantity - ? 
              WHERE id = ?
            ''', [diffQty, item.variantId]);
          }

          await txn.update(
            'order_items',
            {
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'cost_price': item.costPrice,
            },
            where: 'id = ?',
            whereArgs: [item.id],
          );
        } else {
          final newItemId = await txn.insert('order_items', {
            'order_id': orderId,
            'variant_id': item.variantId,
            'product_id': item.productId,
            'product_name': item.productName,
            'size': item.size,
            'color': item.color,
            'sku_barcode': item.skuBarcode,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'cost_price': item.costPrice,
            'returned_quantity': 0,
          });
          updatedItemIds.add(newItemId);

          await txn.rawUpdate('''
            UPDATE product_variants 
            SET stock_quantity = stock_quantity - ? 
            WHERE id = ?
          ''', [item.quantity, item.variantId]);
        }
      }

      for (final existingId in existingItemsMap.keys) {
        if (!updatedItemIds.contains(existingId)) {
          final oldItem = existingItemsMap[existingId]!;
          final oldQty = oldItem['quantity'] as int;
          final returnedQty = (oldItem['returned_quantity'] as int?) ?? 0;
          final restorable = oldQty - returnedQty;
          final variantId = oldItem['variant_id'] as int;

          if (restorable > 0) {
            await txn.rawUpdate('''
              UPDATE product_variants 
              SET stock_quantity = stock_quantity + ? 
              WHERE id = ?
            ''', [restorable, variantId]);
          }

          await txn.delete('order_items', where: 'id = ?', whereArgs: [existingId]);
        }
      }

      await txn.update(
        'orders',
        {
          'total_amount': totalAmount,
          'amount_paid': amountPaid,
          'change_due': changeDue,
          'delivery_fee': deliveryFee,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      final totalDiff = totalAmount - oldTotal;
      if (totalDiff != 0 && shiftId != null) {
        await txn.rawUpdate('''
          UPDATE shifts 
          SET cash_sales = cash_sales + ?, 
              expected_cash = opening_float + (cash_sales + ?) - cash_returns
          WHERE id = ?
        ''', [totalDiff, totalDiff, shiftId]);
      }
    });
  }

  Future<void> deleteOrder(int orderId) async {
    final db = await database;
    await db.transaction((txn) async {
      final orderRows = await txn.query('orders', where: 'id = ?', whereArgs: [orderId]);
      if (orderRows.isEmpty) return;
      final order = orderRows.first;
      final totalAmount = (order['total_amount'] as num).toDouble();
      final shiftId = order['shift_id'] as int?;

      final items = await txn.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      for (final item in items) {
        final variantId = item['variant_id'] as int;
        final qty = item['quantity'] as int;
        final retQty = (item['returned_quantity'] as int?) ?? 0;
        final restorable = qty - retQty;
        if (restorable > 0) {
          await txn.rawUpdate('''
            UPDATE product_variants 
            SET stock_quantity = stock_quantity + ? 
            WHERE id = ?
          ''', [restorable, variantId]);
        }
      }

      if (shiftId != null) {
        await txn.rawUpdate('''
          UPDATE shifts 
          SET cash_sales = cash_sales - ?, 
              expected_cash = opening_float + (cash_sales - ?) - cash_returns
          WHERE id = ?
        ''', [totalAmount, totalAmount, shiftId]);
      }

      await txn.delete('returns', where: 'order_id = ?', whereArgs: [orderId]);
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      await txn.delete('orders', where: 'id = ?', whereArgs: [orderId]);
    });
  }

  // ================= RETURNS & RESTOCKING =================
  Future<void> processReturn({
    required int orderId,
    required int orderItemId,
    required int variantId,
    required int? shiftId,
    required String productName,
    required String size,
    required String color,
    required String skuBarcode,
    required int returnQty,
    required double refundAmount,
    required String reason,
  }) async {
    final db = await database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      // 1. Insert return record
      await txn.insert('returns', {
        'order_id': orderId,
        'order_item_id': orderItemId,
        'variant_id': variantId,
        'shift_id': shiftId,
        'product_name': productName,
        'size': size,
        'color': color,
        'sku_barcode': skuBarcode,
        'quantity': returnQty,
        'refund_amount': refundAmount,
        'reason': reason,
        'created_at': now.toIso8601String(),
      });

      // 2. Restock variant (+1 or +returnQty)
      await txn.rawUpdate('''
        UPDATE product_variants 
        SET stock_quantity = stock_quantity + ? 
        WHERE id = ?
      ''', [returnQty, variantId]);

      // 3. Update order item returned_quantity
      await txn.rawUpdate('''
        UPDATE order_items 
        SET returned_quantity = returned_quantity + ? 
        WHERE id = ?
      ''', [returnQty, orderItemId]);

      // 4. Deduct cash from active shift
      if (shiftId != null) {
        await txn.rawUpdate('''
          UPDATE shifts 
          SET cash_returns = cash_returns + ?, 
              expected_cash = opening_float + cash_sales - (cash_returns + ?)
          WHERE id = ?
        ''', [refundAmount, refundAmount, shiftId]);
      }

      // 5. Check if all items in order are returned
      final items = await txn.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      bool allReturned = true;
      for (final item in items) {
        final q = item['quantity'] as int;
        final rq = item['returned_quantity'] as int;
        if (rq < q) {
          allReturned = false;
          break;
        }
      }

      await txn.update(
        'orders',
        {'status': allReturned ? 'refunded' : 'partially_refunded'},
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });
  }

  Future<List<ReturnModel>> getAllReturns({int limit = 50}) async {
    final db = await database;
    final res = await db.query('returns', orderBy: 'id DESC', limit: limit);
    return res.map((e) => ReturnModel.fromMap(e)).toList();
  }

  // ================= SHIFTS & CASH DRAWER =================
  Future<ShiftModel?> getActiveShift(int cashierId) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT s.*, u.name as cashier_name 
      FROM shifts s
      JOIN users u ON s.cashier_id = u.id
      WHERE s.cashier_id = ? AND s.status = 'open'
      ORDER BY s.id DESC
      LIMIT 1
    ''', [cashierId]);

    if (res.isNotEmpty) {
      return ShiftModel.fromMap(res.first, cashierName: res.first['cashier_name'] as String?);
    }
    return null;
  }

  Future<int> openShift(int cashierId, double openingFloat) async {
    final db = await database;
    final now = DateTime.now();
    return await db.insert('shifts', {
      'cashier_id': cashierId,
      'opening_float': openingFloat,
      'cash_sales': 0.0,
      'cash_returns': 0.0,
      'expected_cash': openingFloat,
      'actual_cash': 0.0,
      'discrepancy': 0.0,
      'status': 'open',
      'start_time': now.toIso8601String(),
    });
  }

  Future<void> closeShift(int shiftId, double actualCash) async {
    final db = await database;
    final now = DateTime.now();
    final shiftRows = await db.query('shifts', where: 'id = ?', whereArgs: [shiftId]);
    if (shiftRows.isEmpty) return;

    final shift = ShiftModel.fromMap(shiftRows.first);
    final expected = shift.openingFloat + shift.cashSales - shift.cashReturns;
    final discrepancy = actualCash - expected;

    await db.update(
      'shifts',
      {
        'actual_cash': actualCash,
        'expected_cash': expected,
        'discrepancy': discrepancy,
        'status': 'closed',
        'end_time': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }

  Future<List<ShiftModel>> getShiftsHistory({int limit = 30}) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT s.*, u.name as cashier_name 
      FROM shifts s
      JOIN users u ON s.cashier_id = u.id
      ORDER BY s.id DESC
      LIMIT ?
    ''', [limit]);

    return res.map((e) => ShiftModel.fromMap(e, cashierName: e['cashier_name'] as String?)).toList();
  }

  // ================= FINANCIAL & INVENTORY REPORTS =================
  Future<Map<String, dynamic>> getFinancialStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    String orderWhere = '';
    List<dynamic> orderArgs = [];
    if (startDate != null && endDate != null) {
      orderWhere = 'WHERE created_at >= ? AND created_at <= ?';
      orderArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    } else if (startDate != null) {
      orderWhere = 'WHERE created_at >= ?';
      orderArgs = [startDate.toIso8601String()];
    } else if (endDate != null) {
      orderWhere = 'WHERE created_at <= ?';
      orderArgs = [endDate.toIso8601String()];
    }

    String returnWhere = '';
    List<dynamic> returnArgs = [];
    if (startDate != null && endDate != null) {
      returnWhere = 'WHERE created_at >= ? AND created_at <= ?';
      returnArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    } else if (startDate != null) {
      returnWhere = 'WHERE created_at >= ?';
      returnArgs = [startDate.toIso8601String()];
    } else if (endDate != null) {
      returnWhere = 'WHERE created_at <= ?';
      returnArgs = [endDate.toIso8601String()];
    }

    String itemsWhere = '';
    List<dynamic> itemsArgs = [];
    if (startDate != null && endDate != null) {
      itemsWhere = 'WHERE o.created_at >= ? AND o.created_at <= ?';
      itemsArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    } else if (startDate != null) {
      itemsWhere = 'WHERE o.created_at >= ?';
      itemsArgs = [startDate.toIso8601String()];
    } else if (endDate != null) {
      itemsWhere = 'WHERE o.created_at <= ?';
      itemsArgs = [endDate.toIso8601String()];
    }

    // Total Sales & Orders
    final salesRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_amount), 0.0) as total_sales,
        COUNT(id) as total_orders
      FROM orders
      $orderWhere
    ''', orderArgs);

    // Payment Methods Breakdown (Cash / Card)
    final methodsRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN total_amount ELSE 0 END), 0.0) as cash_sales,
        COALESCE(SUM(CASE WHEN payment_method != 'cash' THEN total_amount ELSE 0 END), 0.0) as card_sales
      FROM orders
      $orderWhere
    ''', orderArgs);

    // Total Returns
    final returnsRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(refund_amount), 0.0) as total_returns,
        COUNT(id) as return_count
      FROM returns
      $returnWhere
    ''', returnArgs);

    // Net Profit & COGS Calculation = (Total Sold Items Revenue - Total Sold Items Cost)
    final profitRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM((oi.unit_price - oi.cost_price) * (oi.quantity - oi.returned_quantity)), 0.0) as net_profit,
        COALESCE(SUM(oi.cost_price * (oi.quantity - oi.returned_quantity)), 0.0) as total_cogs
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      $itemsWhere
    ''', itemsArgs);

    final totalSales = (salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = (salesRes.first['total_orders'] as int?) ?? 0;
    final cashSales = (methodsRes.first['cash_sales'] as num?)?.toDouble() ?? 0.0;
    final cardSales = (methodsRes.first['card_sales'] as num?)?.toDouble() ?? 0.0;
    final totalReturns = (returnsRes.first['total_returns'] as num?)?.toDouble() ?? 0.0;
    final returnCount = (returnsRes.first['return_count'] as int?) ?? 0;
    final netProfit = (profitRes.first['net_profit'] as num?)?.toDouble() ?? 0.0;
    final totalCogs = (profitRes.first['total_cogs'] as num?)?.toDouble() ?? 0.0;

    return {
      'total_sales': totalSales,
      'total_orders': totalOrders,
      'cash_sales': cashSales,
      'card_sales': cardSales,
      'total_returns': totalReturns,
      'return_count': returnCount,
      'net_profit': netProfit,
      'total_cogs': totalCogs,
    };
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 10,
  }) async {
    final db = await database;
    String itemsWhere = '';
    List<dynamic> args = [];
    if (startDate != null && endDate != null) {
      itemsWhere = 'WHERE o.created_at >= ? AND o.created_at <= ?';
      args = [startDate.toIso8601String(), endDate.toIso8601String(), limit];
    } else if (startDate != null) {
      itemsWhere = 'WHERE o.created_at >= ?';
      args = [startDate.toIso8601String(), limit];
    } else if (endDate != null) {
      itemsWhere = 'WHERE o.created_at <= ?';
      args = [endDate.toIso8601String(), limit];
    } else {
      args = [limit];
    }

    final res = await db.rawQuery('''
      SELECT 
        oi.product_name,
        oi.size,
        oi.color,
        oi.sku_barcode,
        SUM(oi.quantity - oi.returned_quantity) as total_sold_qty,
        SUM((oi.unit_price) * (oi.quantity - oi.returned_quantity)) as total_revenue
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      $itemsWhere
      GROUP BY oi.variant_id
      HAVING total_sold_qty > 0
      ORDER BY total_sold_qty DESC
      LIMIT ?
    ''', args);

    return res;
  }

  Future<List<Map<String, dynamic>>> getCategorySalesStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String itemsWhere = '';
    List<dynamic> args = [];
    if (startDate != null && endDate != null) {
      itemsWhere = 'WHERE o.created_at >= ? AND o.created_at <= ?';
      args = [startDate.toIso8601String(), endDate.toIso8601String()];
    } else if (startDate != null) {
      itemsWhere = 'WHERE o.created_at >= ?';
      args = [startDate.toIso8601String()];
    } else if (endDate != null) {
      itemsWhere = 'WHERE o.created_at <= ?';
      args = [endDate.toIso8601String()];
    }

    final res = await db.rawQuery('''
      SELECT 
        COALESCE(c.name, 'عام') as category_name,
        SUM(oi.quantity - oi.returned_quantity) as total_sold_qty,
        SUM((oi.unit_price) * (oi.quantity - oi.returned_quantity)) as total_revenue
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      JOIN products p ON oi.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      $itemsWhere
      GROUP BY p.category_id
      HAVING total_sold_qty > 0
      ORDER BY total_revenue DESC
    ''', args);

    return res;
  }

  // ================= LICENSE METHODS =================

  Future<Map<String, dynamic>?> getLicenseRecord() async {
    final db = await database;
    final res = await db.query('system_license', where: 'id = 1', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> initLicenseRecord(String firstRunDate) async {
    final db = await database;
    await db.insert('system_license', {
      'id': 1,
      'first_run_date': firstRunDate,
      'activation_key': null,
      'is_activated': 0,
      'last_checked_date': firstRunDate,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> updateLicenseActivation(String activationKey, int isActivated) async {
    final db = await database;
    await db.update(
      'system_license',
      {
        'activation_key': activationKey,
        'is_activated': isActivated,
        'last_checked_date': DateTime.now().toIso8601String(),
      },
      where: 'id = 1',
    );
  }

  Future<void> updateLastCheckedDate(String lastCheckedDate) async {
    final db = await database;
    await db.update(
      'system_license',
      {'last_checked_date': lastCheckedDate},
      where: 'id = 1',
    );
  }

  Future<int> getTotalOrdersCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM orders');
    if (res.isNotEmpty && res.first['count'] != null) {
      return (res.first['count'] as num).toInt();
    }
    return 0;
  }
}
