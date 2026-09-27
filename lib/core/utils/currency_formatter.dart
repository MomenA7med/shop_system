import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, {String symbol = 'ج.م'}) {
    final formatter = NumberFormat('#,##0.00', 'ar');
    return '${formatter.format(amount)} $symbol';
  }

  static String formatSimple(double amount) {
    final formatter = NumberFormat('#,##0.00', 'ar');
    return formatter.format(amount);
  }
}
