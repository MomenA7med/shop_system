import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/order_model.dart';
import '../../providers/invoices_provider.dart';
import '../../providers/settings_provider.dart';
import '../pos/widgets/receipt_preview_modal.dart';
import 'widgets/edit_invoice_dialog.dart';
import 'widgets/invoice_details_dialog.dart';
import 'widgets/invoice_return_dialog.dart';

class InvoicesView extends StatefulWidget {
  const InvoicesView({super.key});

  @override
  State<InvoicesView> createState() => _InvoicesViewState();
}

class _InvoicesViewState extends State<InvoicesView> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoicesProvider>().loadInvoices();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final invoicesProv = context.read<InvoicesProvider>();
    final initialRange = DateTimeRange(
      start: invoicesProv.customStartDate ?? DateTime.now().subtract(const Duration(days: 7)),
      end: invoicesProv.customEndDate ?? DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initialRange,
      locale: const Locale('ar', 'EG'),
      helpText: 'اختر الفترة الزمنية للبحث عن الفواتير',
      cancelText: 'إلغاء',
      confirmText: 'تطبيق الفلتر',
    );

    if (picked != null) {
      invoicesProv.setDateFilter(
        InvoiceDateFilter.custom,
        customStart: picked.start,
        customEnd: picked.end,
      );
    }
  }

  Color _getStatusColor(OrderModel order, AppColorsExtension colors) {
    if (order.isFullyRefunded) {
      return colors.error;
    } else if (order.isPartiallyRefunded) {
      return colors.warning;
    } else {
      return colors.success;
    }
  }

  String _getStatusLabel(OrderModel order) {
    if (order.isFullyRefunded) {
      return 'مسترجعة بالكامل';
    } else if (order.isPartiallyRefunded) {
      return 'مرتجع جزئي';
    } else {
      return 'مكتملة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final invoicesProv = context.watch<InvoicesProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final invoices = invoicesProv.invoices;

    return Scaffold(
      backgroundColor: colors.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.receipt_long_rounded, color: colors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سجل الفواتير والمبيعات',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'عرض وتعديل الفواتير المباعة، عمل المرتجعات، والفلترة حسب الأيام',
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                  ),
                  icon: invoicesProv.isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('تحديث البيانات'),
                  onPressed: invoicesProv.isLoading ? null : () => invoicesProv.loadInvoices(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 2. Summary Metric Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'صافي المبيعات للفترة',
                    value: CurrencyFormatter.format(invoicesProv.netSalesAmount, symbol: settings.currencySymbol),
                    subtitle: invoicesProv.totalRefundedAmount > 0
                        ? 'إجمالي المرتجع: ${CurrencyFormatter.formatSimple(invoicesProv.totalRefundedAmount)}'
                        : null,
                    icon: Icons.payments_outlined,
                    iconColor: colors.primary,
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'عدد الفواتير',
                    value: '${invoicesProv.totalInvoicesCount} فاتورة',
                    icon: Icons.receipt_outlined,
                    iconColor: colors.info,
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'إجمالي القطع المباعة',
                    value: '${invoicesProv.remainingItemsCount} قطعة',
                    subtitle: invoicesProv.totalReturnedItemsCount > 0
                        ? 'مسترجع: ${invoicesProv.totalReturnedItemsCount} قطعة'
                        : null,
                    icon: Icons.shopping_basket_outlined,
                    iconColor: colors.success,
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'متوسط قيمة الفاتورة',
                    value: CurrencyFormatter.format(invoicesProv.averageInvoiceValue, symbol: settings.currencySymbol),
                    icon: Icons.trending_up,
                    iconColor: colors.warning,
                    colors: colors,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 3. Filters Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day Filter Buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          'الفترة الزمنية: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        _buildDateFilterChip('اليوم', InvoiceDateFilter.today, invoicesProv, colors),
                        const SizedBox(width: 6),
                        _buildDateFilterChip('أمس', InvoiceDateFilter.yesterday, invoicesProv, colors),
                        const SizedBox(width: 6),
                        _buildDateFilterChip('آخر 7 أيام', InvoiceDateFilter.last7days, invoicesProv, colors),
                        const SizedBox(width: 6),
                        _buildDateFilterChip('آخر 30 يوم', InvoiceDateFilter.last30days, invoicesProv, colors),
                        const SizedBox(width: 6),
                        _buildDateFilterChip('هذا الشهر', InvoiceDateFilter.thisMonth, invoicesProv, colors),
                        const SizedBox(width: 6),
                        _buildDateFilterChip('كل الفواتير', InvoiceDateFilter.all, invoicesProv, colors),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _selectCustomDateRange(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: invoicesProv.dateFilter == InvoiceDateFilter.custom
                                  ? colors.primary
                                  : colors.surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: invoicesProv.dateFilter == InvoiceDateFilter.custom
                                    ? colors.primary
                                    : colors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  size: 15,
                                  color: invoicesProv.dateFilter == InvoiceDateFilter.custom
                                      ? Colors.white
                                      : colors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  invoicesProv.dateFilter == InvoiceDateFilter.custom &&
                                          invoicesProv.customStartDate != null &&
                                          invoicesProv.customEndDate != null
                                      ? '${DateFormatter.formatDate(invoicesProv.customStartDate!)} - ${DateFormatter.formatDate(invoicesProv.customEndDate!)}'
                                      : 'تحديد فترة مخصصة...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: invoicesProv.dateFilter == InvoiceDateFilter.custom
                                        ? Colors.white
                                        : colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Search Bar & Status Dropdown
                  Row(
                    children: [
                      // Search field
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _searchCtrl,
                            style: TextStyle(fontSize: 13, color: colors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'البحث برقم الفاتورة، اسم الكاشير، أو الباركود...',
                              hintStyle: TextStyle(fontSize: 12, color: colors.textMuted),
                              prefixIcon: Icon(Icons.search, size: 18, color: colors.primary),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        invoicesProv.setSearchQuery('');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              isDense: true,
                            ),
                            onChanged: (val) => invoicesProv.setSearchQuery(val),
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Status filter
                      SizedBox(
                        height: 40,
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: invoicesProv.statusFilter,
                          isDense: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            labelText: 'حالة الفاتورة',
                            labelStyle: TextStyle(fontSize: 11, color: colors.textSecondary),
                          ),
                          style: TextStyle(fontSize: 12, color: colors.textPrimary),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('جميع الحالات')),
                            DropdownMenuItem(value: 'completed', child: Text('مكتملة وناجحة')),
                            DropdownMenuItem(value: 'partially_refunded', child: Text('مسترجعة جزئياً')),
                            DropdownMenuItem(value: 'refunded', child: Text('مسترجعة بالكامل')),
                          ],
                          onChanged: (val) {
                            if (val != null) invoicesProv.setStatusFilter(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. Invoices List / Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: invoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 54, color: colors.textMuted.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'لا توجد فواتير مطابقة للفلتر المحدد',
                              style: TextStyle(color: colors.textMuted, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'جرب تغيير الفترة الزمنية أو إزالة نص البحث',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: colors.surfaceLight,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Text('رقم الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textSecondary))),
                                Expanded(flex: 3, child: Text('التاريخ والوقت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textSecondary))),
                                Expanded(flex: 2, child: Text('الكاشير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textSecondary))),
                                Expanded(flex: 2, child: Text('الأصناف والقطع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textSecondary))),
                                Expanded(flex: 2, child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textSecondary))),
                                Expanded(flex: 2, child: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textSecondary))),
                                const SizedBox(width: 170, child: Text('الإجراءات', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                              ],
                            ),
                          ),

                          const Divider(height: 1),

                          // Table Body
                          Expanded(
                            child: ListView.separated(
                              itemCount: invoices.length,
                              separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
                              itemBuilder: (context, index) {
                                final order = invoices[index];
                                final statusColor = _getStatusColor(order, colors);

                                return InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => InvoiceDetailsDialog(order: order),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Row(
                                      children: [
                                        // Invoice Number
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              Icon(Icons.receipt, size: 16, color: colors.primary),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  order.invoiceNumber,
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Date & Time
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            DateFormatter.formatDateTime(order.createdAt),
                                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                                          ),
                                        ),

                                        // Cashier
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            order.cashierName ?? 'غير معروف',
                                            style: TextStyle(fontSize: 12, color: colors.textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),

                                        // Items & Qty count
                                        Expanded(
                                          flex: 2,
                                          child: order.hasReturns
                                              ? Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      '${order.items.length} أصناف (${order.remainingPieces} متبقي)',
                                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                                    ),
                                                    Text(
                                                      'تم إرجاع ${order.totalReturnedPieces} قطع',
                                                      style: TextStyle(fontSize: 10, color: colors.warning, fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                )
                                              : Text(
                                                  '${order.items.length} أصناف (${order.totalPieces} قطع)',
                                                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                                                ),
                                        ),

                                        // Grand Total
                                        Expanded(
                                          flex: 2,
                                          child: order.hasReturns
                                              ? Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      CurrencyFormatter.format(order.netTotalAmount, symbol: settings.currencySymbol),
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: colors.isDark ? colors.primaryLight : colors.primaryDark,
                                                      ),
                                                    ),
                                                    Text(
                                                      'مسترجع: ${CurrencyFormatter.formatSimple(order.refundedAmount)}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: colors.error,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Text(
                                                  CurrencyFormatter.format(order.totalAmount, symbol: settings.currencySymbol),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: colors.isDark ? colors.primaryLight : colors.primaryDark,
                                                  ),
                                                ),
                                        ),

                                        // Status
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              _getStatusLabel(order),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Action Buttons
                                        SizedBox(
                                          width: 170,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              // View details button
                                              IconButton(
                                                icon: Icon(Icons.visibility_outlined, size: 18, color: colors.primary),
                                                tooltip: 'عرض التفاصيل',
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (_) => InvoiceDetailsDialog(order: order),
                                                  );
                                                },
                                              ),

                                              // Edit invoice button
                                              IconButton(
                                                icon: Icon(Icons.edit_outlined, size: 18, color: colors.info),
                                                tooltip: 'تعديل الفاتورة',
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (_) => EditInvoiceDialog(order: order),
                                                  );
                                                },
                                              ),

                                              // Return button
                                              IconButton(
                                                icon: Icon(Icons.assignment_return_outlined, size: 18, color: colors.warning),
                                                tooltip: 'عمل مرتجع من الفاتورة',
                                                onPressed: order.items.any((i) => i.remainingQuantity > 0)
                                                    ? () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (_) => InvoiceReturnDialog(order: order),
                                                        );
                                                      }
                                                    : null,
                                              ),

                                              // Print button
                                              IconButton(
                                                icon: Icon(Icons.print_outlined, size: 18, color: colors.textSecondary),
                                                tooltip: 'طباعة الإيصال',
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (_) => ReceiptPreviewModal(
                                                      order: order,
                                                      settings: settings,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterChip(
    String label,
    InvoiceDateFilter filter,
    InvoicesProvider prov,
    AppColorsExtension colors,
  ) {
    final isSelected = prov.dateFilter == filter;

    return InkWell(
      onTap: () => prov.setDateFilter(filter),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? colors.primary : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required AppColorsExtension colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: colors.warning, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
