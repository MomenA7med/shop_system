import 'package:flutter/material.dart';

class AppColors {
  // Static Shared Brand Accents
  static const Color primary = Color(0xFF10B981); // Emerald Teal
  static const Color primaryLight = Color(0xFF34D399);
  static const Color primaryDark = Color(0xFF059669);

  static const Color secondary = Color(0xFF6366F1); // Indigo
  static const Color accent = Color(0xFF06B6D4); // Cyan

  // Status & Badges
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color actionDanger = Color(0xFFDC2626);

  // Dark Surface & Background Constants
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkCardSurface = Color(0xFF243044); // Elevated slate
  static const Color darkSurfaceLight = Color(0xFF334155); // Slate 700
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);
  static const Color darkKeypadButton = Color(0xFF2A374D);
  static const Color darkKeypadButtonHover = Color(0xFF3B4D6B);

  // Light Surface & Background Constants
  static const Color lightBackground = Color(0xFFF1F5F9); // Slate 100
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure White
  static const Color lightCardSurface = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurfaceLight = Color(0xFFE2E8F0); // Slate 200
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF475569); // Slate 600
  static const Color lightTextMuted = Color(0xFF94A3B8); // Slate 400
  static const Color lightKeypadButton = Color(0xFFF1F5F9);
  static const Color lightKeypadButtonHover = Color(0xFFE2E8F0);

  // Fallback / legacy static accessors (default to dark)
  static const Color background = darkBackground;
  static const Color surface = darkSurface;
  static const Color cardSurface = darkCardSurface;
  static const Color surfaceLight = darkSurfaceLight;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextMuted;
  static const Color keypadButton = darkKeypadButton;
  static const Color keypadButtonHover = darkKeypadButtonHover;
  static const Color border = darkBorder;

  /// Dynamic accessor that resolves colors according to current context / theme mode
  static AppColorsExtension of(BuildContext context) {
    return Theme.of(context).extension<AppColorsExtension>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppColorsExtension.dark
            : AppColorsExtension.light);
  }
}

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color background;
  final Color surface;
  final Color cardSurface;
  final Color surfaceLight;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color keypadButton;
  final Color keypadButtonHover;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color secondary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color actionDanger;
  final bool isDark;

  const AppColorsExtension({
    required this.background,
    required this.surface,
    required this.cardSurface,
    required this.surfaceLight,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.keypadButton,
    required this.keypadButtonHover,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.actionDanger,
    required this.isDark,
  });

  static const dark = AppColorsExtension(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    cardSurface: AppColors.darkCardSurface,
    surfaceLight: AppColors.darkSurfaceLight,
    border: AppColors.darkBorder,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    keypadButton: AppColors.darkKeypadButton,
    keypadButtonHover: AppColors.darkKeypadButtonHover,
    primary: AppColors.primary,
    primaryLight: AppColors.primaryLight,
    primaryDark: AppColors.primaryDark,
    secondary: AppColors.secondary,
    accent: AppColors.accent,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    info: AppColors.info,
    actionDanger: AppColors.actionDanger,
    isDark: true,
  );

  static const light = AppColorsExtension(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    cardSurface: AppColors.lightCardSurface,
    surfaceLight: AppColors.lightSurfaceLight,
    border: AppColors.lightBorder,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    keypadButton: AppColors.lightKeypadButton,
    keypadButtonHover: AppColors.lightKeypadButtonHover,
    primary: AppColors.primary,
    primaryLight: AppColors.primaryDark,
    primaryDark: AppColors.primaryDark,
    secondary: Color(0xFF4F46E5),
    accent: Color(0xFF0891B2),
    success: AppColors.success,
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
    actionDanger: AppColors.actionDanger,
    isDark: false,
  );

  @override
  AppColorsExtension copyWith({
    Color? background,
    Color? surface,
    Color? cardSurface,
    Color? surfaceLight,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? keypadButton,
    Color? keypadButtonHover,
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? secondary,
    Color? accent,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? actionDanger,
    bool? isDark,
  }) {
    return AppColorsExtension(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      cardSurface: cardSurface ?? this.cardSurface,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      keypadButton: keypadButton ?? this.keypadButton,
      keypadButtonHover: keypadButtonHover ?? this.keypadButtonHover,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      actionDanger: actionDanger ?? this.actionDanger,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      keypadButton: Color.lerp(keypadButton, other.keypadButton, t)!,
      keypadButtonHover: Color.lerp(keypadButtonHover, other.keypadButtonHover, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      actionDanger: Color.lerp(actionDanger, other.actionDanger, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension AppThemeContextExtension on BuildContext {
  AppColorsExtension get colors => AppColors.of(this);
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

