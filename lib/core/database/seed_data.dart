import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SeedData {
  static Future<void> seed(Database db) async {
    // 1. Check if already seeded
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM users');
    final usersCount = (result.first['count'] as num?)?.toInt() ?? 0;

    if (usersCount > 0) return;

    // 2. Default Users (Admin: PIN 1234, Cashier: PIN 0000)
    await db.insert('users', {
      'name': 'مدير النظام (أحمد)',
      'role': 'admin',
      'pin_code': '1234',
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('users', {
      'name': 'كاشير 1 (سارة)',
      'role': 'cashier',
      'pin_code': '0000',
      'created_at': DateTime.now().toIso8601String(),
    });

    // 3. Store Settings
    await db.insert('store_settings', {
      'id': 1,
      'store_name': 'محل الأناقة للأزياء والملابس',
      'slogan': 'أجود الخامات وأحدث صيحات الموضة',
      'phone': '01012345678',
      'address': 'شارع الجمهورية - أمام مول المدينة',
      'currency_symbol': 'ج.م',
      'receipt_footer':
          'شكراً لتعاملكم معنا! البضاعة المباعة ترد وتستبدل خلال 14 يوماً مع أصل الفاتورة.',
      'tax_rate_percent': 0.0,
    });

    // 4. Default Categories
    final categories = [
      'قمصان وتيشيرتات',
      'بناطيل وجينز',
      'جواكت وسويترات',
      'فساتين وملابس سهرة',
      'ملابس أطفال',
      'إكسسوارات وأحزمة',
    ];

    final categoryIds = <String, int>{};
    for (final cat in categories) {
      final id = await db.insert('categories', {'name': cat});
      categoryIds[cat] = id;
    }

    // 5. Initial Products & Clothing Variants (Without Images)
    final initialProducts = [
      {
        'name': 'قميص أكسفورد كلاسيك قطن',
        'category_id': categoryIds['قمصان وتيشيرتات']!,
        'description': 'قميص قطن 100% مناسب للمناسبات والعمل',
        'variants': [
          {
            'size': 'M',
            'color': 'أبيض',
            'cost': 180.0,
            'price': 290.0,
            'stock': 15,
            'barcode': '100101',
          },
          {
            'size': 'L',
            'color': 'أبيض',
            'cost': 180.0,
            'price': 290.0,
            'stock': 20,
            'barcode': '100102',
          },
          {
            'size': 'XL',
            'color': 'أبيض',
            'cost': 180.0,
            'price': 290.0,
            'stock': 12,
            'barcode': '100103',
          },
          {
            'size': 'M',
            'color': 'كحلي',
            'cost': 180.0,
            'price': 290.0,
            'stock': 8,
            'barcode': '100104',
          },
          {
            'size': 'L',
            'color': 'كحلي',
            'cost': 180.0,
            'price': 290.0,
            'stock': 14,
            'barcode': '100105',
          },
          {
            'size': 'XL',
            'color': 'كحلي',
            'cost': 180.0,
            'price': 290.0,
            'stock': 2,
            'barcode': '100106',
          }, // Low stock
        ],
      },
      {
        'name': 'تيشيرت بولو سادة',
        'category_id': categoryIds['قمصان وتيشيرتات']!,
        'description': 'تيشيرت صيفي قطني عالي الجودة',
        'variants': [
          {
            'size': 'M',
            'color': 'أسود',
            'cost': 120.0,
            'price': 210.0,
            'stock': 25,
            'barcode': '100201',
          },
          {
            'size': 'L',
            'color': 'أسود',
            'cost': 120.0,
            'price': 210.0,
            'stock': 18,
            'barcode': '100202',
          },
          {
            'size': 'XL',
            'color': 'أسود',
            'cost': 120.0,
            'price': 210.0,
            'stock': 10,
            'barcode': '100203',
          },
          {
            'size': 'M',
            'color': 'رمادي',
            'cost': 120.0,
            'price': 210.0,
            'stock': 15,
            'barcode': '100204',
          },
          {
            'size': 'L',
            'color': 'رمادي',
            'cost': 120.0,
            'price': 210.0,
            'stock': 12,
            'barcode': '100205',
          },
        ],
      },
      {
        'name': 'بنطال جينز سليم كلاسيك',
        'category_id': categoryIds['بناطيل وجينز']!,
        'description': 'جينز خامة ممتازة ومريحة',
        'variants': [
          {
            'size': '30',
            'color': 'أزرق غامق',
            'cost': 220.0,
            'price': 380.0,
            'stock': 10,
            'barcode': '200101',
          },
          {
            'size': '32',
            'color': 'أزرق غامق',
            'cost': 220.0,
            'price': 380.0,
            'stock': 16,
            'barcode': '200102',
          },
          {
            'size': '34',
            'color': 'أزرق غامق',
            'cost': 220.0,
            'price': 380.0,
            'stock': 14,
            'barcode': '200103',
          },
          {
            'size': '36',
            'color': 'أزرق غامق',
            'cost': 220.0,
            'price': 380.0,
            'stock': 1,
            'barcode': '200104',
          }, // Low stock
          {
            'size': '32',
            'color': 'أسود',
            'cost': 220.0,
            'price': 380.0,
            'stock': 12,
            'barcode': '200105',
          },
          {
            'size': '34',
            'color': 'أسود',
            'cost': 220.0,
            'price': 380.0,
            'stock': 8,
            'barcode': '200106',
          },
        ],
      },
      {
        'name': 'بنطال قماش كاجوال (شينو)',
        'category_id': categoryIds['بناطيل وجينز']!,
        'description': 'بنطال مريح جداً للعمل والخروجات',
        'variants': [
          {
            'size': '32',
            'color': 'بيج',
            'cost': 200.0,
            'price': 350.0,
            'stock': 11,
            'barcode': '200201',
          },
          {
            'size': '34',
            'color': 'بيج',
            'cost': 200.0,
            'price': 350.0,
            'stock': 14,
            'barcode': '200202',
          },
          {
            'size': '32',
            'color': 'زيتي',
            'cost': 200.0,
            'price': 350.0,
            'stock': 9,
            'barcode': '200203',
          },
          {
            'size': '34',
            'color': 'زيتي',
            'cost': 200.0,
            'price': 350.0,
            'stock': 7,
            'barcode': '200204',
          },
        ],
      },
      {
        'name': 'جاكيت بامب مبطن شتوي',
        'category_id': categoryIds['جواكت وسويترات']!,
        'description': 'جاكيت ضد الماء والرياح وبطانة حرارية',
        'variants': [
          {
            'size': 'L',
            'color': 'أسود',
            'cost': 450.0,
            'price': 750.0,
            'stock': 6,
            'barcode': '300101',
          },
          {
            'size': 'XL',
            'color': 'أسود',
            'cost': 450.0,
            'price': 750.0,
            'stock': 5,
            'barcode': '300102',
          },
          {
            'size': 'L',
            'color': 'كحلي',
            'cost': 450.0,
            'price': 750.0,
            'stock': 4,
            'barcode': '300103',
          },
          {
            'size': 'XL',
            'color': 'كحلي',
            'cost': 450.0,
            'price': 750.0,
            'stock': 2,
            'barcode': '300104',
          },
        ],
      },
      {
        'name': 'فستان سهرة حرير مشجر',
        'category_id': categoryIds['فساتين وملابس سهرة']!,
        'description': 'فستان أنيق جداً بتطريز ناعم',
        'variants': [
          {
            'size': 'M',
            'color': 'أحمر نبيتي',
            'cost': 350.0,
            'price': 620.0,
            'stock': 7,
            'barcode': '400101',
          },
          {
            'size': 'L',
            'color': 'أحمر نبيتي',
            'cost': 350.0,
            'price': 620.0,
            'stock': 9,
            'barcode': '400102',
          },
          {
            'size': 'M',
            'color': 'زمردي أخضر',
            'cost': 350.0,
            'price': 620.0,
            'stock': 5,
            'barcode': '400103',
          },
          {
            'size': 'L',
            'color': 'زمردي أخضر',
            'cost': 350.0,
            'price': 620.0,
            'stock': 6,
            'barcode': '400104',
          },
        ],
      },
    ];

    for (final prod in initialProducts) {
      final productId = await db.insert('products', {
        'category_id': prod['category_id'],
        'name': prod['name'],
        'description': prod['description'],
        'created_at': DateTime.now().toIso8601String(),
      });

      final variantsList = prod['variants'] as List<Map<String, dynamic>>;
      for (final v in variantsList) {
        await db.insert('product_variants', {
          'product_id': productId,
          'sku_barcode': v['barcode'],
          'size': v['size'],
          'color': v['color'],
          'cost_price': v['cost'],
          'selling_price': v['price'],
          'stock_quantity': v['stock'],
          'min_stock_alert': 2,
        });
      }
    }
  }
}
