import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/number_parser.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pos_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/shift_provider.dart';
import 'receipt_preview_modal.dart';

class CartPanel extends StatefulWidget {
  const CartPanel({super.key});

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  final TextEditingController _paidCtrl = TextEditingController();
  final FocusNode _paidFocusNode = FocusNode();
  final TextEditingController _discountCtrl = TextEditingController();
  final FocusNode _discountFocusNode = FocusNode();
  double _lastGrandTotal = 0.0;
  double _lastDiscount = 0.0;

  @override
  void dispose() {
    _paidCtrl.dispose();
    _paidFocusNode.dispose();
    _discountCtrl.dispose();
    _discountFocusNode.dispose();
    super.dispose();
  }

  void _syncPaidAmount(POSProvider pos) {
    if (pos.cartItems.isEmpty) {
      if (_paidCtrl.text.isNotEmpty) {
        _paidCtrl.clear();
      }
      if (_discountCtrl.text.isNotEmpty) {
        _discountCtrl.clear();
      }
      _lastGrandTotal = 0.0;
      _lastDiscount = 0.0;
      return;
    }

    // Sync discount input only if not currently focused by user
    if (!_discountFocusNode.hasFocus) {
      if (_lastDiscount != pos.discount) {
        _lastDiscount = pos.discount;
        final formatted = pos.discount > 0
            ? (pos.discount % 1 == 0
                  ? pos.discount.toInt().toString()
                  : pos.discount.toStringAsFixed(2))
            : '';
        if (_discountCtrl.text != formatted) {
          _discountCtrl.text = formatted;
        }
      }
    }

    // Sync paid amount input only if not currently focused by user
    if (!_paidFocusNode.hasFocus) {
      if (_lastGrandTotal != pos.grandTotal ||
          pos.amountPaid == pos.grandTotal) {
        _lastGrandTotal = pos.grandTotal;
        final formatted = pos.grandTotal > 0
            ? (pos.grandTotal % 1 == 0
                  ? pos.grandTotal.toInt().toString()
                  : pos.grandTotal.toStringAsFixed(2))
            : '';
        if (_paidCtrl.text != formatted) {
          _paidCtrl.text = formatted;
        }
      }
    }
  }

  Future<void> _handleCheckout({required bool saveAndPrint}) async {
    final pos = context.read<POSProvider>();
    final auth = context.read<AuthProvider>();
    final shift = context.read<ShiftProvider>();
    final settings = context.read<SettingsProvider>().settings;

    if (!pos.canCheckout) return;

    final cashierId = auth.currentUser?.id ?? 1;
    final shiftId = shift.activeShift?.id;

    final order = await pos.checkout(cashierId: cashierId, shiftId: shiftId);

    if (order != null && mounted) {
      // Reload active shift to reflect updated cash totals
      if (shift.activeShift != null) {
        await shift.checkActiveShift(cashierId);
      }

      if (saveAndPrint && mounted) {
        showDialog(
          context: context,
          builder: (_) => ReceiptPreviewModal(order: order, settings: settings),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تم حفظ الفاتورة #${order.invoiceNumber} بنجاح بدون طباعة',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pos = context.watch<POSProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final cartItems = pos.cartItems;

    _syncPaidAmount(pos);

    final screenWidth = MediaQuery.of(context).size.width;
    // Spacious comfortable panel width
    final panelWidth = screenWidth < 1100
        ? 390.0
        : (screenWidth < 1400 ? 430.0 : 460.0);

    return Container(
      width: panelWidth,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border, width: 1)),
      ),
      child: Column(
        children: [
          // 1. Cart Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${AppStrings.currentOrder} (${cartItems.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (cartItems.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text(
                      'مسح السلة',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      pos.clearCart();
                      _paidCtrl.clear();
                      _discountCtrl.clear();
                    },
                  ),
              ],
            ),
          ),
          Divider(color: colors.border, height: 1),

          // 2. Cart Items List (Spacious & Clean Layout)
          Expanded(
            child: cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 54,
                          color: colors.textMuted.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            AppStrings.emptyCart,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.cardSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Line: Product Name + Top "X" Delete Icon
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.productName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: colors.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => pos.removeItem(index),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: colors.error.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 15,
                                      color: colors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Bottom Line: Specs/Price (Right) | Quantity Controls (Center) | Total (Left)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Specs badge & unit price
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${item.size} | ${item.color}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyFormatter.format(
                                        item.unitPrice,
                                        symbol: settings.currencySymbol,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),

                                // Quantity Controls
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 20,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      color: colors.textSecondary,
                                      onPressed: () =>
                                          pos.decrementQuantity(index),
                                    ),
                                    Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Text(
                                        '${item.quantity}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 20,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      color: colors.primary,
                                      onPressed: () =>
                                          pos.incrementQuantity(index),
                                    ),
                                  ],
                                ),

                                // Total Item Price
                                Text(
                                  CurrencyFormatter.format(
                                    item.totalPrice,
                                    symbol: settings.currencySymbol,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: colors.isDark
                                        ? colors.primaryLight
                                        : colors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          Divider(color: colors.border, height: 1),

          // 3. Payment & Totals Section with Discount & Side-by-Side Cash Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: colors.surface),
            child: Column(
              children: [
                // Subtotal row (if discount is applied)
                Visibility(
                  key: const ValueKey('subtotal_section'),
                  visible: pos.discount > 0,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.subtotal,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(
                            pos.subtotal,
                            symbol: settings.currencySymbol,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Grand Total Row
                Row(
                  key: const ValueKey('grand_total_section'),
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.grandTotal,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(
                        pos.grandTotal,
                        symbol: settings.currencySymbol,
                      ),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colors.isDark
                            ? colors.primaryLight
                            : colors.primaryDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 4. Discount Input Row (خانة الخصم)
                Row(
                  key: const ValueKey('discount_input_section'),
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.discount_outlined,
                          size: 16,
                          color: colors.warning,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'الخصم:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          key: const ValueKey('pos_discount_text_field'),
                          controller: _discountCtrl,
                          focusNode: _discountFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                settings.currencySymbol,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                            suffixIcon: Visibility(
                              visible: pos.discount > 0,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                onPressed: () {
                                  _discountCtrl.clear();
                                  _lastDiscount = 0.0;
                                  pos.setDiscount(0.0);
                                },
                              ),
                            ),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final parsed = NumberParser.tryParseDouble(
                              val,
                              0.0,
                            );
                            _lastDiscount = parsed;
                            pos.setDiscount(parsed);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 5. Cash Received (Side-by-Side Label & Large TextField)
                Row(
                  children: [
                    // Label & Exact Amount Button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المبلغ المستلم:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (pos.grandTotal > 0 &&
                            pos.amountPaid != pos.grandTotal) ...[
                          const SizedBox(height: 3),
                          InkWell(
                            onTap: () {
                              pos.setAmountPaid(pos.grandTotal);
                              _paidCtrl.text = pos.grandTotal % 1 == 0
                                  ? pos.grandTotal.toInt().toString()
                                  : pos.grandTotal.toStringAsFixed(2);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                AppStrings.exactAmount,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(width: 12),

                    // Large Prominent Input Field
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: _paidCtrl,
                          focusNode: _paidFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 0,
                            ),
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              color: colors.textMuted,
                              fontSize: 16,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                settings.currencySymbol,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final parsed = NumberParser.tryParseDouble(val);
                            _lastGrandTotal = pos.grandTotal;
                            pos.setAmountPaid(parsed);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 6. Change Due / Remaining Box (Full Width)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: pos.changeDue > 0
                        ? colors.info.withValues(alpha: 0.15)
                        : (pos.amountPaid < pos.grandTotal &&
                                  pos.cartItems.isNotEmpty
                              ? colors.warning.withValues(alpha: 0.12)
                              : colors.cardSurface),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: pos.changeDue > 0
                          ? colors.info
                          : (pos.amountPaid < pos.grandTotal &&
                                    pos.cartItems.isNotEmpty
                                ? colors.warning
                                : colors.border),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        pos.amountPaid < pos.grandTotal &&
                                pos.cartItems.isNotEmpty
                            ? 'المتبقي مطلوب تحصيله:'
                            : AppStrings.changeDue,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: pos.changeDue > 0
                              ? colors.info
                              : (pos.amountPaid < pos.grandTotal &&
                                        pos.cartItems.isNotEmpty
                                    ? colors.warning
                                    : colors.textSecondary),
                        ),
                      ),
                      Text(
                        pos.amountPaid < pos.grandTotal &&
                                pos.cartItems.isNotEmpty
                            ? CurrencyFormatter.format(
                                pos.grandTotal - pos.amountPaid,
                                symbol: settings.currencySymbol,
                              )
                            : CurrencyFormatter.format(
                                pos.changeDue,
                                symbol: settings.currencySymbol,
                              ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: pos.changeDue > 0
                              ? colors.info
                              : (pos.amountPaid < pos.grandTotal &&
                                        pos.cartItems.isNotEmpty
                                    ? colors.warning
                                    : colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 7. Dual Action Buttons: Save & Print vs Save Without Printing
                Row(
                  children: [
                    // Button 1: Save & Print
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pos.canCheckout
                                ? colors.primary
                                : colors.surfaceLight,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              AppStrings.saveAndPrint,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onPressed: pos.canCheckout
                              ? () => _handleCheckout(saveAndPrint: true)
                              : null,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Button 2: Save Without Printing
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pos.canCheckout
                                ? (colors.isDark
                                      ? colors.cardSurface
                                      : colors.surfaceLight)
                                : colors.surfaceLight,
                            foregroundColor: pos.canCheckout
                                ? colors.textPrimary
                                : colors.textMuted,
                            side: BorderSide(
                              color: pos.canCheckout
                                  ? colors.primary
                                  : colors.border,
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            elevation: 0,
                          ),
                          icon: Icon(
                            Icons.save_outlined,
                            size: 18,
                            color: pos.canCheckout
                                ? colors.primary
                                : colors.textMuted,
                          ),
                          label: Text(
                            AppStrings.saveWithoutPrint,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: pos.canCheckout
                                  ? colors.textPrimary
                                  : colors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: pos.canCheckout
                              ? () => _handleCheckout(saveAndPrint: false)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
