import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_styles.dart';
import 'core/database/database_helper.dart';
import 'core/services/app_info_service.dart';
import 'core/services/print_service.dart';
import 'models/store_settings_model.dart';
import 'providers/auth_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/invoices_provider.dart';
import 'providers/license_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/returns_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/shift_provider.dart';
import 'views/main_layout.dart';

/// Helper to log fatal startup exceptions to a local text file
void _logCrash(String text) {
  try {
    final timestamp = DateTime.now().toIso8601String();
    final logFile = File('crash_log.txt');
    logFile.writeAsStringSync('[$timestamp] $text\n\n', mode: FileMode.append);
  } catch (_) {}
}

/// Initialize SQLite FFI for desktop platforms
void _setupSqliteFfi() {
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress Flutter Desktop hardware keyboard sync assertion bug in debug mode
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exception.toString();
    if (message.contains('hardware_keyboard.dart') ||
        message.contains('_pressedKeys.containsKey') ||
        message.contains(
          'KeyDownEvent is dispatched, but the state shows that the physical key is already pressed',
        )) {
      // Ignored: Known platform duplicate key-down assertion on macOS/desktop
      return;
    }
    _logCrash('FlutterError: $message\n${details.stack}');
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _logCrash('PlatformDispatcher Error: $error\n$stack');
    return true;
  };

  String? startupError;
  StoreSettingsModel? initialSettings;

  try {
    await AppInfoService.init();
    _setupSqliteFfi();

    // Pre-initialize database & schema migrations
    await DatabaseHelper.instance.database;
    await DatabaseHelper.instance.ensureSchemaMigrations();

    // Warm up PDF fonts in the background so receipt printing is instant and non-blocking
    PrintService.warmUpFonts();

    // Pre-load store settings to establish theme before first frame renders
    try {
      initialSettings = await DatabaseHelper.instance.getStoreSettings();
    } catch (e) {
      debugPrint('Error preloading settings: $e');
    }
  } catch (e, stack) {
    startupError = e.toString();
    _logCrash('Fatal Startup Error: $e\n$stack');
  }

  runApp(ClothingStoreApp(
    initialSettings: initialSettings,
    startupError: startupError,
  ));
}

class ClothingStoreApp extends StatelessWidget {
  final StoreSettingsModel? initialSettings;
  final String? startupError;

  const ClothingStoreApp({
    super.key,
    this.initialSettings,
    this.startupError,
  });

  @override
  Widget build(BuildContext context) {
    if (startupError != null) {
      return MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppStyles.darkTheme,
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: _StartupErrorView(error: startupError!),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LicenseProvider()),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(initialSettings: initialSettings),
        ),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => POSProvider()),
        ChangeNotifierProvider(create: (_) => ShiftProvider()),
        ChangeNotifierProvider(create: (_) => ReturnsProvider()),
        ChangeNotifierProvider(create: (_) => InvoicesProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppStyles.lightTheme,
            darkTheme: AppStyles.darkTheme,
            themeMode: settingsProvider.themeMode,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [
              Locale('ar', 'EG'),
              Locale('ar', 'SA'),
              Locale('ar', 'AE'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MainLayout(),
          );
        },
      ),
    );
  }
}

class _StartupErrorView extends StatelessWidget {
  final String error;

  const _StartupErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'تعذر بدء تشغيل قاعدة البيانات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'حدث خطأ أثناء تحميل مكتبات النظام أو قاعدة البيانات المحلية. يرجى التأكد من تثبيت حزمة Visual C++ Redistributable أو وجود ملف sqlite3.dll بجوار البرنامج.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: SelectableText(
                  error,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  exit(0);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
