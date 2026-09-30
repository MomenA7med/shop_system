import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/pos_provider.dart';
import 'widgets/barcode_search_bar.dart';
import 'widgets/cart_panel.dart';
import 'widgets/product_card_grid.dart';

class POSView extends StatefulWidget {
  const POSView({super.key});

  @override
  State<POSView> createState() => _POSViewState();
}

class _POSViewState extends State<POSView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<POSProvider>().loadPOSData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pos = context.watch<POSProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        children: [
          // 1. Main & Wide Right Area: Scanner Search Bar, Title Header and Full-Screen Quick Items Grid
          Expanded(
            child: Column(
              children: [
                const BarcodeSearchBar(),
                // Dynamic Title Header Bar (Search Results vs Quick Items)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: pos.searchQuery.isNotEmpty
                              ? colors.primary.withValues(alpha: 0.18)
                              : Colors.amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          pos.searchQuery.isNotEmpty
                              ? Icons.search_rounded
                              : Icons.flash_on_rounded,
                          color: pos.searchQuery.isNotEmpty
                              ? colors.primary
                              : Colors.amber,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pos.searchQuery.isNotEmpty
                            ? 'نتائج البحث عن: "${pos.searchQuery}"'
                            : 'الأصناف السريعة',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (pos.searchQuery.isNotEmpty
                                  ? colors.primary
                                  : AppColors.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          pos.searchQuery.isNotEmpty
                              ? '${pos.products.length} صنف مطابق'
                              : '${pos.quickProducts.length} صنف',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (pos.searchQuery.isNotEmpty)
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => pos.clearSearch(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: colors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'إلغاء البحث والعودة',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          'إضافة فورية للفاتورة بضغطة واحدة',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                const Expanded(child: ProductCardGrid()),
              ],
            ),
          ),

          // 2. Side Panel (Left): Classic Invoice / Cart with Item List & Fast Payment Cockpit
          const CartPanel(),
        ],
      ),
    );
  }
}
