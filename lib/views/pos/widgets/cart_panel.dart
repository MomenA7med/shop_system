import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/number_parser.dart';
import '../../../models/order_item_model.dart';
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
  final TextEditingController _deliveryCtrl = TextEditingController();
  final FocusNode _deliveryFocusNode = FocusNode();
  double _lastAmountPaid = -1.0;
  double _lastDiscount = -1.0;
  double _lastDeliveryFee = -1.0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _paidCtrl.dispose();
    _paidFocusNode.dispose();
    _discountCtrl.dispose();
    _discountFocusNode.dispose();
    _deliveryCtrl.dispose();
    _deliveryFocusNode.dispose();
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (!mounted) return false;
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        final pos = context.read<POSProvider>();
        if (pos.canCheckout) {
          _handleCheckout(saveAndPrint: true);
          return true;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.f3) {
        final pos = context.read<POSProvider>();
        if (pos.canCheckout) {
          _handleCheckout(saveAndPrint: false);
          return true;
        }
      }
    }
    return false;
  }

  void _syncPaidAmount(POSProvider pos) {
    if (pos.cartItems.isEmpty) {
      if (_paidCtrl.text.isNotEmpty) {
        _paidCtrl.clear();
      }
      if (_discountCtrl.text.isNotEmpty) {
        _discountCtrl.clear();
      }
      if (_deliveryCtrl.text.isNotEmpty) {
        _deliveryCtrl.clear();
      }
      _lastAmountPaid = 0.0;
      _lastDiscount = 0.0;
      _lastDeliveryFee = 0.0;
      return;
    }

    // Sync delivery fee input only if not currently focused by user
    if (!_deliveryFocusNode.hasFocus) {
      if (_lastDeliveryFee != pos.deliveryFee) {
        _lastDeliveryFee = pos.deliveryFee;
        final formatted = pos.deliveryFee > 0
            ? (pos.deliveryFee % 1 == 0
                  ? pos.deliveryFee.toInt().toString()
                  : pos.deliveryFee.toStringAsFixed(2))
            : '';
        if (_deliveryCtrl.text != formatted) {
          _deliveryCtrl.text = formatted;
        }
      }
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
    if (!license.isActivated &&
        (license.isTrialExpired ||
            license.totalInvoices >= license.maxTrialInvoices)) {
      ActivationDialog.show(
        context,
        reason:
            license.status?.expirationReason ??
            'لقد وصلت إلى الحد الأقصى للنسخة التجريبية (5 فواتير).',
      );
      return;
    }

    final cashierId = auth.currentUser?.id ?? 1;
    final shiftId = shift.activeShift?.id;

    final order = await pos.checkout(cashierId: cashierId, shiftId: shiftId);

    if (order != null && mounted) {
      // 1. Refresh license statistics
      license.refresh();

      // 2. Reload active shift
      if (shift.activeShift != null) {
        await shift.checkActiveShift(cashierId);
      }

      // 3. Automatically refresh Invoices, Reports, and Inventory
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

  void _showWeightDialog(
    BuildContext context,
    OrderItemModel item,
    int index,
    POSProvider pos,
    AppColorsExtension colors,
    settings,
  ) {
    final maxStock = pos.getMaxStock(item);
    final TextEditingController qtyCtrl = TextEditingController(
      text: NumberParser.formatQuantity(item.quantity),
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final currentQty = NumberParser.tryParseDouble(qtyCtrl.text, 1.0);
          final isOverStock = currentQty > maxStock;
          final currentTotal = (isOverStock ? maxStock : currentQty) * item.unitPrice;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.scale_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'سعر (${item.size}): ${CurrencyFormatter.format(item.unitPrice, symbol: settings.currencySymbol)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'المتاح بالمخزون: ${NumberParser.formatQuantity(maxStock)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colors.isDark ? colors.primaryLight : colors.primaryDark,
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
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'أوزان سريعة شائعة (كجم / وحدة):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildPresetWeightChip('ثمن (0.125)', 0.125, maxStock, qtyCtrl, () => setModalState(() {})),
                        _buildPresetWeightChip('ربع (0.250)', 0.250, maxStock, qtyCtrl, () => setModalState(() {})),
                        _buildPresetWeightChip('تلت (0.333)', 0.333, maxStock, qtyCtrl, () => setModalState(() {})),
                        _buildPresetWeightChip('نصف (0.500)', 0.500, maxStock, qtyCtrl, () => setModalState(() {})),
                        _buildPresetWeightChip('إلا ربع (0.750)', 0.750, maxStock, qtyCtrl, () => setModalState(() {})),
                        _buildPresetWeightChip('1 كجم', 1.0, maxStock, qtyCtrl, () => setModalState(() {})),
                        _buildPresetWeightChip('1.5 كجم', 1.5, maxStock, qtyCtrl, () => setModalState(() {})),
                        _buildPresetWeightChip('2 كجم', 2.0, maxStock, qtyCtrl, () => setModalState(() {})),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'الكمية / الوزن الدقيق',
                        hintText: 'مثال: 0.350',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              onPressed: () {
                                final current = NumberParser.tryParseDouble(qtyCtrl.text, 1.0);
                                if (current > 0.05) {
                                  qtyCtrl.text = NumberParser.formatQuantity(current - 0.05);
                                  setModalState(() {});
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              onPressed: () {
                                final current = NumberParser.tryParseDouble(qtyCtrl.text, 0.0);
                                final next = current + 0.05;
                                if (next <= maxStock) {
                                  qtyCtrl.text = NumberParser.formatQuantity(next);
                                } else {
                                  qtyCtrl.text = NumberParser.formatQuantity(maxStock);
                                }
                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    if (isOverStock) ...[
                      const SizedBox(height: 6),
                      Text(
                        '⚠️ الكمية تتجاوز المتاح بالمخزون (${NumberParser.formatQuantity(maxStock)})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الإجمالي للصنف:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            CurrencyFormatter.format(currentTotal, symbol: settings.currencySymbol),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final parsed = NumberParser.tryParseDouble(qtyCtrl.text, 1.0);
                    if (parsed > maxStock) {
                      pos.updateQuantity(index, maxStock);
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم ضبط الكمية على الحد الأقصى للمخزون (${NumberParser.formatQuantity(maxStock)})'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else if (parsed > 0) {
                      pos.updateQuantity(index, parsed);
                    }
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('تأكيد الكمية / الوزن'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPresetWeightChip(
    String label,
    double value,
    double maxStock,
    TextEditingController controller,
    VoidCallback onUpdated,
  ) {
    final isAllowed = value <= maxStock;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        controller.text = NumberParser.formatQuantity(value > maxStock ? maxStock : value);
        onUpdated();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isAllowed ? context.colors.cardSurface : context.colors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isAllowed ? context.colors.border : context.colors.border.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isAllowed ? context.colors.textPrimary : context.colors.textMuted,
          ),
        ),
      ),
    );
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
                      padding: EdgeInsets.all(
                        settings.logoPath != null &&
                                File(settings.logoPath!).existsSync()
                            ? 2
                            : 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          settings.logoPath != null &&
                              File(settings.logoPath!).existsSync()
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
                      _deliveryCtrl.clear();
                    },
                  ),
              ],
            ),
          ),
          Divider(color: colors.border, height: 1),

          // 2. Cart Items List (The Classic List with supermarket weight/quantity controls)
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
                      final hasDesc = item.color.isNotEmpty &&
                          item.color != '-' &&
                          item.color != 'افتراضي';
                      final specLabel = hasDesc ? '${item.size} (${item.color})' : item.size;

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
                            // Top Line: Product Name + Spec Badge + Top "X" Delete Icon
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: colors.textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              specLabel,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: colors.isDark ? colors.primaryLight : colors.primaryDark,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: (item.quantity >= pos.getMaxStock(item))
                                                  ? colors.warning.withValues(alpha: 0.15)
                                                  : colors.surfaceLight,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'المتاح: ${NumberParser.formatQuantity(pos.getMaxStock(item))}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: (item.quantity >= pos.getMaxStock(item))
                                                    ? colors.warning
                                                    : colors.textMuted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => pos.removeItem(index),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: colors.error.withValues(alpha: 0.1),
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

                            const SizedBox(height: 10),

                            // Bottom Line: Price (Right) | Quantity & Weight Controls (Center) | Total (Left)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Unit price
                                Text(
                                  CurrencyFormatter.format(
                                    item.unitPrice,
                                    symbol: settings.currencySymbol,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                // Quantity Controls with Weight/Scale Picker
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
                                      onPressed: () => pos.decrementQuantity(
                                        index,
                                        item.quantity <= 1.0 && item.quantity > 0.25 ? 0.25 : 1.0,
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'اضغط لتعديل الوزن أو الكمية (أوزان سريعة)',
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () => _showWeightDialog(
                                          context,
                                          item,
                                          index,
                                          pos,
                                          colors,
                                          settings,
                                        ),
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            minWidth: 42,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.surface,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: colors.primary.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                NumberParser.formatQuantity(item.quantity),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: colors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(
                                                Icons.scale_rounded,
                                                size: 13,
                                                color: colors.primary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_circle_outline,
                                        size: 20,
                                        color: (item.quantity >= pos.getMaxStock(item))
                                            ? colors.textMuted.withValues(alpha: 0.35)
                                            : colors.primary,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      onPressed: (item.quantity >= pos.getMaxStock(item))
                                          ? () {
                                              final maxStock = pos.getMaxStock(item);
                                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'عفواً، لا يمكن زيادة الكمية؛ المتاح بالمخزون هو (${NumberParser.formatQuantity(maxStock)}) فقط!',
                                                  ),
                                                  backgroundColor: colors.warning,
                                                  behavior: SnackBarBehavior.floating,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          : () => pos.incrementQuantity(
                                              index,
                                              item.quantity < 1.0 ? 0.25 : 1.0,
                                            ),
                                    ),
                                  ],
                                ),

                                // Line Total Price
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

          // 3. Payment & Totals Section with Delivery, Discount & Side-by-Side Cash Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: colors.surface),
            child: Column(
              children: [
                // Subtotal & Breakdown row (if discount or delivery is applied)
                if (pos.discount > 0 || pos.deliveryFee > 0) ...[
                  Padding(
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

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

                const SizedBox(height: 10),

                // 4. Delivery Fee Input Row (الدليفري / خدمة التوصيل)
                Row(
                  key: const ValueKey('delivery_input_section'),
                  children: [
                    SizedBox(
                      width: 110,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delivery_dining_rounded,
                            size: 19,
                            color: Color(0xFF0D9488),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'الدليفري:',
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
                        height: 44,
                        child: TextField(
                          key: const ValueKey('pos_delivery_text_field'),
                          controller: _deliveryCtrl,
                          focusNode: _deliveryFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            fontSize: 14,
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
                              fontSize: 13,
                            ),
                            prefixIcon: Container(
                              width: 36,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 8),
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
                              minWidth: 36,
                              maxWidth: 36,
                              minHeight: 44,
                              maxHeight: 44,
                            ),
                            suffixIcon: Visibility(
                              visible: pos.deliveryFee > 0,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 30,
                                  minHeight: 30,
                                ),
                                onPressed: () {
                                  _deliveryCtrl.clear();
                                  _lastDeliveryFee = 0.0;
                                  pos.setDeliveryFee(0.0);
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
                            _lastDeliveryFee = parsed;
                            pos.setDeliveryFee(parsed);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 5. Discount Input Row (الخصم)
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
                        height: 44,
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
                              fontSize: 13,
                            ),
                            prefixIcon: Container(
                              width: 36,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 8),
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
                              minWidth: 36,
                              maxWidth: 36,
                              minHeight: 44,
                              maxHeight: 44,
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
                                  minWidth: 30,
                                  minHeight: 30,
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

                const SizedBox(height: 8),

                // 6. Cash Received Row (المبلغ المستلم)
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
                        height: 44,
                        child: TextField(
                          key: const ValueKey('pos_paid_text_field'),
                          controller: _paidCtrl,
                          focusNode: _paidFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            fontSize: 14,
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
                              fontSize: 13,
                            ),
                            prefixIcon: Container(
                              width: 36,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 8),
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
                              minWidth: 36,
                              maxWidth: 36,
                              minHeight: 44,
                              maxHeight: 44,
                            ),
                            suffixIcon: pos.amountPaid > 0
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 30,
                                      minHeight: 30,
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
                            height: 44,
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

                const SizedBox(height: 8),

                // 7. Change Due / Remaining Box
                Container(
                  height: 42,
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
                          fontSize: 15,
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

                const SizedBox(height: 12),

                // 8. Dual Action Buttons: Save & Print vs Save Without Printing
                Row(
                  children: [
                    // Button 1: Save & Print
                    Expanded(
                      child: SizedBox(
                        height: 44,
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

                    const SizedBox(width: 8),

                    // Button 2: Save Without Printing
                    Expanded(
                      child: SizedBox(
                        height: 44,
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
