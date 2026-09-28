import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';
import '../core/utils/number_parser.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';

enum InvoiceDateFilter {
  today,
  yesterday,
  last7days,
  last30days,
  thisMonth,
  custom,
  all,
}

class InvoicesProvider with ChangeNotifier {
  List<OrderModel> _invoices = [];
  OrderModel? _selectedInvoice;
  bool _isLoading = false;
  String? _errorMessage;

  InvoiceDateFilter _dateFilter = InvoiceDateFilter.today;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _searchQuery = '';
  String _statusFilter = 'all';

  List<OrderModel> get invoices => _invoices;
  OrderModel? get selectedInvoice => _selectedInvoice;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  InvoiceDateFilter get dateFilter => _dateFilter;
  DateTime? get customStartDate => _customStartDate;
  DateTime? get customEndDate => _customEndDate;
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;

  // Computed Summary Metrics for active filter
  double get totalSalesAmount => _invoices.fold(0.0, (sum, order) => sum + order.totalAmount);
  double get netSalesAmount => _invoices.fold(0.0, (sum, order) => sum + order.netTotalAmount);
  double get totalRefundedAmount => _invoices.fold(0.0, (sum, order) => sum + order.refundedAmount);
  int get totalInvoicesCount => _invoices.length;
  int get totalItemsCount => _invoices.fold(0, (sum, order) => sum + order.totalItemCount);
  int get remainingItemsCount => _invoices.fold(0, (sum, order) => sum + order.remainingPieces);
  int get totalReturnedItemsCount => _invoices.fold(0, (sum, order) => sum + order.totalReturnedPieces);
  double get averageInvoiceValue => _invoices.isEmpty ? 0.0 : netSalesAmount / _invoices.length;

  Future<void> loadInvoices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      DateTime? start;
      DateTime? end;
      final now = DateTime.now();

      switch (_dateFilter) {
        case InvoiceDateFilter.today:
          start = DateTime(now.year, now.month, now.day, 0, 0, 0);
          end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case InvoiceDateFilter.yesterday:
          final yest = now.subtract(const Duration(days: 1));
          start = DateTime(yest.year, yest.month, yest.day, 0, 0, 0);
          end = DateTime(yest.year, yest.month, yest.day, 23, 59, 59);
          break;
        case InvoiceDateFilter.last7days:
          start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
          end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case InvoiceDateFilter.last30days:
          start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
          end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case InvoiceDateFilter.thisMonth:
          start = DateTime(now.year, now.month, 1, 0, 0, 0);
          end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case InvoiceDateFilter.custom:
          if (_customStartDate != null) {
            start = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day, 0, 0, 0);
          }
          if (_customEndDate != null) {
            end = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59);
          }
          break;
        case InvoiceDateFilter.all:
          start = null;
          end = null;
          break;
      }

      final normalizedSearch = NumberParser.normalize(_searchQuery);

      _invoices = await DatabaseHelper.instance.getOrdersWithFilter(
        startDate: start,
        endDate: end,
        searchQuery: normalizedSearch,
        status: _statusFilter,
      );

      // Keep selected invoice updated if open
      if (_selectedInvoice != null) {
        final match = _invoices.where((o) => o.id == _selectedInvoice!.id);
        if (match.isNotEmpty) {
          _selectedInvoice = match.first;
        }
      }
    } catch (e) {
      _errorMessage = 'خطأ أثناء تحميل الفواتير: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setDateFilter(InvoiceDateFilter filter, {DateTime? customStart, DateTime? customEnd}) {
    _dateFilter = filter;
    if (filter == InvoiceDateFilter.custom) {
      _customStartDate = customStart;
      _customEndDate = customEnd;
    }
    loadInvoices();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadInvoices();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    loadInvoices();
  }

  void selectInvoice(OrderModel? invoice) {
    _selectedInvoice = invoice;
    notifyListeners();
  }

  Future<bool> updateInvoice({
    required int orderId,
    required List<OrderItemModel> items,
    required double totalAmount,
    required double amountPaid,
    required double changeDue,
  }) async {
    try {
      await DatabaseHelper.instance.updateOrder(
        orderId: orderId,
        items: items,
        totalAmount: totalAmount,
        amountPaid: amountPaid,
        changeDue: changeDue,
      );
      await loadInvoices();
      return true;
    } catch (e) {
      debugPrint('Error updating order: $e');
      _errorMessage = 'فشل تعديل الفاتورة: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteInvoice(int orderId) async {
    try {
      await DatabaseHelper.instance.deleteOrder(orderId);
      if (_selectedInvoice?.id == orderId) {
        _selectedInvoice = null;
      }
      await loadInvoices();
      return true;
    } catch (e) {
      debugPrint('Error deleting order: $e');
      _errorMessage = 'فشل حذف الفاتورة: $e';
      notifyListeners();
      return false;
    }
  }
}
