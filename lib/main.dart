import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_strings.dart';
import 'core/constants/app_styles.dart';
import 'core/database/database_helper.dart';
import 'providers/auth_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/invoices_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/returns_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/shift_provider.dart';
import 'views/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress Flutter Desktop hardware keyboard sync assertion bug in debug mode
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exception.toString();
    if (message.contains('hardware_keyboard.dart') ||
        message.contains('_pressedKeys.containsKey') ||
        message.contains('KeyDownEvent is dispatched, but the state shows that the physical key is already pressed')) {
      // Ignored: Known platform duplicate key-down assertion on macOS/desktop
      return;
    }
    FlutterError.presentError(details);
  };

  // Initialize SQLite FFI for macOS and Windows Desktop
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Pre-initialize database
  await DatabaseHelper.instance.database;

  runApp(const ClothingStoreApp());
}

class ClothingStoreApp extends StatelessWidget {
  const ClothingStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
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
