import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../core/database/database_helper.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isCashier => _currentUser?.isCashier ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String pinCode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await DatabaseHelper.instance.getUserByPin(pinCode.trim());
      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'رمز الدخول (PIN) غير صحيح';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء تسجيل الدخول: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  @visibleForTesting
  void setCurrentUserForTesting(UserModel? user) {
    _currentUser = user;
    notifyListeners();
  }
}
