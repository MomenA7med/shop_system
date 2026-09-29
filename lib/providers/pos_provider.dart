import 'package:flutter/material.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/product_variant_model.dart';
import '../models/category_model.dart';
import '../core/database/database_helper.dart';
import '../core/services/license_service.dart';
import '../core/utils/number_parser.dart';

class POSProvider with ChangeNotifier {
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  final List<OrderItemModel> _cartItems = [];
  int? _selectedCategoryId;
  String _searchQuery = '';
  double _discount = 0.0;
  double _amountPaid = 0.0;
  bool _isLoading = false;
  String? _statusMessage;

  List<ProductModel> get products => _products;
  List<CategoryModel> get categories => _categories;
  List<OrderItemModel> get cartItems => _cartItems;
  int? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  double get discount => _discount;
  double get amountPaid => _amountPaid;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;

  double get subtotal => _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get grandTotal => (subtotal - _discount) > 0 ? (subtotal - _discount) : 0.0;
  double get changeDue => (_cartItems.isNotEmpty && _amountPaid > grandTotal) ? _amountPaid - grandTotal : 0.0;
  bool get canCheckout => _cartItems.isNotEmpty && _amountPaid >= grandTotal && grandTotal > 0;

  Future<void> loadPOSData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await DatabaseHelper.instance.cleanupOrphanedProducts();
      _categories = await DatabaseHelper.instance.getAllCategories();
      _products = await DatabaseHelper.instance.getProducts(
        categoryId: _selectedCategoryId,
        search: _searchQuery,
      );
    } catch (e) {
      debugPrint('Error loading POS data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    loadPOSData();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadPOSData();
  }

  void clearSearch() {
    _searchQuery = '';
    loadPOSData();
  }

  void addVariantToCart(ProductModel product, ProductVariantModel variant, [double quantity = 1.0]) {
    if (variant.stockQuantity <= 0) {
      _statusMessage = 'المنتج غير متوفر بالمخزون!';
      notifyListeners();
      return;
    }

    final existingIndex = _cartItems.indexWhere((item) => item.variantId == variant.id);

    if (existingIndex >= 0) {
      final newQty = _cartItems[existingIndex].quantity + quantity;
      if (newQty <= variant.stockQuantity || variant.stockQuantity <= 0) {
        _cartItems[existingIndex].quantity = newQty;
        _statusMessage = 'تمت زيادة الكمية';
      } else {
        _cartItems[existingIndex].quantity = variant.stockQuantity;
        _statusMessage = 'تم ضبط الكمية إلى الحد الأقصى للمخزون (${variant.stockQuantity})';
      }
    } else {
      _cartItems.add(OrderItemModel(
        variantId: variant.id!,
        productId: product.id!,
        productName: product.name,
        size: variant.size,
        color: variant.color,
        skuBarcode: variant.skuBarcode,
        quantity: quantity,
        unitPrice: variant.sellingPrice,
        costPrice: variant.costPrice,
      ));
      _statusMessage = 'تمت إضافة الصنف للسلة';
    }

    // Auto set initial cash suggestion if not set or smaller than total
    if (_amountPaid < grandTotal) {
      _amountPaid = grandTotal;
    }

    notifyListeners();
  }

  Future<bool> scanBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return false;

    final found = await DatabaseHelper.instance.findVariantByBarcode(cleanBarcode);
    if (found != null) {
      final variant = ProductVariantModel.fromMap(found);
      final product = ProductModel(
        id: found['product_id'] as int,
        categoryId: found['category_id'] as int? ?? 1,
        name: found['product_name'] as String,
      );
      addVariantToCart(product, variant);
      _searchQuery = '';
      await loadPOSData();
      return true;
    } else {
      _statusMessage = 'لم يتم العثور على باركود: $cleanBarcode';
      notifyListeners();
      return false;
    }
  }

  void updateQuantity(int index, double newQuantity) {
    if (index >= 0 && index < _cartItems.length) {
      if (newQuantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index].quantity = newQuantity;
      }
      if (_cartItems.isEmpty) {
        _amountPaid = 0.0;
        _discount = 0.0;
      } else {
        _amountPaid = grandTotal;
      }
      notifyListeners();
    }
  }

  void incrementQuantity(int index, [double step = 1.0]) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index].quantity += step;
      if (_amountPaid < grandTotal) {
        _amountPaid = grandTotal;
      }
      notifyListeners();
    }
  }

  void decrementQuantity(int index, [double step = 1.0]) {
    if (index >= 0 && index < _cartItems.length) {
      final current = _cartItems[index].quantity;
      if (current > step) {
        _cartItems[index].quantity = (current - step);
      } else {
        _cartItems.removeAt(index);
      }
      if (_cartItems.isEmpty) {
        _amountPaid = 0.0;
        _discount = 0.0;
      } else if (_amountPaid < grandTotal || _amountPaid > grandTotal) {
        _amountPaid = grandTotal;
      }
      notifyListeners();
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      if (_cartItems.isEmpty) {
        _amountPaid = 0.0;
        _discount = 0.0;
      } else if (_amountPaid < grandTotal || _amountPaid > grandTotal) {
        _amountPaid = grandTotal;
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cartItems.clear();
    _discount = 0.0;
    _amountPaid = 0.0;
    _statusMessage = null;
    notifyListeners();
  }

  void setDiscount(double discountAmount) {
    if (_cartItems.isEmpty) {
      _discount = 0.0;
      _amountPaid = 0.0;
    } else {
      _discount = discountAmount < 0 ? 0.0 : discountAmount;
      if (_amountPaid < grandTotal) {
        _amountPaid = grandTotal;
      }
    }
    notifyListeners();
  }

  void setAmountPaid(double amount) {
    if (_cartItems.isEmpty) {
      _amountPaid = 0.0;
    } else {
      _amountPaid = amount < 0 ? 0.0 : amount;
    }
    notifyListeners();
  }

  void appendCashDigit(String digit) {
    String current = _amountPaid == 0 ? '' : _amountPaid.toStringAsFixed(0);
    if (digit == 'C') {
      _amountPaid = 0.0;
    } else if (digit == 'DEL') {
      if (current.isNotEmpty) {
        current = current.substring(0, current.length - 1);
        _amountPaid = NumberParser.tryParseDouble(current, 0.0);
      }
    } else {
      current += digit;
      _amountPaid = NumberParser.tryParseDouble(current, _amountPaid);
    }
    notifyListeners();
  }

  void quickAddCash(double amount) {
    _amountPaid += amount;
    notifyListeners();
  }

  Future<OrderModel?> checkout({
    required int cashierId,
    required int? shiftId,
  }) async {
    if (!canCheckout) return null;

    final licenseStatus = await LicenseService.checkStatus();
    if (!licenseStatus.canCreateInvoice) {
      _statusMessage = licenseStatus.expirationReason ?? 'تم تجاوز الحد المسموح به للنسخة التجريبية. يرجى تفعيل البرنامج.';
      notifyListeners();
      return null;
    }

    try {
      final order = await DatabaseHelper.instance.createOrderWithItems(
        cashierId: cashierId,
        shiftId: shiftId,
        totalAmount: grandTotal,
        amountPaid: _amountPaid,
        changeDue: changeDue,
        items: List.from(_cartItems),
      );

      clearCart();
      await loadPOSData(); // Refresh product stock
      return order;
    } catch (e) {
      debugPrint('Error during checkout: $e');
      _statusMessage = 'حدث خطأ أثناء إتمام عملية البيع: $e';
      notifyListeners();
      return null;
    }
  }
}
