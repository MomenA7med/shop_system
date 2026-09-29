import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../providers/pos_provider.dart';

class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<POSProvider>();
    final categories = pos.categories;
    final selectedId = pos.selectedCategoryId;

    final isQuick = pos.isQuickFilterOnly;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 1. Quick Items chip
          _buildCategoryChip(
            context: context,
            icon: Icons.flash_on_rounded,
            label: 'الأصناف السريعة',
            isSelected: isQuick,
            onTap: () => pos.selectQuickFilter(),
            badgeCount: pos.quickProducts.length,
          ),
          const SizedBox(width: 8),

          // 2. All Categories chip
          _buildCategoryChip(
            context: context,
            icon: Icons.apps_rounded,
            label: AppStrings.allCategories,
            isSelected: !isQuick && selectedId == null,
            onTap: () => pos.selectCategory(null),
          ),
          const SizedBox(width: 8),

          // 3. Category chips
          ...categories.map((cat) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _buildCategoryChip(
              context: context,
              label: cat.name,
              isSelected: !isQuick && selectedId == cat.id,
              onTap: () => pos.selectCategory(cat.id),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    IconData? icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : colors.cardSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : (icon == Icons.flash_on_rounded ? Colors.amber : colors.textSecondary),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : colors.textSecondary,
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
