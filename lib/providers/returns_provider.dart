import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../models/return_model.dart';
import '../core/database/database_helper.dart';
import '../core/utils/number_parser.dart';

class ReturnsProvider with ChangeNotifier {
  OrderModel? _searchedOrder;
  List<ReturnModel> _returnsHistory = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  OrderModel? get searchedOrder => _searchedOrder;
  List<ReturnModel> get returnsHistory => _returnsHistory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  Future<void> loadReturnsHistory() async {
    _isLoading = true;
    notifyListeners();
    try {
      _returnsHistory = await DatabaseHelper.instance.getAllReturns();
    } catch (e) {
      debugPrint('Error loading returns: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> searchOrder(String invoiceNumber) async {
    final query = NumberParser.normalize(invoiceNumber.trim());
    if (query.isEmpty) return false;

    _isLoading = true;
    _errorMessage = null;
    _searchedOrder = null;
    notifyListeners();

    try {
      final order = await DatabaseHelper.instance.getOrderByInvoiceNumber(query);
      if (order != null) {
        _searchedOrder = order;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'لم يتم العثور على فاتورة بهذا الرقم: $query';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'خطأ أثناء البحث عن الفاتورة: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> returnItem({
    required OrderItemModel item,
    required int returnQty,
    required String reason,
    required int? shiftId,
  }) async {
    if (_searchedOrder == null || _searchedOrder!.id == null || item.id == null) {
      _errorMessage = 'بيانات الفاتورة غير مكتملة';
      notifyListeners();
      return false;
    }

    if (returnQty <= 0 || returnQty > item.remainingQuantity) {
      _errorMessage = 'الكمية المسترجعة غير صالحة';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final refundAmount = returnQty * item.unitPrice;
      await DatabaseHelper.instance.processReturn(
        orderId: _searchedOrder!.id!,
        orderItemId: item.id!,
        variantId: item.variantId,
        shiftId: shiftId,
        productName: item.productName,
        size: item.size,
        color: item.color,
        skuBarcode: item.skuBarcode,
        returnQty: returnQty,
        refundAmount: refundAmount,
        reason: reason,
      );

      _successMessage = 'تمت عملية الإرجاع بنجاح وتحديث المخزون والدرج النقدي';
      // Refresh searched order
      await searchOrder(_searchedOrder!.invoiceNumber);
      await loadReturnsHistory();
      return true;
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء معالجة المرتجع: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearSearch() {
    _searchedOrder = null;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
