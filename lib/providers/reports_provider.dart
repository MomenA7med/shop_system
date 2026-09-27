import 'package:flutter/material.dart';
import '../models/product_variant_model.dart';
import '../core/database/database_helper.dart';

class ReportsProvider with ChangeNotifier {
  Map<String, dynamic> _financialStats = {
    'total_sales': 0.0,
    'total_orders': 0,
    'total_returns': 0.0,
    'return_count': 0,
    'net_profit': 0.0,
    'total_cogs': 0.0,
  };
  List<Map<String, dynamic>> _topProducts = [];
  List<ProductVariantModel> _lowStockVariants = [];
  bool _isLoading = false;

  Map<String, dynamic> get financialStats => _financialStats;
  List<Map<String, dynamic>> get topProducts => _topProducts;
  List<ProductVariantModel> get lowStockVariants => _lowStockVariants;
  bool get isLoading => _isLoading;

  double get totalSales => (_financialStats['total_sales'] as num?)?.toDouble() ?? 0.0;
  int get totalOrders => (_financialStats['total_orders'] as int?) ?? 0;
  double get totalReturns => (_financialStats['total_returns'] as num?)?.toDouble() ?? 0.0;
  int get returnCount => (_financialStats['return_count'] as int?) ?? 0;
  double get netProfit => (_financialStats['net_profit'] as num?)?.toDouble() ?? 0.0;
  double get totalCogs => (_financialStats['total_cogs'] as num?)?.toDouble() ?? 0.0;

  Future<void> loadReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      _financialStats = await DatabaseHelper.instance.getFinancialStats();
      _topProducts = await DatabaseHelper.instance.getTopSellingProducts();
      _lowStockVariants = await DatabaseHelper.instance.getLowStockVariants();
    } catch (e) {
      debugPrint('Error loading reports: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
