import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class BackupService {
  /// Export backup database file to user selected path
  static Future<String?> exportBackup() async {
    final dbPath = await DatabaseHelper.instance.getDatabasePath();
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('قاعدة البيانات غير موجودة');
    }

    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final defaultFileName = 'clothing_pos_backup_$dateStr.db';
    final bytes = await dbFile.readAsBytes();

    final saveUri = await FilePicker.saveFile(
      dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية (USB أو قرص محلي)',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['db'],
      bytes: bytes,
    );

    if (saveUri != null) {
      return saveUri.path;
    }
    return null;
  }

  /// Restore database from user selected backup file
  static Future<bool> restoreBackup() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'اختر ملف النسخة الاحتياطية (.db)',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final selectedFile = File(files.first.path!);
      if (!await selectedFile.exists()) {
        throw Exception('الملف المحدد غير موجود');
      }

      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      
      // Copy over existing database
      await selectedFile.copy(dbPath);
      return true;
    }
    return false;
  }
}
