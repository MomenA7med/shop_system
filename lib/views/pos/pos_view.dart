import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/pos_provider.dart';
import 'widgets/cart_panel.dart';
import 'widgets/supermarket_invoice_table.dart';

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
          // 1. Center & Main Supermarket Invoice & Scanner Area
          Expanded(
            child: SupermarketInvoiceTable(),
          ),

          // 2. Side Panel: Checkout, Keypad & Fast Payment
          CartPanel(),
        ],
      ),
    );
  }
}
