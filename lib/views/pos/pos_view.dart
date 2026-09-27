import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/pos_provider.dart';
import 'widgets/barcode_search_bar.dart';
import 'widgets/category_filter_bar.dart';
import 'widgets/product_card_grid.dart';
import 'widgets/cart_panel.dart';

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
          // Center & Main POS Catalog Section
          Expanded(
            child: Column(
              children: [
                // Top Search & Category Filters
                Container(
                  color: colors.surface,
                  child: Column(
                    children: [
                      const BarcodeSearchBar(),
                      Divider(color: colors.border, height: 1),
                      const CategoryFilterBar(),
                    ],
                  ),
                ),

                // Status snack/message
                if (pos.statusMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      pos.statusMessage!,
                      style: TextStyle(fontSize: 12, color: colors.primaryLight),
                    ),
                  ),

                // Product Cards Grid
                Expanded(
                  child: ProductCardGrid(),
                ),
              ],
            ),
          ),

          // Left Side: Cart & Cashier Checkout
          CartPanel(),
        ],
      ),
    );
  }
}
