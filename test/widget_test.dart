import 'package:flutter_test/flutter_test.dart';
import 'package:shop_system/models/product_model.dart';
import 'package:shop_system/models/product_variant_model.dart';
import 'package:shop_system/models/order_item_model.dart';
import 'package:shop_system/models/shift_model.dart';
import 'package:shop_system/core/utils/number_parser.dart';

void main() {
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

  test('NumberParser normalizes and parses Arabic and English numbers accurately', () {
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
  });
}
