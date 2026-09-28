import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfoService {
  static String _version = '1.0.1';
  static String _buildNumber = '1';

  static String get version => _version;
  static String get buildNumber => _buildNumber;
  static String get fullVersion => '$_version+$_buildNumber';
  static String get displayVersion => 'الإصدار $_version (Desktop)';

  static Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version.isNotEmpty) {
        _version = packageInfo.version;
      }
      if (packageInfo.buildNumber.isNotEmpty) {
        _buildNumber = packageInfo.buildNumber;
      }
    } catch (e) {
      debugPrint('Error getting PackageInfo: $e');
    }
  }

  @visibleForTesting
  static void setMockVersion(String version, [String buildNumber = '1']) {
    _version = version;
    _buildNumber = buildNumber;
  }
}
