import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDateTime(DateTime dateTime) {
    try {
      return DateFormat('yyyy-MM-dd | hh:mm a', 'ar').format(dateTime);
    } catch (_) {
      return DateFormat('yyyy-MM-dd | hh:mm a').format(dateTime);
    }
  }

  static String formatDate(DateTime dateTime) {
    try {
      return DateFormat('yyyy-MM-dd', 'ar').format(dateTime);
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(dateTime);
    }
  }

  static String formatTime(DateTime dateTime) {
    try {
      return DateFormat('hh:mm a', 'ar').format(dateTime);
    } catch (_) {
      return DateFormat('hh:mm a').format(dateTime);
    }
  }
}
