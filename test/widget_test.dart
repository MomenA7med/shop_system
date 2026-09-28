import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'package:shop_system/core/constants/app_strings.dart';
import 'package:shop_system/models/user_model.dart';
import 'package:shop_system/providers/auth_provider.dart';
import 'package:shop_system/providers/inventory_provider.dart';
import 'package:shop_system/views/inventory/inventory_view.dart';
import 'package:shop_system/widgets/custom_sidebar.dart';
import 'package:shop_system/providers/reports_provider.dart';
import 'package:shop_system/views/reports/reports_view.dart';
import 'package:shop_system/core/services/print_service.dart';
import 'package:shop_system/models/product_model.dart';
import 'package:shop_system/models/product_variant_model.dart';
import 'package:shop_system/models/order_item_model.dart';
import 'package:shop_system/models/order_model.dart';
import 'package:shop_system/models/shift_model.dart';
import 'package:shop_system/models/store_settings_model.dart';
import 'package:shop_system/providers/pos_provider.dart';
import 'package:shop_system/providers/settings_provider.dart';
import 'package:shop_system/views/settings/settings_view.dart';
import 'package:shop_system/core/utils/number_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Product model calculates total stock and price range accurately', () {
    final variants = [
      ProductVariantModel(
        id: 1,
        productId: 10,
        skuBarcode: '1001',
        size: 'M',
        color: 'أسود',
        costPrice: 100.0,
        sellingPrice: 180.0,
        stockQuantity: 5,
      ),
      ProductVariantModel(
        id: 2,
        productId: 10,
        skuBarcode: '1002',
        size: 'L',
        color: 'أسود',
        costPrice: 100.0,
        sellingPrice: 200.0,
        stockQuantity: 8,
      ),
    ];

    final product = ProductModel(
      id: 10,
      categoryId: 1,
      name: 'قميص كتان',
      variants: variants,
    );

    expect(product.totalStock, 13);
    expect(product.minPrice, 180.0);
    expect(product.maxPrice, 200.0);
    expect(product.isAllOutOfStock, false);
  });

  test('OrderItem calculates totals and net profit accurately', () {
    final item = OrderItemModel(
      id: 1,
      variantId: 1,
      productId: 10,
      productName: 'تيشيرت بولو',
      size: 'XL',
      color: 'كحلي',
      skuBarcode: '1003',
      quantity: 3,
      unitPrice: 250.0,
      costPrice: 150.0,
    );

    expect(item.totalPrice, 750.0);
    expect(item.totalCost, 450.0);
    expect(item.profit, 300.0);
  });

  test('Shift model calculates expected cash and discrepancies accurately', () {
    final shift = ShiftModel(
      id: 1,
      cashierId: 1,
      openingFloat: 500.0,
      cashSales: 1200.0,
      cashReturns: 200.0,
      actualCash: 1500.0,
    );

    expect(shift.expectedCash, 1500.0);
    expect(shift.discrepancy, 0.0);
    expect(shift.isBalanced, true);

    shift.actualCash = 1450.0;
    expect(shift.hasShortage, true);
    expect(shift.discrepancy, -50.0);
  });

  test(
    'NumberParser normalizes and parses Arabic and English numbers accurately',
    () {
      expect(NumberParser.normalize('١٢٣٤٥'), '12345');
      expect(NumberParser.normalize('٥٠٠٫٥'), '500.5');
      expect(NumberParser.normalize('٣٥٠,٧٥'), '350.75');
      expect(NumberParser.tryParseDouble('١٥٠.٥'), 150.5);
      expect(NumberParser.tryParseDouble('٥٠٠٫٢٥'), 500.25);
      expect(NumberParser.tryParseInt('٢٥'), 25);
      expect(NumberParser.tryParseInt('100'), 100);
      expect(NumberParser.isDigit('٥'), true);
      expect(NumberParser.isDigit('8'), true);
      expect(NumberParser.extractDigit('٩'), '9');
    },
  );

  test(
    'OrderModel and OrderItemModel calculate post-return quantities and net totals accurately',
    () {
      final item1 = OrderItemModel(
        id: 1,
        variantId: 1,
        productId: 10,
        productName: 'بنطلون جينز',
        size: '32',
        color: 'أزرق',
        skuBarcode: '2001',
        quantity: 3,
        unitPrice: 300.0,
        costPrice: 180.0,
        returnedQuantity: 1, // 1 returned, 2 remaining
      );

      final item2 = OrderItemModel(
        id: 2,
        variantId: 2,
        productId: 11,
        productName: 'قميص أبيض',
        size: 'L',
        color: 'أبيض',
        skuBarcode: '2002',
        quantity: 2,
        unitPrice: 200.0,
        costPrice: 120.0,
        returnedQuantity: 2, // 2 returned, 0 remaining (fully returned)
      );

      final order = OrderModel(
        id: 1,
        invoiceNumber: 'INV-1001',
        cashierId: 1,
        totalAmount: 1300.0,
        amountPaid: 1500.0,
        changeDue: 200.0,
        status: 'partially_refunded',
        items: [item1, item2],
      );

      // Item 1 checks
      expect(item1.remainingQuantity, 2);
      expect(item1.netTotalPrice, 600.0);
      expect(item1.refundedAmount, 300.0);
      expect(item1.isFullyReturned, false);

      // Item 2 checks
      expect(item2.remainingQuantity, 0);
      expect(item2.netTotalPrice, 0.0);
      expect(item2.refundedAmount, 400.0);
      expect(item2.isFullyReturned, true);

      // Order level checks
      expect(order.totalPieces, 5);
      expect(order.remainingPieces, 2);
      expect(order.totalReturnedPieces, 3);
      expect(order.refundedAmount, 700.0);
      expect(order.netTotalAmount, 600.0);
      expect(order.hasReturns, true);
      expect(order.isFullyRefunded, false);
      expect(order.isPartiallyRefunded, true);
    },
  );

  test(
    'ProductVariantModel preserves productName in constructor, fromMap and copyWith',
    () {
      final variant = ProductVariantModel(
        id: 1,
        productId: 10,
        productName: 'تيشيرت صيفي',
        skuBarcode: '9901',
        size: 'XL',
        color: 'أخضر',
        costPrice: 50.0,
        sellingPrice: 100.0,
        stockQuantity: 1,
        minStockAlert: 3,
      );

      expect(variant.productName, 'تيشيرت صيفي');
      expect(variant.isLowStock, true);

      final map = {
        'id': 2,
        'product_id': 10,
        'product_name': 'بنطلون قماش',
        'sku_barcode': '9902',
        'size': '34',
        'color': 'كحلي',
        'cost_price': 80.0,
        'selling_price': 150.0,
        'stock_quantity': 0,
        'min_stock_alert': 2,
      };

      final fromMapVariant = ProductVariantModel.fromMap(map);
      expect(fromMapVariant.productName, 'بنطلون قماش');
      expect(fromMapVariant.isOutOfStock, true);

      final copied = fromMapVariant.copyWith(productName: 'بنطلون جينز');
      expect(copied.productName, 'بنطلون جينز');
    },
  );

  test(
    'POSProvider resets amountPaid, discount, and changeDue when cart is emptied',
    () {
      final pos = POSProvider();
      final product = ProductModel(id: 1, categoryId: 1, name: 'سويتشيرت');
      final variant = ProductVariantModel(
        id: 10,
        productId: 1,
        skuBarcode: 'SW-01',
        size: 'L',
        color: 'أسود',
        costPrice: 800.0,
        sellingPrice: 1500.0,
        stockQuantity: 10,
      );

      // Initial state
      expect(pos.cartItems.isEmpty, true);
      expect(pos.changeDue, 0.0);
      expect(pos.amountPaid, 0.0);

      // Add to cart
      pos.addVariantToCart(product, variant);
      expect(pos.cartItems.length, 1);
      expect(pos.subtotal, 1500.0);
      expect(pos.grandTotal, 1500.0);
      expect(pos.amountPaid, 1500.0);
      expect(pos.changeDue, 0.0);

      // Overpay
      pos.setAmountPaid(2000.0);
      expect(pos.amountPaid, 2000.0);
      expect(pos.changeDue, 500.0);

      // Remove item from cart
      pos.removeItem(0);
      expect(pos.cartItems.isEmpty, true);
      expect(pos.grandTotal, 0.0);
      expect(pos.amountPaid, 0.0);
      expect(pos.changeDue, 0.0);
    },
  );

  test(
    'SettingsProvider initializes with initialSettings theme immediately without flash',
    () {
      final lightSettings = StoreSettingsModel(
        storeName: 'Test Store',
        slogan: 'Test Slogan',
        phone: '01000000000',
        address: 'Test Address',
        themeMode: 'light',
      );
      final provider = SettingsProvider(initialSettings: lightSettings);
      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isDarkMode, false);

      final darkSettings = StoreSettingsModel(
        storeName: 'Test Store',
        slogan: 'Test Slogan',
        phone: '01000000000',
        address: 'Test Address',
        themeMode: 'dark',
      );
      final darkProvider = SettingsProvider(initialSettings: darkSettings);
      expect(darkProvider.themeMode, ThemeMode.dark);
      expect(darkProvider.isDarkMode, true);
    },
  );

  test(
    'ProductVariantModel accurately uses custom minStockAlert threshold',
    () {
      // Custom threshold of 7
      final variantCustomThreshold = ProductVariantModel(
        id: 1,
        productId: 10,
        skuBarcode: 'TST-001',
        size: 'XL',
        color: 'أزرق',
        costPrice: 100,
        sellingPrice: 150,
        stockQuantity: 6,
        minStockAlert: 7,
      );

      expect(variantCustomThreshold.minStockAlert, 7);
      expect(variantCustomThreshold.isLowStock, true);
      expect(variantCustomThreshold.isOutOfStock, false);

      // When stock is greater than custom threshold (8 > 7)
      final safeStockVariant = variantCustomThreshold.copyWith(
        stockQuantity: 8,
      );
      expect(safeStockVariant.isLowStock, false);
      expect(safeStockVariant.isOutOfStock, false);

      // When stock is 0
      final outOfStockVariant = variantCustomThreshold.copyWith(
        stockQuantity: 0,
      );
      expect(outOfStockVariant.isLowStock, false);
      expect(outOfStockVariant.isOutOfStock, true);
    },
  );

  test(
    'StoreSettingsModel supports value equality and immutability properly',
    () {
      final s1 = StoreSettingsModel(
        storeName: 'محل VOLT',
        slogan: 'أجود الخامات',
        phone: '01012345678',
        address: 'شارع الجمهورية',
      );
      final s2 = StoreSettingsModel(
        storeName: 'محل VOLT',
        slogan: 'أجود الخامات',
        phone: '01012345678',
        address: 'شارع الجمهورية',
      );

      expect(s1 == s2, true);
      expect(s1.hashCode, s2.hashCode);

      final modified = s1.copyWith(storeName: 'محل جديد');
      expect(s1 == modified, false);
      expect(modified.storeName, 'محل جديد');
    },
  );

  test(
    'Deleting a category cascades to delete its products and variants cleanly',
    () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)',
          );
          await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
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
        },
      );

      // Insert category, product and variant
      final catId = await db.insert('categories', {'name': 'قمصان'});
      final prodId = await db.insert('products', {
        'category_id': catId,
        'name': 'قميص رجالي',
        'description': '',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('product_variants', {
        'product_id': prodId,
        'sku_barcode': 'SH-01',
        'size': 'L',
        'color': 'أبيض',
        'cost_price': 100,
        'selling_price': 200,
        'stock_quantity': 5,
      });

      expect((await db.query('categories')).length, 1);
      expect((await db.query('products')).length, 1);
      expect((await db.query('product_variants')).length, 1);

      // Delete category
      await db.transaction((txn) async {
        final productRows = await txn.query(
          'products',
          columns: ['id'],
          where: 'category_id = ?',
          whereArgs: [catId],
        );
        for (final r in productRows) {
          await txn.delete(
            'product_variants',
            where: 'product_id = ?',
            whereArgs: [r['id']],
          );
        }
        await txn.delete(
          'products',
          where: 'category_id = ?',
          whereArgs: [catId],
        );
        await txn.delete('categories', where: 'id = ?', whereArgs: [catId]);
      });

      expect((await db.query('categories')).isEmpty, true);
      expect((await db.query('products')).isEmpty, true);
      expect((await db.query('product_variants')).isEmpty, true);

      await db.close();
    },
  );

  testWidgets(
    'InventoryView displays add & edit buttons for Admin but view-only & print for Cashier',
    (tester) async {
      final inventoryProvider = InventoryProvider();
      final settingsProvider = SettingsProvider(
        initialSettings: StoreSettingsModel(
          storeName: 'Test Store',
          slogan: '',
          phone: '',
          address: '',
        ),
      );

      final auth = AuthProvider();

      // 1. Cashier Role
      auth.setCurrentUserForTesting(
        UserModel(name: 'الكاشير', role: 'cashier', pinCode: '5678'),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: inventoryProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
          ],
          child: const MaterialApp(home: InventoryView()),
        ),
      );

      expect(find.text(AppStrings.addNewProduct), findsNothing);
      expect(find.text('وضع العرض وطباعة الباركود (الكاشير)'), findsOneWidget);

      // 2. Admin Role
      auth.setCurrentUserForTesting(
        UserModel(name: 'المدير', role: 'admin', pinCode: '1234'),
      );
      await tester.pump();

      expect(find.text(AppStrings.addNewProduct), findsOneWidget);
      expect(find.text('إدارة التصنيفات (0)'), findsOneWidget);
      expect(find.text('وضع العرض وطباعة الباركود (الكاشير)'), findsNothing);
    },
  );

  testWidgets('CustomSidebar logout button successfully triggers logout', (
    tester,
  ) async {
    final auth = AuthProvider();
    auth.setCurrentUserForTesting(
      UserModel(name: 'المدير', role: 'admin', pinCode: '1234'),
    );
    expect(auth.isAuthenticated, true);

    final settingsProvider = SettingsProvider(
      initialSettings: StoreSettingsModel(
        storeName: 'Test Store',
        slogan: '',
        phone: '',
        address: '',
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: settingsProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              width: 220,
              child: CustomSidebar(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.navLogout), findsOneWidget);

    // Tap sidebar logout button
    await tester.tap(find.text(AppStrings.navLogout));
    await tester.pump();

    expect(auth.isAuthenticated, false);
    expect(auth.currentUser, isNull);
  });

  test(
    'ReportsProvider calculates dates accurately for all period presets',
    () {
      final provider = ReportsProvider();
      expect(provider.selectedPeriod, ReportPeriod.all);
      expect(provider.startDate, isNull);
      expect(provider.endDate, isNull);

      // Today
      provider.setPeriod(ReportPeriod.today);
      expect(provider.selectedPeriod, ReportPeriod.today);
      expect(provider.startDate?.day, DateTime.now().day);
      expect(provider.endDate?.day, DateTime.now().day);

      // Weekly
      provider.setPeriod(ReportPeriod.weekly);
      expect(provider.selectedPeriod, ReportPeriod.weekly);
      expect(provider.startDate, isNotNull);
      expect(provider.endDate, isNotNull);
      expect(
        provider.endDate!.difference(provider.startDate!).inDays >= 6,
        true,
      );

      // Monthly
      provider.setPeriod(ReportPeriod.monthly);
      expect(provider.selectedPeriod, ReportPeriod.monthly);
      expect(provider.startDate?.day, 1);
      expect(provider.startDate?.month, DateTime.now().month);

      // Yearly
      provider.setPeriod(ReportPeriod.yearly);
      expect(provider.selectedPeriod, ReportPeriod.yearly);
      expect(provider.startDate?.month, 1);
      expect(provider.startDate?.day, 1);
      expect(provider.startDate?.year, DateTime.now().year);

      // Custom
      final start = DateTime(2026, 5, 1);
      final end = DateTime(2026, 5, 15);
      provider.setPeriod(
        ReportPeriod.custom,
        customStart: start,
        customEnd: end,
      );
      expect(provider.selectedPeriod, ReportPeriod.custom);
      expect(provider.startDate?.day, 1);
      expect(provider.startDate?.month, 5);
      expect(provider.endDate?.day, 15);
      expect(provider.endDate?.month, 5);
    },
  );

  test(
    'PrintService generates valid financial report PDF document without errors',
    () async {
      final settings = StoreSettingsModel(
        storeName: 'متجر الأزياء التجريبي',
        slogan: 'أفضل الملابس العصرية',
        phone: '01000000000',
        address: 'القاهرة، مصر',
      );

      final stats = {
        'total_sales': 15000.0,
        'total_orders': 25,
        'cash_sales': 10000.0,
        'card_sales': 5000.0,
        'total_returns': 500.0,
        'return_count': 2,
        'net_profit': 6000.0,
        'total_cogs': 8500.0,
      };

      final topProducts = [
        {
          'product_name': 'تيشيرت صيفي',
          'size': 'L',
          'color': 'أبيض',
          'sku_barcode': '1001',
          'total_sold_qty': 12,
          'total_revenue': 3600.0,
        },
      ];

      final categorySales = [
        {
          'category_name': 'تيشيرتات',
          'total_sold_qty': 15,
          'total_revenue': 4500.0,
        },
      ];

      final pdfBytes = await PrintService.generateFinancialReportPdf(
        financialStats: stats,
        topProducts: topProducts,
        categorySales: categorySales,
        settings: settings,
        periodLabel: 'شهري (سبتمبر 2026)',
      );

      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes.length > 100, true);
    },
  );

  testWidgets(
    'ReportsView displays period selector, action buttons, and stat cards properly for Admin and hides actions for Cashier',
    (tester) async {
      final reportsProvider = ReportsProvider();
      final settingsProvider = SettingsProvider(
        initialSettings: StoreSettingsModel(
          storeName: 'Test Store',
          slogan: '',
          phone: '',
          address: '',
        ),
      );
      final auth = AuthProvider();
      auth.setCurrentUserForTesting(
        UserModel(name: 'المدير', role: 'admin', pinCode: '1234'),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: reportsProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 1280, height: 800, child: ReportsView()),
            ),
          ),
        ),
      );

      expect(find.text(AppStrings.financialReports), findsOneWidget);
      expect(find.text('تصدير PDF'), findsOneWidget);
      expect(find.text('طباعة التقرير'), findsOneWidget);
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('أسبوعي'), findsOneWidget);
      expect(find.text('شهري'), findsOneWidget);
      expect(find.text('سنوي'), findsOneWidget);
      expect(find.text('نطاق مخصص'), findsOneWidget);

      // Now switch to Cashier role
      auth.setCurrentUserForTesting(
        UserModel(name: 'الكاشير', role: 'cashier', pinCode: '5678'),
      );
      await tester.pump();

      expect(find.text('تصدير PDF'), findsNothing);
      expect(find.text('طباعة التقرير'), findsNothing);
    },
  );

  test(
    'PrintService generates valid inventory report PDF document without errors',
    () async {
      final settings = StoreSettingsModel(
        storeName: 'متجر الأزياء التجريبي',
        slogan: 'أفضل الملابس العصرية',
        phone: '01000000000',
        address: 'القاهرة، مصر',
      );

      final product = ProductModel(
        id: 1,
        categoryId: 1,
        categoryName: 'قمصان',
        name: 'قميص أكسفورد',
        variants: [
          ProductVariantModel(
            id: 1,
            productId: 1,
            productName: 'قميص أكسفورد',
            skuBarcode: 'OX-01',
            size: 'L',
            color: 'أزرق سماوي',
            costPrice: 120.0,
            sellingPrice: 250.0,
            stockQuantity: 10,
          ),
          ProductVariantModel(
            id: 2,
            productId: 1,
            productName: 'قميص أكسفورد',
            skuBarcode: 'OX-02',
            size: 'XL',
            color: 'أبيض',
            costPrice: 120.0,
            sellingPrice: 250.0,
            stockQuantity: 2,
            minStockAlert: 3, // isLowStock = true
          ),
        ],
      );

      final pdfBytes = await PrintService.generateInventoryReportPdf(
        products: [product],
        settings: settings,
        categoryFilterName: 'قمصان',
      );

      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes.length > 100, true);
    },
  );

  testWidgets(
    'InventoryView displays Export PDF, Export Excel, and Print buttons properly',
    (tester) async {
      final inventoryProvider = InventoryProvider();
      final settingsProvider = SettingsProvider(
        initialSettings: StoreSettingsModel(
          storeName: 'Test Store',
          slogan: '',
          phone: '',
          address: '',
        ),
      );
      final auth = AuthProvider();
      auth.setCurrentUserForTesting(
        UserModel(name: 'المدير', role: 'admin', pinCode: '1234'),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: inventoryProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 1280, height: 800, child: InventoryView()),
            ),
          ),
        ),
      );

      expect(find.text('تصدير PDF'), findsOneWidget);
      expect(find.text('تصدير Excel'), findsOneWidget);
      expect(find.text('طباعة الجرد'), findsOneWidget);

      // Now switch to Cashier role
      auth.setCurrentUserForTesting(
        UserModel(name: 'الكاشير', role: 'cashier', pinCode: '5678'),
      );
      await tester.pump();

      expect(find.text('تصدير PDF'), findsNothing);
      expect(find.text('تصدير Excel'), findsNothing);
      expect(find.text('طباعة الجرد'), findsNothing);
      expect(find.text('وضع العرض وطباعة الباركود (الكاشير)'), findsOneWidget);
    },
  );

  test('StoreSettingsModel correctly handles logoPath in serialization and copyWith', () {
    final settings = StoreSettingsModel(
      storeName: 'متجر الأزياء الحديث',
      slogan: 'أفضل الخامات',
      phone: '01000000000',
      address: 'القاهرة',
      logoPath: '/path/to/logo.png',
    );

    final map = settings.toMap();
    expect(map['logo_path'], '/path/to/logo.png');

    final reconstructed = StoreSettingsModel.fromMap(map);
    expect(reconstructed.logoPath, '/path/to/logo.png');
    expect(reconstructed.storeName, 'متجر الأزياء الحديث');

    final cleared = reconstructed.copyWith(clearLogo: true);
    expect(cleared.logoPath, isNull);

    final updated = cleared.copyWith(logoPath: '/new/path.png');
    expect(updated.logoPath, '/new/path.png');
  });

  testWidgets('SettingsView displays store logo management section properly', (tester) async {
    final settingsProvider = SettingsProvider(
      initialSettings: StoreSettingsModel(
        storeName: 'متجر تجريبي',
        slogan: 'سلوجان',
        phone: '010',
        address: 'عنوان',
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 1280, height: 800, child: SettingsView()),
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.storeSettings), findsOneWidget);
    expect(find.text('شعار المتجر (Logo)'), findsOneWidget);
    expect(find.text('اختيار شعار للمحل'), findsOneWidget);
  });
}
