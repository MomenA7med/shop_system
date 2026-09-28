import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/order_item_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/invoices_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/returns_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shift_provider.dart';

class ReturnsView extends StatefulWidget {
  const ReturnsView({super.key});

  @override
  State<ReturnsView> createState() => _ReturnsViewState();
}

class _ReturnsViewState extends State<ReturnsView> {
  final TextEditingController _invoiceSearchCtrl = TextEditingController();
  final Map<int, int> _returnQuantities = {};
  final Map<int, String> _returnReasons = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReturnsProvider>().loadReturnsHistory();
    });
  }

  @override
  void dispose() {
    _invoiceSearchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    context.read<ReturnsProvider>().searchOrder(_invoiceSearchCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final returns = context.watch<ReturnsProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final shift = context.watch<ShiftProvider>();
    final order = returns.searchedOrder;

    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              AppStrings.returnsTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Search Invoice Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _invoiceSearchCtrl,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: AppStrings.searchInvoiceOrBarcode,
                        hintStyle: TextStyle(color: colors.textMuted),
                        prefixIcon: Icon(
                          Icons.receipt_long,
                          color: colors.primary,
                        ),
                      ),
                      onSubmitted: (_) => _onSearch(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('بحث عن الفاتورة'),
                    onPressed: _onSearch,
                  ),
                ],
              ),
            ),

            if (returns.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colors.error, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      returns.errorMessage!,
                      style: TextStyle(color: colors.error, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            if (returns.successMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: colors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      returns.successMessage!,
                      style: TextStyle(color: colors.success, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Searched Order Items Section
            Expanded(
              child: order != null
                  ? _buildOrderReturnDetails(
                      context,
                      order,
                      returns,
                      shift,
                      settings.currencySymbol,
                    )
                  : _buildReturnsHistorySection(
                      context,
                      returns,
                      settings.currencySymbol,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderReturnDetails(
    BuildContext context,
    dynamic order,
    ReturnsProvider returns,
    ShiftProvider shift,
    String currencySymbol,
  ) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Summary Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'فاتورة رقم: ${order.invoiceNumber}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '(${DateFormatter.formatDateTime(order.createdAt)})',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              Text(
                'الإجمالي: ${CurrencyFormatter.format(order.totalAmount, symbol: currencySymbol)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          Divider(height: 24, color: colors.border),

          // Items Table Header & Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'عناصر الفاتورة المؤهلة للإرجاع:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'حدد الكمية والسبب لكل صنف تود إرجاعه',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'الصنف والمواصفات',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'الكمية والمتبقي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'سعر الوحدة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    'كمية الإرجاع',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 150,
                  child: Text(
                    'سبب الإرجاع',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 130,
                  child: Text(
                    'تأكيد المرتجع',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Items Rows
          Expanded(
            child: ListView.separated(
              itemCount: order.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final OrderItemModel item = order.items[index];
                final remaining = item.remainingQuantity;
                final isFullyReturned = remaining <= 0;

                _returnQuantities.putIfAbsent(item.id!, () => 1);
                _returnReasons.putIfAbsent(item.id!, () => 'مقاس غير مناسب');

                final selectedQty = _returnQuantities[item.id!] ?? 1;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.cardSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFullyReturned
                          ? colors.border.withValues(alpha: 0.5)
                          : colors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Item Name & Variant
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isFullyReturned
                                    ? colors.textMuted
                                    : colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.size} - ${item.color} (باركود: ${item.skuBarcode})',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Quantity Status
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الكمية: ${item.quantity}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              isFullyReturned
                                  ? 'مسترجع بالكامل ($remaining)'
                                  : 'متبقي: $remaining',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isFullyReturned
                                    ? colors.error
                                    : colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Unit Price
                      Expanded(
                        flex: 2,
                        child: Text(
                          CurrencyFormatter.format(
                            item.unitPrice,
                            symbol: currencySymbol,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),

                      if (!isFullyReturned) ...[
                        // Return Qty Counter
                        Container(
                          width: 110,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.remove,
                                  size: 15,
                                  color: colors.textPrimary,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: selectedQty > 1
                                    ? () => setState(
                                        () => _returnQuantities[item.id!] =
                                            selectedQty - 1,
                                      )
                                    : null,
                              ),
                              Text(
                                '$selectedQty',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: colors.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.add,
                                  size: 15,
                                  color: colors.primary,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: selectedQty < remaining
                                    ? () => setState(
                                        () => _returnQuantities[item.id!] =
                                            selectedQty + 1,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Return Reason Dropdown in Box
                        Container(
                          width: 150,
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.border),
                          ),
                          alignment: Alignment.center,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _returnReasons[item.id!],
                              isDense: true,
                              isExpanded: true,
                              dropdownColor: colors.surface,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              items:
                                  [
                                    'مقاس غير مناسب',
                                    'عيب صناعة',
                                    'رغبة العميل',
                                    'تبديل موديل',
                                  ].map((r) {
                                    return DropdownMenuItem<String>(
                                      value: r,
                                      child: Text(
                                        r,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(
                                    () => _returnReasons[item.id!] = val,
                                  );
                                }
                              },
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Confirm Return Button
                        SizedBox(
                          width: 130,
                          height: 38,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.warning,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.assignment_return, size: 15),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'إرجاع (${CurrencyFormatter.formatSimple(item.unitPrice * selectedQty)})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onPressed: () async {
                              final shiftId = shift.activeShift?.id;
                              final invoicesProv = context.read<InvoicesProvider>();
                              final reportsProv = context.read<ReportsProvider>();
                              final inventoryProv = context.read<InventoryProvider>();
                              final posProv = context.read<POSProvider>();

                              final ok = await returns.returnItem(
                                item: item,
                                returnQty: selectedQty,
                                reason:
                                    _returnReasons[item.id!] ?? 'طلب العميل',
                                shiftId: shiftId,
                                orderId: order.id,
                                invoiceNumber: order.invoiceNumber,
                              );

                              if (ok) {
                                if (shiftId != null &&
                                    shift.activeShift != null) {
                                  await shift.checkActiveShift(
                                    shift.activeShift!.cashierId,
                                  );
                                }
                                invoicesProv.loadInvoices();
                                reportsProv.loadReports();
                                inventoryProv.loadInventory();
                                posProv.loadPOSData();
                              }
                            },
                          ),
                        ),
                      ] else ...[
                        // Fully returned placeholder spanning across controls
                        SizedBox(
                          width: 410,
                          height: 38,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: colors.error.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 15,
                                  color: colors.error,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'تم استرجاع كامل الكمية من هذا الصنف',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnsHistorySection(
    BuildContext context,
    ReturnsProvider returns,
    String currencySymbol,
  ) {
    final colors = context.colors;
    final history = returns.returnsHistory;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سجل العمليات المرتجعة الأخيرة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'إجمالي العمليات: ${history.length}',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          Divider(height: 20, color: colors.border),

          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد عمليات إرجاع مسجلة',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, _) => Divider(color: colors.border),
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.assignment_return,
                              color: colors.warning,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${item.size} - ${item.color} | الكمية: ${item.quantity} | السبب: ${item.reason}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '- ${CurrencyFormatter.format(item.refundAmount, symbol: currencySymbol)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: colors.warning,
                                ),
                              ),
                              Text(
                                DateFormatter.formatDateTime(item.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
