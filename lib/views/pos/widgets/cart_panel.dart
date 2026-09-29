import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/number_parser.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/invoices_provider.dart';
import '../../../providers/pos_provider.dart';
import '../../../providers/license_provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/shift_provider.dart';
import '../../license/activation_dialog.dart';
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
  double _lastAmountPaid = -1.0;
  double _lastDiscount = -1.0;

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
      _lastAmountPaid = 0.0;
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
      if (_lastAmountPaid != pos.amountPaid) {
        _lastAmountPaid = pos.amountPaid;
        final formatted = pos.amountPaid > 0
            ? (pos.amountPaid % 1 == 0
                  ? pos.amountPaid.toInt().toString()
                  : pos.amountPaid.toStringAsFixed(2))
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
    final invoices = context.read<InvoicesProvider>();
    final reports = context.read<ReportsProvider>();
    final inventory = context.read<InventoryProvider>();

    if (!pos.canCheckout) return;

    final license = context.read<LicenseProvider>();
    if (!license.isActivated && (license.isTrialExpired || license.totalInvoices >= license.maxTrialInvoices)) {
      ActivationDialog.show(
        context,
        reason: license.status?.expirationReason ?? 'لقد وصلت إلى الحد الأقصى للنسخة التجريبية (5 فواتير).',
      );
      return;
    }

    final cashierId = auth.currentUser?.id ?? 1;
    final shiftId = shift.activeShift?.id;

    final order = await pos.checkout(cashierId: cashierId, shiftId: shiftId);

    if (order != null && mounted) {
      // 1. Refresh license statistics (e.g. remaining invoices)
      license.refresh();

      // 2. Reload active shift to reflect updated cash totals
      if (shift.activeShift != null) {
        await shift.checkActiveShift(cashierId);
      }

      // 3. Automatically refresh Invoices, Reports, and Inventory in background
      invoices.loadInvoices();
      reports.loadReports();
      inventory.loadInventory();

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
                      width: 32,
                      height: 32,
                      padding: EdgeInsets.all(settings.logoPath != null && File(settings.logoPath!).existsSync() ? 2 : 6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: settings.logoPath != null && File(settings.logoPath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(settings.logoPath!),
                                width: 26,
                                height: 26,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Icon(
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
          // 2. Checkout Dashboard & Payment Cockpit
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Grand Total Hero Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary.withValues(alpha: 0.15),
                          colors.primary.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppStrings.grandTotal,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.textSecondary,
                              ),
                            ),
                            if (pos.discount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.warning.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'خصم: ${CurrencyFormatter.format(pos.discount, symbol: settings.currencySymbol)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors.warning,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.format(
                              pos.grandTotal,
                              symbol: settings.currencySymbol,
                            ),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: colors.isDark
                                  ? colors.primaryLight
                                  : colors.primaryDark,
                            ),
                          ),
                        ),
                        if (pos.discount > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'المجموع قبل الخصم: ${CurrencyFormatter.format(pos.subtotal, symbol: settings.currencySymbol)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Cash Addition Chips
                  if (cartItems.isNotEmpty) ...[
                    Text(
                      'إضافة سريعة للمبلغ المستلم:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickCashChip('+5 ج', 5, pos),
                        _buildQuickCashChip('+10 ج', 10, pos),
                        _buildQuickCashChip('+20 ج', 20, pos),
                        _buildQuickCashChip('+50 ج', 50, pos),
                        _buildQuickCashChip('+100 ج', 100, pos),
                        _buildQuickCashChip('+200 ج', 200, pos),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
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

                // 4. Discount Input Row (خانة الخصم - كبيرة ومريحة)
                Row(
                  key: const ValueKey('discount_input_section'),
                  children: [
                    SizedBox(
                      width: 110,
                      child: Row(
                        children: [
                          Icon(
                            Icons.discount_outlined,
                            size: 18,
                            color: colors.warning,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'الخصم:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: TextField(
                          key: const ValueKey('pos_discount_text_field'),
                          controller: _discountCtrl,
                          focusNode: _discountFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          textAlign: TextAlign.left,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              color: colors.textMuted,
                              fontSize: 14,
                            ),
                            prefixIcon: Container(
                              width: 36,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                settings.currencySymbol,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 36,
                              maxWidth: 36,
                              minHeight: 46,
                              maxHeight: 46,
                            ),
                            suffixIcon: Visibility(
                              visible: pos.discount > 0,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: () {
                                  _discountCtrl.clear();
                                  _lastDiscount = 0.0;
                                  pos.setDiscount(0.0);
                                },
                              ),
                            ),
                            isDense: false,
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

                // 5. Cash Received Row (خانة المبلغ المستلم - كبيرة وبنفس حجم الخصم ومحاذاة مثالية)
                Row(
                  key: const ValueKey('cash_received_section'),
                  children: [
                    SizedBox(
                      width: 110,
                      child: Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'المبلغ المستلم:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: TextField(
                          key: const ValueKey('pos_paid_text_field'),
                          controller: _paidCtrl,
                          focusNode: _paidFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          textAlign: TextAlign.left,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              color: colors.textMuted,
                              fontSize: 14,
                            ),
                            prefixIcon: Container(
                              width: 36,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                settings.currencySymbol,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 36,
                              maxWidth: 36,
                              minHeight: 46,
                              maxHeight: 46,
                            ),
                            suffixIcon: pos.amountPaid > 0
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    onPressed: () {
                                      _paidCtrl.clear();
                                      _lastAmountPaid = 0.0;
                                      pos.setAmountPaid(0.0);
                                    },
                                  )
                                : null,
                            isDense: false,
                          ),
                          onChanged: (val) {
                            final parsed = NumberParser.tryParseDouble(val);
                            _lastAmountPaid = parsed;
                            pos.setAmountPaid(parsed);
                          },
                        ),
                      ),
                    ),
                    if (pos.grandTotal > 0 &&
                        pos.amountPaid != pos.grandTotal) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: AppStrings.exactAmount,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            pos.setAmountPaid(pos.grandTotal);
                            _lastAmountPaid = pos.grandTotal;
                            _paidCtrl.text = pos.grandTotal % 1 == 0
                                ? pos.grandTotal.toInt().toString()
                                : pos.grandTotal.toStringAsFixed(2);
                          },
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'بالضبط',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // 6. Change Due / Remaining Box (Full Width)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: (pos.cartItems.isNotEmpty && pos.changeDue > 0)
                        ? colors.info.withValues(alpha: 0.15)
                        : (pos.amountPaid < pos.grandTotal &&
                                  pos.cartItems.isNotEmpty
                              ? colors.warning.withValues(alpha: 0.12)
                              : colors.cardSurface),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (pos.cartItems.isNotEmpty && pos.changeDue > 0)
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
                          color: (pos.cartItems.isNotEmpty && pos.changeDue > 0)
                              ? colors.info
                              : (pos.amountPaid < pos.grandTotal &&
                                        pos.cartItems.isNotEmpty
                                    ? colors.warning
                                    : colors.textSecondary),
                        ),
                      ),
                      Text(
                        pos.cartItems.isEmpty
                            ? CurrencyFormatter.format(
                                0.0,
                                symbol: settings.currencySymbol,
                              )
                            : (pos.amountPaid < pos.grandTotal
                                  ? CurrencyFormatter.format(
                                      pos.grandTotal - pos.amountPaid,
                                      symbol: settings.currencySymbol,
                                    )
                                  : CurrencyFormatter.format(
                                      pos.changeDue,
                                      symbol: settings.currencySymbol,
                                    )),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: (pos.cartItems.isNotEmpty && pos.changeDue > 0)
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

  Widget _buildQuickCashChip(String label, double amount, POSProvider pos) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        final current = pos.amountPaid;
        final next = current + amount;
        pos.setAmountPaid(next);
        _lastAmountPaid = next;
        _paidCtrl.text = next % 1 == 0
            ? next.toInt().toString()
            : next.toStringAsFixed(2);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.colors.cardSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: context.colors.primaryLight,
          ),
        ),
      ),
    );
  }
}
