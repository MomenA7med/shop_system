class NumberParser {
  /// Converts Arabic-Indic (٠-٩) and Eastern Arabic (۰-۹) digits to standard ASCII digits (0-9),
  /// and normalizes Arabic comma (٫) and standard comma (,) to decimal dot (.).
  static String normalize(String input) {
    if (input.isEmpty) return '';
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const easternDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    var result = input.trim();
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(arabicDigits[i], i.toString());
      result = result.replaceAll(easternDigits[i], i.toString());
    }
    // Normalize Arabic decimal comma '٫' and standard comma ',' to dot '.'
    result = result.replaceAll('٫', '.').replaceAll(',', '.');
    return result;
  }

  /// Safely parses a double from a string containing Arabic or English digits.
  static double tryParseDouble(String? input, [double defaultValue = 0.0]) {
    if (input == null || input.trim().isEmpty) return defaultValue;
    final normalized = normalize(input);
    return double.tryParse(normalized) ?? defaultValue;
  }

  /// Safely parses an integer from a string containing Arabic or English digits.
  static int tryParseInt(String? input, [int defaultValue = 0]) {
    if (input == null || input.trim().isEmpty) return defaultValue;
    final normalized = normalize(input);
    final directInt = int.tryParse(normalized);
    if (directInt != null) return directInt;
    final parsedDouble = double.tryParse(normalized);
    return parsedDouble?.toInt() ?? defaultValue;
  }

  /// Formats a quantity value cleanly (e.g. 1.0 -> '1', 0.5 -> '0.5', 0.25 -> '0.25', 0.333 -> '0.333')
  static String formatQuantity(num quantity) {
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
  }

  /// Parses textual quantity input including common Arabic supermarket fractions:
  /// 'ربع' -> 0.25, 'نص' -> 0.5, 'تلت' -> 0.333, 'تمن' -> 0.125, 'كيلو ونص' -> 1.5, etc.
  static double parseQuantity(String input, [double fallback = 1.0]) {
    final clean = input.trim().toLowerCase().replaceAll(' ', '');
    if (clean.isEmpty) return fallback;

    // Direct fraction matching
    if (clean == 'ربع' || clean == '1/4' || clean == '¼' || clean == 'ربعكيلو') return 0.25;
    if (clean == 'نص' || clean == 'نصف' || clean == '1/2' || clean == '½' || clean == 'نصكيلو') return 0.5;
    if (clean == 'تلت' || clean == 'ثلث' || clean == '1/3' || clean == '⅓' || clean == 'تلتكيلو') return 0.333;
    if (clean == 'تمن' || clean == 'ثمن' || clean == '1/8' || clean == '⅛' || clean == 'تمنكيلو') return 0.125;
    if (clean == 'الاربع' || clean == 'إلاربع' || clean == '3/4' || clean == '¾' || clean == 'ثلاثةاربع') return 0.75;
    if (clean == 'كيلوونص' || clean == 'كيلوونصف') return 1.5;
    if (clean == 'كيلووربع') return 1.25;
    if (clean == 'كيلو') return 1.0;

    return tryParseDouble(input, fallback);
  }

  /// Checks whether a character is an Arabic or English numeric digit.
  static bool isDigit(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    // ASCII 0-9
    if (code >= 48 && code <= 57) return true;
    // Arabic-Indic ٠-٩ (0x0660 - 0x0669)
    if (code >= 0x0660 && code <= 0x0669) return true;
    // Eastern Arabic-Indic ۰-۹ (0x06F0 - 0x06F9)
    if (code >= 0x06F0 && code <= 0x06F9) return true;
    return false;
  }

  /// Extracts single digit from Arabic or English digit character.
  static String? extractDigit(String char) {
    if (!isDigit(char)) return null;
    return normalize(char);
  }
}
