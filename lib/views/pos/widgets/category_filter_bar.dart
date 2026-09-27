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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // All category pill
          _buildCategoryChip(
            context: context,
            label: AppStrings.allCategories,
            isSelected: selectedId == null,
            onTap: () => pos.selectCategory(null),
          ),
          const SizedBox(width: 8),
          ...categories.map((cat) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _buildCategoryChip(
              context: context,
              label: cat.name,
              isSelected: selectedId == cat.id,
              onTap: () => pos.selectCategory(cat.id),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : colors.cardSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : colors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
