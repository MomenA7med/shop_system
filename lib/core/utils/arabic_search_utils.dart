import '../../models/product_model.dart';
import 'number_parser.dart';

class ArabicSearchUtils {
  /// Normalizes Arabic and alphanumeric text for search comparison:
  /// - Converts Arabic/Eastern digits to ASCII digits (0-9)
  /// - Normalizes all Hamza forms (أ, إ, آ, ٱ) -> ا
  /// - Normalizes Ta Marbuta (ة) -> ه
  /// - Normalizes Alif Maqsura (ى) -> ي
  /// - Normalizes Waw with Hamza (ؤ) -> و
  /// - Normalizes Ya with Hamza (ئ) -> ي
  /// - Strips Tashkeel (diacritics) and Tatweel (ـ)
  /// - Trims and converts to lowercase
  static String normalize(String? text) {
    if (text == null || text.trim().isEmpty) return '';

    // First normalize digits using NumberParser
    var result = NumberParser.normalize(text).toLowerCase();

    // Remove Arabic diacritics / Tashkeel
    result = result.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

    // Remove Tatweel (ـ)
    result = result.replaceAll('ـ', '');

    // Normalize Hamzas
    result = result
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا');

    // Normalize Ta Marbuta
    result = result.replaceAll('ة', 'ه');

    // Normalize Alif Maqsura
    result = result.replaceAll('ى', 'ي');

    // Normalize Hamza on Waw / Ya
    result = result.replaceAll('ؤ', 'و').replaceAll('ئ', 'ي');

    // Collapse multiple whitespaces into a single space
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  /// Splits a search query into normalized individual search tokens
  static List<String> extractTokens(String query) {
    final norm = normalize(query);
    if (norm.isEmpty) return [];
    return norm.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// Calculates the relevance score of a product against a search query.
  /// Higher score = more relevant. Returns 0 if product does not match.
  static int calculateRelevance(ProductModel product, String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return 1;

    final normQuery = normalize(cleanQuery);
    if (normQuery.isEmpty) return 1;

    final tokens = extractTokens(cleanQuery);
    if (tokens.isEmpty) return 1;

    final normName = normalize(product.name);
    final normDesc = normalize(product.description);
    final normCat = normalize(product.categoryName);

    int score = 0;

    // 1. Exact or partial Barcode matching (Highest priority in POS)
    for (final variant in product.variants) {
      final barcode = NumberParser.normalize(variant.skuBarcode).trim();
      final normBarcode = normalize(barcode);

      if (barcode == cleanQuery || normBarcode == normQuery) {
        return 1000; // Exact Barcode Match
      } else if (barcode.startsWith(cleanQuery) || normBarcode.startsWith(normQuery)) {
        score = 800;
      } else if (barcode.contains(cleanQuery) || normBarcode.contains(normQuery)) {
        score = score < 600 ? 600 : score;
      }
    }

    // 2. Product Name Matching (High priority)
    if (normName == normQuery) {
      score = score < 500 ? 500 : score; // Exact Name Match
    } else if (normName.startsWith(normQuery)) {
      score = score < 400 ? 400 : score; // Name starts with full query
    } else if (normName.contains(normQuery)) {
      score = score < 300 ? 300 : score; // Name contains full query phrase
    } else {
      // Check if ALL search tokens appear in the product name
      final allTokensInName = tokens.every((token) => normName.contains(token));
      if (allTokensInName) {
        score = score < 250 ? 250 : score;
      } else {
        // Count how many tokens appear in name
        final matchingTokensInName = tokens.where((token) => normName.contains(token)).length;
        if (matchingTokensInName > 0 && matchingTokensInName == tokens.length) {
          score = score < 200 ? 200 : score;
        }
      }
    }

    // 3. Category Name Matching
    if (normCat.isNotEmpty) {
      if (normCat == normQuery || normCat.startsWith(normQuery)) {
        score = score < 150 ? 150 : score;
      } else if (tokens.every((t) => normCat.contains(t))) {
        score = score < 120 ? 120 : score;
      }
    }

    // 4. Description Matching
    if (normDesc.isNotEmpty && tokens.every((t) => normDesc.contains(t))) {
      score = score < 100 ? 100 : score;
    }

    // 5. Variant Unit / Package / Note Matching (Whole-word / Token check)
    // Avoids partial substring traps (e.g. 'بيض' matching 'أبيض' / 'ابيض')
    for (final variant in product.variants) {
      final normSize = normalize(variant.size);
      final normColor = normalize(variant.color);

      // Check variant size / package (e.g., 'كيلو', 'علبة', 'كيس', 'M', 'L')
      if (normSize.isNotEmpty && normSize != '-' && normSize != 'افتراضي') {
        if (normSize == normQuery || tokens.contains(normSize)) {
          score = score < 90 ? 90 : score;
        }
      }

      // Check variant note / color (e.g., 'احمر', 'ابيض', 'بلدي', 'كانز')
      if (normColor.isNotEmpty && normColor != '-' && normColor != 'افتراضي') {
        // Whole token match on color to prevent 'بيض' matching 'ابيض'
        if (normColor == normQuery || tokens.contains(normColor)) {
          score = score < 80 ? 80 : score;
        }
      }
    }

    return score;
  }

  /// Filters and sorts a list of products by search relevance score descending
  static List<ProductModel> filterAndRank(List<ProductModel> products, String query) {
    final clean = query.trim();
    if (clean.isEmpty) return products;

    final scored = <MapEntry<ProductModel, int>>[];
    for (final product in products) {
      final score = calculateRelevance(product, clean);
      if (score > 0) {
        scored.add(MapEntry(product, score));
      }
    }

    // Sort by score descending, then by product ID descending
    scored.sort((a, b) {
      final comp = b.value.compareTo(a.value);
      if (comp != 0) return comp;
      return (b.key.id ?? 0).compareTo(a.key.id ?? 0);
    });

    return scored.map((e) => e.key).toList();
  }
}
