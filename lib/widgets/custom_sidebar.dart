import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';

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

    final navItems = [
      {'icon': Icons.point_of_sale_rounded, 'label': AppStrings.navPOS, 'adminOnly': false},
      {'icon': Icons.receipt_long_rounded, 'label': AppStrings.navInvoices, 'adminOnly': false},
      {'icon': Icons.inventory_2_rounded, 'label': AppStrings.navInventory, 'adminOnly': false},
      {'icon': Icons.assignment_return_rounded, 'label': AppStrings.navReturns, 'adminOnly': false},
      {'icon': Icons.access_time_filled_rounded, 'label': AppStrings.navShifts, 'adminOnly': false},
      {'icon': Icons.bar_chart_rounded, 'label': AppStrings.navReports, 'adminOnly': true},
      {'icon': Icons.settings_suggest_rounded, 'label': AppStrings.navSettings, 'adminOnly': true},
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.checkroom_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كاشير الأزياء',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'نظام إدارة ونقاط البيع',
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.textMuted,
                        ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
                              : Border.all(color: Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 20,
                              color: isLocked
                                  ? colors.textMuted.withValues(alpha: 0.5)
                                  : (isSelected ? colors.primaryLight : colors.textSecondary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item['label'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isLocked
                                      ? colors.textMuted.withValues(alpha: 0.5)
                                      : (isSelected ? colors.textPrimary : colors.textSecondary),
                                ),
                              ),
                            ),
                            if (isLocked)
                              Icon(Icons.lock_outline, size: 14, color: colors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer version tag
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'الإصدار 1.0.0 (Desktop)',
              style: TextStyle(fontSize: 10, color: colors.textMuted.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}
