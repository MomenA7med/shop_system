import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/product_variant_model.dart';
import '../models/category_model.dart';
import '../core/database/database_helper.dart';

class InventoryProvider with ChangeNotifier {
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  List<ProductVariantModel> _lowStockVariants = [];
  int? _selectedCategoryId;
  String _searchQuery = '';
  bool _isLoading = false;

  List<ProductModel> get products => _products;
  List<CategoryModel> get categories => _categories;
  List<ProductVariantModel> get lowStockVariants => _lowStockVariants;
  int? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  Future<void> loadInventory() async {
    _isLoading = true;
    notifyListeners();

    try {
      _categories = await DatabaseHelper.instance.getAllCategories();
      _products = await DatabaseHelper.instance.getProducts(
        categoryId: _selectedCategoryId,
        search: _searchQuery,
      );
      _lowStockVariants = await DatabaseHelper.instance.getLowStockVariants();
    } catch (e) {
      debugPrint('Error loading inventory: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    loadInventory();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadInventory();
  }

  Future<bool> addProduct(ProductModel product, List<ProductVariantModel> variants) async {
    try {
      await DatabaseHelper.instance.insertProduct(product, variants);
      await loadInventory();
      return true;
    } catch (e) {
      debugPrint('Error adding product: $e');
      return false;
    }
  }

  Future<bool> updateProduct(ProductModel product, List<ProductVariantModel> variants) async {
    try {
      await DatabaseHelper.instance.updateProduct(product, variants);
      await loadInventory();
      return true;
    } catch (e) {
      debugPrint('Error updating product: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      await DatabaseHelper.instance.deleteProduct(id);
      await loadInventory();
      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  Future<bool> addCategory(String name) async {
    try {
      await DatabaseHelper.instance.insertCategory(name.trim());
      _categories = await DatabaseHelper.instance.getAllCategories();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding category: $e');
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      await DatabaseHelper.instance.deleteCategory(id);
      _categories = await DatabaseHelper.instance.getAllCategories();
      if (_selectedCategoryId == id) _selectedCategoryId = null;
      await loadInventory();
      return true;
    } catch (e) {
      debugPrint('Error deleting category: $e');
      return false;
    }
  }
}
