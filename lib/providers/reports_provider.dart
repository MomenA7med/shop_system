import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product_variant_model.dart';
import '../core/database/database_helper.dart';

enum ReportPeriod {
  all,
  today,
  weekly,
  monthly,
  yearly,
  custom,
}

class ReportsProvider with ChangeNotifier {
  ReportPeriod _selectedPeriod = ReportPeriod.all;
  DateTime? _startDate;
  DateTime? _endDate;

  Map<String, dynamic> _financialStats = {
    'total_sales': 0.0,
    'total_orders': 0,
    'cash_sales': 0.0,
    'card_sales': 0.0,
    'total_returns': 0.0,
    'return_count': 0,
    'net_profit': 0.0,
    'total_cogs': 0.0,
  };
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _categorySales = [];
  List<ProductVariantModel> _lowStockVariants = [];
  bool _isLoading = false;

  ReportPeriod get selectedPeriod => _selectedPeriod;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  Map<String, dynamic> get financialStats => _financialStats;
  List<Map<String, dynamic>> get topProducts => _topProducts;
  List<Map<String, dynamic>> get categorySales => _categorySales;
  List<ProductVariantModel> get lowStockVariants => _lowStockVariants;
  bool get isLoading => _isLoading;

  double get totalSales => (_financialStats['total_sales'] as num?)?.toDouble() ?? 0.0;
  int get totalOrders => (_financialStats['total_orders'] as int?) ?? 0;
  double get cashSales => (_financialStats['cash_sales'] as num?)?.toDouble() ?? 0.0;
  double get cardSales => (_financialStats['card_sales'] as num?)?.toDouble() ?? 0.0;
  double get totalReturns => (_financialStats['total_returns'] as num?)?.toDouble() ?? 0.0;
  int get returnCount => (_financialStats['return_count'] as int?) ?? 0;
  double get netProfit => (_financialStats['net_profit'] as num?)?.toDouble() ?? 0.0;
  double get totalCogs => (_financialStats['total_cogs'] as num?)?.toDouble() ?? 0.0;
  double get profitMarginPercentage => totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;

  String get periodDisplayName {
    final dateFormat = DateFormat('yyyy/MM/dd');
    switch (_selectedPeriod) {
      case ReportPeriod.all:
        return 'جميع الفترات (شامل)';
      case ReportPeriod.today:
        return 'اليوم (${dateFormat.format(DateTime.now())})';
      case ReportPeriod.weekly:
        final start = _startDate ?? DateTime.now().subtract(const Duration(days: 6));
        final end = _endDate ?? DateTime.now();
        return 'أسبوعي (${dateFormat.format(start)} - ${dateFormat.format(end)})';
      case ReportPeriod.monthly:
        final now = DateTime.now();
        return 'شهري (${now.month}/${now.year})';
      case ReportPeriod.yearly:
        final now = DateTime.now();
        return 'سنوي (عام ${now.year})';
      case ReportPeriod.custom:
        if (_startDate != null && _endDate != null) {
          return 'فترة مخصصة (${dateFormat.format(_startDate!)} إلى ${dateFormat.format(_endDate!)})';
        }
        return 'فترة مخصصة';
    }
  }

  void setPeriod(ReportPeriod period, {DateTime? customStart, DateTime? customEnd}) {
    _selectedPeriod = period;
    final now = DateTime.now();

    switch (period) {
      case ReportPeriod.all:
        _startDate = null;
        _endDate = null;
        break;
      case ReportPeriod.today:
        _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case ReportPeriod.weekly:
        final weekStart = now.subtract(const Duration(days: 6));
        _startDate = DateTime(weekStart.year, weekStart.month, weekStart.day, 0, 0, 0);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case ReportPeriod.monthly:
        _startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        break;
      case ReportPeriod.yearly:
        _startDate = DateTime(now.year, 1, 1, 0, 0, 0);
        _endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        break;
      case ReportPeriod.custom:
        if (customStart != null) {
          _startDate = DateTime(customStart.year, customStart.month, customStart.day, 0, 0, 0);
        }
        if (customEnd != null) {
          _endDate = DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59, 999);
        }
        break;
    }

    loadReports();
  }

  Future<void> loadReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      _financialStats = await DatabaseHelper.instance.getFinancialStats(
        startDate: _startDate,
        endDate: _endDate,
      );
      _topProducts = await DatabaseHelper.instance.getTopSellingProducts(
        startDate: _startDate,
        endDate: _endDate,
      );
      _categorySales = await DatabaseHelper.instance.getCategorySalesStats(
        startDate: _startDate,
        endDate: _endDate,
      );
      _lowStockVariants = await DatabaseHelper.instance.getLowStockVariants();
    } catch (e) {
      debugPrint('Error loading reports: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
