import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/services/app_info_service.dart';
import '../providers/auth_provider.dart';
import '../providers/license_provider.dart';
import '../providers/settings_provider.dart';
import '../views/license/activation_dialog.dart';

class CustomSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const CustomSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final settings = context.watch<SettingsProvider>().settings;
    final hasLogo =
        settings.logoPath != null && File(settings.logoPath!).existsSync();

    final navItems = [
      {
        'icon': Icons.point_of_sale_rounded,
        'label': AppStrings.navPOS,
        'adminOnly': false,
      },
      {
        'icon': Icons.receipt_long_rounded,
        'label': AppStrings.navInvoices,
        'adminOnly': false,
      },
      {
        'icon': Icons.inventory_2_rounded,
        'label': AppStrings.navInventory,
        'adminOnly': false,
      },
      {
        'icon': Icons.assignment_return_rounded,
        'label': AppStrings.navReturns,
        'adminOnly': false,
      },
      {
        'icon': Icons.access_time_filled_rounded,
        'label': AppStrings.navShifts,
        'adminOnly': false,
      },
      {
        'icon': Icons.bar_chart_rounded,
        'label': AppStrings.navReports,
        'adminOnly': true,
      },
      {
        'icon': Icons.settings_suggest_rounded,
        'label': AppStrings.navSettings,
        'adminOnly': true,
      },
    ];

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: colors.border, width: 1)),
      ),
      child: Column(
        children: [
          // App Logo / Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  padding: EdgeInsets.all(hasLogo ? 2 : 8),
                  decoration: BoxDecoration(
                    gradient: hasLogo
                        ? null
                        : const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                    color: hasLogo ? colors.cardSurface : null,
                    borderRadius: BorderRadius.circular(10),
                    border: hasLogo ? Border.all(color: colors.border) : null,
                  ),
                  child: hasLogo
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(settings.logoPath!),
                            width: 34,
                            height: 34,
                            fit: BoxFit.contain,
                          ),
                        )
                      : const Icon(
                          Icons.shopping_cart_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.storeName.isNotEmpty
                            ? settings.storeName
                            : 'كاشير السوبر ماركت',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        settings.slogan.isNotEmpty
                            ? settings.slogan
                            : 'نظام إدارة ونقاط بيع السوبر ماركت',
                        style: TextStyle(fontSize: 10, color: colors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(),
          const SizedBox(height: 8),

          // Navigation Links
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = selectedIndex == index;
                final isLocked = (item['adminOnly'] as bool) && !isAdmin;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (isLocked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(AppStrings.unauthorizedAccess),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        onDestinationSelected(index);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                )
                              : Border.all(color: Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 20,
                              color: isLocked
                                  ? colors.textMuted.withValues(alpha: 0.5)
                                  : (isSelected
                                        ? colors.primaryLight
                                        : colors.textSecondary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item['label'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isLocked
                                      ? colors.textMuted.withValues(alpha: 0.5)
                                      : (isSelected
                                            ? colors.textPrimary
                                            : colors.textSecondary),
                                ),
                              ),
                            ),
                            if (isLocked)
                              Icon(
                                Icons.lock_outline,
                                size: 14,
                                color: colors.textMuted,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // License / Activation Section
          Consumer<LicenseProvider>(
            builder: (context, license, _) {
              final isActivated = license.isActivated;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      ActivationDialog.show(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isActivated
                            ? LinearGradient(
                                colors: [
                                  Colors.teal.shade800.withValues(alpha: 0.15),
                                  Colors.green.shade800.withValues(alpha: 0.1),
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.amber.shade700.withValues(alpha: 0.2),
                                  Colors.orange.shade800.withValues(alpha: 0.15),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActivated
                              ? Colors.green.withValues(alpha: 0.4)
                              : Colors.amber.shade700.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isActivated ? Icons.verified_rounded : Icons.shopping_bag_outlined,
                            size: 20,
                            color: isActivated ? Colors.green : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isActivated ? 'النسخة مفعلة' : 'شراء وتفعيل النظام',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isActivated ? Colors.green : Colors.amber.shade900,
                                  ),
                                ),
                                if (!isActivated)
                                  Text(
                                    'متبقي ${license.remainingInvoices} فواتير / ${license.daysRemaining} يوم',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: isActivated ? Colors.green : Colors.amber.shade800,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Logout Action Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  context.read<AuthProvider>().logout();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppStrings.navLogout,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const Divider(),

          // Developer Credit Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border.withValues(alpha: 0.8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.engineering_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'برمجة وتطوير:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'م / مؤمن أحمد محمد',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '📱 01003779702',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryLight,
                  ),
                ),
              ],
            ),
          ),

          // Footer version tag
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 2),
            child: Text(
              AppInfoService.displayVersion,
              style: TextStyle(
                fontSize: 9,
                color: colors.textMuted.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
