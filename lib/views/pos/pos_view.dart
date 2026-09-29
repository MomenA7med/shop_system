import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/pos_provider.dart';
import 'widgets/barcode_search_bar.dart';
import 'widgets/category_filter_bar.dart';
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

    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        children: const [
          // 1. Main & Wide Right Area: Scanner Search Bar, Category/Quick Filters, and Full-Screen Cards Grid
          Expanded(
            child: Column(
              children: [
                BarcodeSearchBar(),
                CategoryFilterBar(),
                Expanded(
                  child: ProductCardGrid(),
                ),
              ],
            ),
          ),

          // 2. Side Panel (Left): Classic Invoice / Cart with Item List & Fast Payment Cockpit
          CartPanel(),
        ],
      ),
    );
  }
}
