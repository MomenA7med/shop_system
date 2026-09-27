import 'package:flutter/material.dart';
import '../models/store_settings_model.dart';
import '../models/user_model.dart';
import '../core/database/database_helper.dart';

class SettingsProvider with ChangeNotifier {
  StoreSettingsModel _settings = StoreSettingsModel(
    storeName: 'محل الأناقة للأزياء والملابس',
    slogan: 'أجود الخامات وأحدث صيحات الموضة',
    phone: '01012345678',
    address: 'شارع الجمهورية - أمام مول المدينة',
    currencySymbol: 'ج.م',
  );
  List<UserModel> _users = [];
  bool _isLoading = false;
  ThemeMode _themeMode = ThemeMode.dark;

  StoreSettingsModel get settings => _settings;
  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    try {
      _settings = await DatabaseHelper.instance.getStoreSettings();
      _users = await DatabaseHelper.instance.getAllUsers();
      _themeMode = _parseThemeMode(_settings.themeMode);
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ThemeMode _parseThemeMode(String val) {
    switch (val.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final themeStr = _themeModeToString(mode);
    _settings = _settings.copyWith(themeMode: themeStr);
    notifyListeners();
    try {
      await DatabaseHelper.instance.updateStoreSettings(_settings);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  Future<bool> updateSettings(StoreSettingsModel newSettings) async {
    try {
      await DatabaseHelper.instance.updateStoreSettings(newSettings);
      _settings = newSettings;
      _themeMode = _parseThemeMode(newSettings.themeMode);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating settings: $e');
      return false;
    }
  }

  Future<bool> addUser(String name, String role, String pinCode) async {
    try {
      await DatabaseHelper.instance.insertUser(UserModel(
        name: name,
        role: role,
        pinCode: pinCode,
      ));
      _users = await DatabaseHelper.instance.getAllUsers();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding user: $e');
      return false;
    }
  }

  Future<bool> updateUser(UserModel user) async {
    try {
      await DatabaseHelper.instance.updateUser(user);
      _users = await DatabaseHelper.instance.getAllUsers();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating user: $e');
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      await DatabaseHelper.instance.deleteUser(id);
      _users = await DatabaseHelper.instance.getAllUsers();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return false;
    }
  }
}
