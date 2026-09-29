import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

class HardwareInfo {
  final String motherboardSerial;
  final String diskSerial;
  final String machineId; // Unique combined clean fingerprint

  HardwareInfo({
    required this.motherboardSerial,
    required this.diskSerial,
    required this.machineId,
  });
}

class LicenseStatus {
  final bool isActivated;
  final bool isTrial;
  final bool isTrialExpired;
  final int totalInvoices;
  final int maxTrialInvoices;
  final int daysRemaining;
  final String? expirationReason;

  LicenseStatus({
    required this.isActivated,
    required this.isTrial,
    required this.isTrialExpired,
    required this.totalInvoices,
    this.maxTrialInvoices = 5,
    required this.daysRemaining,
    this.expirationReason,
  });

  bool get canCreateInvoice => isActivated || (!isTrialExpired && totalInvoices < maxTrialInvoices);
}

class LicenseService {
  // Secret salt/key known only to the developer
  static const String _secretMasterKey = "SHOP_POS_MOMEN_AHMED_2026_@#!99";
  static const int maxTrialDays = 30;
  static const int maxTrialInvoices = 5;
  static const String developerWhatsApp = "201003779702";

  static HardwareInfo? _cachedHardwareInfo;

  /// Retrieves hardware identification for the current device
  static Future<HardwareInfo> getHardwareInfo() async {
    if (_cachedHardwareInfo != null) {
      return _cachedHardwareInfo!;
    }

    String motherboard = "UNKNOWN_BOARD";
    String disk = "UNKNOWN_DISK";

    try {
      if (Platform.isWindows) {
        // 1. Get Motherboard Serial Number via PowerShell
        try {
          final mbResult = await Process.run('powershell', [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            '(Get-CimInstance Win32_BaseBoard).SerialNumber',
          ]);
          final out = mbResult.stdout.toString().trim();
          if (out.isNotEmpty && out.toLowerCase() != 'null') {
            motherboard = out.toUpperCase();
          }
        } catch (_) {}

        // Fallback for Motherboard via WMIC
        if (motherboard == "UNKNOWN_BOARD") {
          try {
            final wmicMb = await Process.run('wmic', ['baseboard', 'get', 'serialnumber']);
            final lines = wmicMb.stdout.toString().split('\n');
            if (lines.length > 1 && lines[1].trim().isNotEmpty) {
              motherboard = lines[1].trim().toUpperCase();
            }
          } catch (_) {}
        }

        // 2. Get Disk Serial Number via PowerShell
        try {
          final diskResult = await Process.run('powershell', [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            '(Get-CimInstance Win32_DiskDrive | Select-Object -First 1).SerialNumber',
          ]);
          final out = diskResult.stdout.toString().trim();
          if (out.isNotEmpty && out.toLowerCase() != 'null') {
            disk = out.toUpperCase();
          }
        } catch (_) {}

        // Fallback for Disk via WMIC
        if (disk == "UNKNOWN_DISK") {
          try {
            final wmicDisk = await Process.run('wmic', ['diskdrive', 'get', 'serialnumber']);
            final lines = wmicDisk.stdout.toString().split('\n');
            if (lines.length > 1 && lines[1].trim().isNotEmpty) {
              disk = lines[1].trim().toUpperCase();
            }
          } catch (_) {}
        }

        // 3. Additional fallback: MachineGuid from Windows Registry
        if (motherboard == "UNKNOWN_BOARD" && disk == "UNKNOWN_DISK") {
          try {
            final regResult = await Process.run('reg', [
              'query',
              r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography',
              '/v',
              'MachineGuid',
            ]);
            final match = RegExp(r'MachineGuid\s+REG_SZ\s+([a-zA-Z0-9\-]+)').firstMatch(regResult.stdout.toString());
            if (match != null) {
              motherboard = "WIN_REG";
              disk = match.group(1) ?? "WIN_DEFAULT";
            }
          } catch (_) {}
        }
      } else if (Platform.isMacOS) {
        try {
          final res = await Process.run('ioreg', ['-rd1', '-c', 'IOPlatformExpertDevice']);
          final match = RegExp(r'"IOPlatformUUID"\s*=\s*"([^"]+)"').firstMatch(res.stdout.toString());
          motherboard = "APPLE_DEVICE";
          disk = match?.group(1)?.toUpperCase() ?? "MAC_UUID";
        } catch (_) {
          motherboard = "APPLE_DEVICE";
          disk = "MAC_DEFAULT";
        }
      } else if (Platform.isLinux) {
        try {
          final machineIdFile = File('/etc/machine-id');
          if (await machineIdFile.exists()) {
            final id = (await machineIdFile.readAsString()).trim();
            motherboard = "LINUX_SYS";
            disk = id.toUpperCase();
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error getting hardware info: $e');
    }

    // Combine board and disk to produce a deterministic 16-character Machine ID
    final combinedRaw = "MB:${motherboard.trim()}|DISK:${disk.trim()}";
    final md5Digest = md5.convert(utf8.encode(combinedRaw)).toString().toUpperCase();
    final cleanMachineId = "${md5Digest.substring(0, 4)}-${md5Digest.substring(4, 8)}-${md5Digest.substring(8, 12)}-${md5Digest.substring(12, 16)}";

    _cachedHardwareInfo = HardwareInfo(
      motherboardSerial: motherboard,
      diskSerial: disk,
      machineId: cleanMachineId,
    );

    return _cachedHardwareInfo!;
  }

  /// Generates the official activation key for a given machine ID using HMAC-SHA256
  static String generateActivationKey(String machineId) {
    final cleanId = machineId.trim().toUpperCase().replaceAll('-', '').replaceAll(' ', '');
    final keyBytes = utf8.encode(_secretMasterKey);
    final idBytes = utf8.encode(cleanId);

    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(idBytes);

    // Format as XXXX-XXXX-XXXX-XXXX
    final hexString = digest.toString().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final sub = hexString.substring(0, 16);
    return "${sub.substring(0, 4)}-${sub.substring(4, 8)}-${sub.substring(8, 12)}-${sub.substring(12, 16)}";
  }

  /// Validates an entered activation key against current hardware
  static Future<bool> verifyEnteredKey(String enteredKey) async {
    final hw = await getHardwareInfo();
    final cleanEntered = enteredKey.trim().toUpperCase().replaceAll('-', '').replaceAll(' ', '');
    final expectedKey = generateActivationKey(hw.machineId).replaceAll('-', '');
    return cleanEntered == expectedKey;
  }

  /// Evaluates full license status (Activated, Trial, Expired, Invoices count)
  static Future<LicenseStatus> checkStatus() async {
    try {
      final db = DatabaseHelper.instance;
      final licenseRecord = await db.getLicenseRecord();
      final totalInvoices = await db.getTotalOrdersCount();

      DateTime now = DateTime.now();

      if (licenseRecord == null) {
        // First run -> initialize
        await db.initLicenseRecord(now.toIso8601String());
        return LicenseStatus(
          isActivated: false,
          isTrial: true,
          isTrialExpired: false,
          totalInvoices: totalInvoices,
          maxTrialInvoices: maxTrialInvoices,
          daysRemaining: maxTrialDays,
        );
      }

      final isActivatedInDb = (licenseRecord['is_activated'] as int? ?? 0) == 1;
      final activationKey = licenseRecord['activation_key'] as String?;

      // If activated, perform cryptographic verification
      if (isActivatedInDb && activationKey != null && activationKey.isNotEmpty) {
        final isValid = await verifyEnteredKey(activationKey);
        if (isValid) {
          return LicenseStatus(
            isActivated: true,
            isTrial: false,
            isTrialExpired: false,
            totalInvoices: totalInvoices,
            maxTrialInvoices: maxTrialInvoices,
            daysRemaining: 9999,
          );
        }
      }

      // Not activated -> Check trial constraints
      DateTime firstRun = DateTime.tryParse(licenseRecord['first_run_date'] as String? ?? '') ?? now;
      final elapsedDays = now.difference(firstRun).inDays;
      final daysRemaining = maxTrialDays - elapsedDays;

      // Clock tampering detection (if current time is earlier than last recorded check)
      DateTime? lastChecked;
      if (licenseRecord['last_checked_date'] != null) {
        lastChecked = DateTime.tryParse(licenseRecord['last_checked_date'] as String);
      }
      bool clockTampered = false;
      if (lastChecked != null && now.isBefore(lastChecked.subtract(const Duration(hours: 1)))) {
        clockTampered = true;
      } else {
        await db.updateLastCheckedDate(now.toIso8601String());
      }

      bool isExpired = false;
      String? reason;

      if (clockTampered) {
        isExpired = true;
        reason = "تم اكتشاف تغيير في توقيت النظام. يرجى تفعيل البرنامج.";
      } else if (daysRemaining <= 0) {
        isExpired = true;
        reason = "انتهت فترة التجربة المجانية (30 يوم). يرجى شراء وتفعيل البرنامج.";
      } else if (totalInvoices >= maxTrialInvoices) {
        isExpired = true;
        reason = "لقد وصلت إلى الحد الأقصى للفواتير التجريبية ($maxTrialInvoices فواتير).";
      }

      return LicenseStatus(
        isActivated: false,
        isTrial: true,
        isTrialExpired: isExpired,
        totalInvoices: totalInvoices,
        maxTrialInvoices: maxTrialInvoices,
        daysRemaining: daysRemaining < 0 ? 0 : daysRemaining,
        expirationReason: reason,
      );
    } catch (e) {
      debugPrint('Error checking license status: $e');
      return LicenseStatus(
        isActivated: false,
        isTrial: true,
        isTrialExpired: false,
        totalInvoices: 0,
        daysRemaining: maxTrialDays,
      );
    }
  }

  /// Saves valid activation key in database
  static Future<bool> activate(String key) async {
    final isValid = await verifyEnteredKey(key);
    if (!isValid) return false;

    final formattedKey = key.trim().toUpperCase();
    await DatabaseHelper.instance.updateLicenseActivation(formattedKey, 1);
    return true;
  }

  /// Builds WhatsApp URL to request activation code directly from developer
  static Future<String> getWhatsAppPurchaseUrl() async {
    final hw = await getHardwareInfo();
    final message = '''
السلام عليكم ورحمة الله،
أرغب في شراء وتفعيل نظام إدارة المبيعات.

بيانات جهازي:
• رقم البوردة: ${hw.motherboardSerial}
• رقم الهارديسك: ${hw.diskSerial}
• كود الجهاز: ${hw.machineId}
''';

    final encoded = Uri.encodeComponent(message);
    return "https://wa.me/$developerWhatsApp?text=$encoded";
  }
}
