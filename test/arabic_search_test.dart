import 'package:flutter_test/flutter_test.dart';
import 'package:shop_system/core/utils/arabic_search_utils.dart';
import 'package:shop_system/models/product_model.dart';
import 'package:shop_system/models/product_variant_model.dart';

void main() {
  group('ArabicSearchUtils Tests', () {
    test('Normalizes Arabic letters, hamzas, diacritics, and digits correctly', () {
      expect(ArabicSearchUtils.normalize('إندومي'), 'اندومي');
      expect(ArabicSearchUtils.normalize('أرز'), 'ارز');
      expect(ArabicSearchUtils.normalize('آيس كريم'), 'ايس كريم');
      expect(ArabicSearchUtils.normalize('جبنة'), 'جبنه');
      expect(ArabicSearchUtils.normalize('شاى'), 'شاي');
      expect(ArabicSearchUtils.normalize('بَيْضٌ'), 'بيض');
      expect(ArabicSearchUtils.normalize('شيبسي ٥٠٠ جم'), 'شيبسي 500 جم');
    });

    test('Searching "بيض" does NOT match clothing with color "أبيض"', () {
      final clothingProduct = ProductModel(
        id: 1,
        name: 'قميص أكسفورد كلاسيك قطن',
        description: 'قميص قطن 100%',
        categoryId: 1,
        categoryName: 'قمصان وتيشيرتات',
        variants: [
          ProductVariantModel(
            id: 1,
            productId: 1,
            skuBarcode: '100101',
            size: 'M',
            color: 'أبيض',
            costPrice: 180.0,
            sellingPrice: 290.0,
            stockQuantity: 15,
          ),
        ],
      );

      final eggProduct = ProductModel(
        id: 2,
        name: 'طبق بيض أحمر 30 بيضة',
        description: 'بيض مزارع طازج',
        categoryId: 2,
        categoryName: 'ألبان وبيض',
        variants: [
          ProductVariantModel(
            id: 2,
            productId: 2,
            skuBarcode: '6220001234567',
            size: 'طبق',
            color: 'أحمر',
            costPrice: 130.0,
            sellingPrice: 150.0,
            stockQuantity: 20,
          ),
        ],
      );

      final results = ArabicSearchUtils.filterAndRank([clothingProduct, eggProduct], 'بيض');

      // Only eggProduct should match, clothingProduct should NOT match!
      expect(results.length, 1);
      expect(results.first.id, 2);
      expect(results.first.name, 'طبق بيض أحمر 30 بيضة');
    });

    test('Multi-token and normalized Arabic search matches accurately', () {
      final chipsProduct = ProductModel(
        id: 3,
        name: 'شيبسي عائلي بطعم الطماطم المتبلة',
        categoryId: 3,
        categoryName: 'شيبسي ومقرمشات',
        variants: [
          ProductVariantModel(
            id: 3,
            productId: 3,
            skuBarcode: '6221004123456',
            size: 'كيس',
            color: 'افتراضي',
            costPrice: 8.5,
            sellingPrice: 10.0,
            stockQuantity: 100,
          ),
        ],
      );

      final cheeseProduct = ProductModel(
        id: 4,
        name: 'جبنة دومتي فيتا 500 جم',
        categoryId: 2,
        categoryName: 'ألبان وجبن',
        variants: [
          ProductVariantModel(
            id: 4,
            productId: 4,
            skuBarcode: '6223000551122',
            size: 'علبة',
            color: 'افتراضي',
            costPrice: 30.0,
            sellingPrice: 38.0,
            stockQuantity: 50,
          ),
        ],
      );

      // Searching 'شيبسي طماطم'
      final chipsResults = ArabicSearchUtils.filterAndRank([chipsProduct, cheeseProduct], 'شيبسي طماطم');
      expect(chipsResults.length, 1);
      expect(chipsResults.first.id, 3);

      // Searching 'جبنه' (Ta Marbuta vs Ha) matches 'جبنة'
      final cheeseResults = ArabicSearchUtils.filterAndRank([chipsProduct, cheeseProduct], 'جبنه');
      expect(cheeseResults.length, 1);
      expect(cheeseResults.first.id, 4);

      // Searching Arabic digits barcode '٦٢٢٣٠٠٠٥٥١١٢٢'
      final barcodeResults = ArabicSearchUtils.filterAndRank([chipsProduct, cheeseProduct], '٦٢٢٣٠٠٠٥٥١١٢٢');
      expect(barcodeResults.length, 1);
      expect(barcodeResults.first.id, 4);
    });
  });
}
