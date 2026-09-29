import 'package:flutter/material.dart';
import '../core/services/license_service.dart';

class LicenseProvider with ChangeNotifier {
  LicenseStatus? _status;
  HardwareInfo? _hardwareInfo;
  bool _isLoading = true;
  String? _errorMessage;

  LicenseStatus? get status => _status;
  HardwareInfo? get hardwareInfo => _hardwareInfo;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isActivated => _status?.isActivated ?? false;
  bool get isTrial => _status?.isTrial ?? true;
  bool get isTrialExpired => _status?.isTrialExpired ?? false;
  int get totalInvoices => _status?.totalInvoices ?? 0;
  int get maxTrialInvoices => _status?.maxTrialInvoices ?? 5;
  int get remainingInvoices => isActivated ? 9999 : (maxTrialInvoices - totalInvoices < 0 ? 0 : maxTrialInvoices - totalInvoices);
  int get daysRemaining => _status?.daysRemaining ?? 30;
  bool get canCreateInvoice => _status?.canCreateInvoice ?? false;

  LicenseProvider({
    bool autoInit = true,
    LicenseStatus? initialStatus,
    HardwareInfo? initialHardwareInfo,
  }) {
    _status = initialStatus ??
        LicenseStatus(
          isActivated: false,
          isTrial: true,
          isTrialExpired: false,
          totalInvoices: 0,
          daysRemaining: 30,
        );
    _hardwareInfo = initialHardwareInfo;
    if (autoInit) {
      initLicense();
    } else {
      _isLoading = false;
    }
  }

  Future<void> initLicense() async {
    _isLoading = true;
    notifyListeners();

    try {
      _hardwareInfo = await LicenseService.getHardwareInfo();
      _status = await LicenseService.checkStatus();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      _status = await LicenseService.checkStatus();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing license: $e');
    }
  }

  Future<bool> activate(String key) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await LicenseService.activate(key);
      if (success) {
        _status = await LicenseService.checkStatus();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'كود التفعيل غير صالح لهذا الجهاز!';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء التفعيل: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
