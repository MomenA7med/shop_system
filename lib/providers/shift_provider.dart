import 'package:flutter/material.dart';
import '../models/shift_model.dart';
import '../core/database/database_helper.dart';

class ShiftProvider with ChangeNotifier {
  ShiftModel? _activeShift;
  List<ShiftModel> _shiftHistory = [];
  bool _isLoading = false;

  ShiftModel? get activeShift => _activeShift;
  List<ShiftModel> get shiftHistory => _shiftHistory;
  bool get hasActiveShift => _activeShift != null && _activeShift!.isOpen;
  bool get isLoading => _isLoading;

  Future<void> checkActiveShift(int cashierId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _activeShift = await DatabaseHelper.instance.getActiveShift(cashierId);
      _shiftHistory = await DatabaseHelper.instance.getShiftsHistory();
    } catch (e) {
      debugPrint('Error loading shift: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startShift(int cashierId, double openingFloat) async {
    try {
      await DatabaseHelper.instance.openShift(cashierId, openingFloat);
      await checkActiveShift(cashierId);
      return true;
    } catch (e) {
      debugPrint('Error opening shift: $e');
      return false;
    }
  }

  Future<ShiftModel?> endShift(double actualCash) async {
    if (_activeShift == null || _activeShift!.id == null) return null;

    try {
      final shiftId = _activeShift!.id!;
      final cashierId = _activeShift!.cashierId;
      await DatabaseHelper.instance.closeShift(shiftId, actualCash);
      
      final closedShift = _activeShift!;
      closedShift.actualCash = actualCash;
      closedShift.status = 'closed';
      closedShift.endTime = DateTime.now();

      await checkActiveShift(cashierId);
      return closedShift;
    } catch (e) {
      debugPrint('Error closing shift: $e');
      return null;
    }
  }
}
