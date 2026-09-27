import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shift_provider.dart';

class DesktopHeader extends StatefulWidget {
  const DesktopHeader({super.key});

  @override
  State<DesktopHeader> createState() => _DesktopHeaderState();
}

class _DesktopHeaderState extends State<DesktopHeader> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = context.watch<AuthProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;
    final shift = context.watch<ShiftProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 950;
        final isVeryCompact = constraints.maxWidth < 750;

        return Container(
          height: 58,
          padding: EdgeInsets.symmetric(horizontal: isVeryCompact ? 10 : 18),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.border, width: 1)),
          ),
          child: Row(
            children: [
              // Store Branding & Logo Placeholder Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 18),
                    if (!isVeryCompact) ...[
                      const SizedBox(width: 8),
                      Text(
                        settings.storeName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: colors.primaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Shift Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: shift.hasActiveShift
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: shift.hasActiveShift ? AppColors.success : AppColors.warning,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      shift.hasActiveShift ? Icons.check_circle_outline : Icons.pause_circle_outline,
                      color: shift.hasActiveShift ? AppColors.success : AppColors.warning,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shift.hasActiveShift
                          ? (isCompact ? '#${shift.activeShift?.id}' : 'الوردية مفتوحة (#${shift.activeShift?.id})')
                          : (isCompact ? 'مغلقة' : 'لا توجد وردية مفتوحة'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: shift.hasActiveShift ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Live Clock & Date (Hidden on very compact screens to avoid overcrowding)
              if (!isCompact) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 14, color: colors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      DateFormatter.formatDateTime(_currentTime),
                      style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ] else if (!isVeryCompact) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 14, color: colors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
              ],

              // Quick Theme Toggle (Light / Dark Mode)
              Tooltip(
                message: isDark ? 'التبديل إلى الوضع النهاري (Light Mode)' : 'التبديل إلى الوضع الليلي (Dark Mode)',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    settingsProvider.toggleTheme();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.cardSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            key: ValueKey(isDark),
                            size: 15,
                            color: isDark ? const Color(0xFFFBBF24) : AppColors.secondary,
                          ),
                        ),
                        if (!isVeryCompact) ...[
                          const SizedBox(width: 5),
                          Text(
                            isDark ? 'نهاري' : 'ليلي',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // User Profile & Role
              if (auth.currentUser != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: auth.isAdmin ? AppColors.secondary : AppColors.primary,
                      child: Text(
                        auth.currentUser!.name.substring(0, 1),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.currentUser!.name,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors.textPrimary),
                          ),
                          Text(
                            auth.isAdmin ? 'مدير' : 'كاشير',
                            style: TextStyle(
                              fontSize: 9,
                              color: auth.isAdmin ? AppColors.secondary : colors.primaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                    IconButton(
                      tooltip: 'تسجيل الخروج',
                      icon: Icon(Icons.logout, size: 17, color: colors.textMuted),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        auth.logout();
                      },
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
