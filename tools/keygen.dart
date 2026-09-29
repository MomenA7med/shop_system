// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main(List<String> args) {
  const secretMasterKey = "SHOP_POS_MOMEN_AHMED_2026_@#!99";

  print("=================================================");
  print("   🔑 أداة توليد كود شراء نظام إدارة المبيعات");
  print("   المطور: م / مؤمن أحمد محمد (01003779702)");
  print("=================================================\n");

  String machineId = "";

  if (args.isNotEmpty) {
    machineId = args.join(" ").trim();
  } else {
    stdout.write("👉 أدخل كود الجهاز (Machine ID) الخاص بالعميل: ");
    final line = stdin.readLineSync();
    if (line != null) {
      machineId = line.trim();
    }
  }

  if (machineId.isEmpty) {
    print("❌ خطأ: كود الجهاز فارغ! يرجى إدخال كود الجهاز.");
    return;
  }

  final cleanId = machineId.trim().toUpperCase().replaceAll('-', '').replaceAll(' ', '');
  final keyBytes = utf8.encode(secretMasterKey);
  final idBytes = utf8.encode(cleanId);

  final hmac = Hmac(sha256, keyBytes);
  final digest = hmac.convert(idBytes);

  final hexString = digest.toString().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final sub = hexString.substring(0, 16);
  final finalKey = "${sub.substring(0, 4)}-${sub.substring(4, 8)}-${sub.substring(8, 12)}-${sub.substring(12, 16)}";

  print("\n-------------------------------------------------");
  print("✅ كود التفعيل المخصص لهذا الجهاز هو:");
  print("👉  $finalKey");
  print("-------------------------------------------------");
  print("قم بنسخ هذا الكود وإرساله للعميل عبر الواتساب.\n");
}
