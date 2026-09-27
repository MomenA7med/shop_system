import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/reports_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/stat_card.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().loadReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportsProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 1020;
          final isVeryNarrow = constraints.maxWidth < 800;
          final isShortHeight = constraints.maxHeight < 720;

          final statCards = [
            StatCard(
              title: AppStrings.totalSales,
              value: CurrencyFormatter.format(reports.totalSales, symbol: settings.currencySymbol),
              icon: Icons.monetization_on_outlined,
              accentColor: colors.primary,
              subtitle: 'عدد الفواتير: ${reports.totalOrders}',
            ),
            StatCard(
              title: AppStrings.netProfit,
              value: CurrencyFormatter.format(reports.netProfit, symbol: settings.currencySymbol),
              icon: Icons.trending_up,
              accentColor: colors.primary,
              subtitle: 'المبيعات - تكلفة البضاعة',
            ),
            StatCard(
              title: 'تكلفة البضاعة (COGS)',
              value: CurrencyFormatter.format(reports.totalCogs, symbol: settings.currencySymbol),
              icon: Icons.account_balance,
              accentColor: colors.secondary,
              subtitle: 'إجمالي سعر التكلفة',
            ),
            StatCard(
              title: AppStrings.totalReturns,
              value: CurrencyFormatter.format(reports.totalReturns, symbol: settings.currencySymbol),
              icon: Icons.assignment_return_outlined,
              accentColor: colors.warning,
              subtitle: 'عدد المرتجعات: ${reports.returnCount}',
            ),
          ];

          Widget buildTopCards() {
            if (isNarrow) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: statCards[0]),
                      const SizedBox(width: 10),
                      Expanded(child: statCards[1]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: statCards[2]),
                      const SizedBox(width: 10),
                      Expanded(child: statCards[3]),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: statCards[0]),
                const SizedBox(width: 12),
                Expanded(child: statCards[1]),
                const SizedBox(width: 12),
                Expanded(child: statCards[2]),
                const SizedBox(width: 12),
                Expanded(child: statCards[3]),
              ],
            );
          }

          Widget buildTopSellingCard({bool fillParent = true}) {
            return Container(
              height: fillParent ? null : 320,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: colors.warning, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.topSellingItems,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.textPrimary),
                      ),
                    ],
                  ),
                  Divider(height: 20, color: colors.border),
                  Expanded(
                    child: reports.topProducts.isEmpty
                        ? Center(child: Text('لا توجد مبيعات مسجلة حتى الآن', style: TextStyle(color: colors.textMuted)))
                        : ListView.separated(
                            itemCount: reports.topProducts.length,
                            separatorBuilder: (_, _) => Divider(color: colors.border),
                            itemBuilder: (context, index) {
                              final item = reports.topProducts[index];
                              final soldQty = item['total_sold_qty'] as int? ?? 0;
                              final revenue = (item['total_revenue'] as num?)?.toDouble() ?? 0.0;

                              return Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: colors.primary.withValues(alpha: 0.2),
                                    child: Text('${index + 1}', style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['product_name'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary)),
                                        Text(
                                          '${item['size']} - ${item['color']} (باركود: ${item['sku_barcode']})',
                                          style: TextStyle(fontSize: 10, color: colors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('$soldQty قطعة مباعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary)),
                                      Text(
                                        CurrencyFormatter.format(revenue, symbol: settings.currencySymbol),
                                        style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.bold),
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

          Widget buildLowStockCard({bool fillParent = true}) {
            return Container(
              height: fillParent ? null : 320,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colors.error, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.lowStockItems,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.textPrimary),
                      ),
                    ],
                  ),
                  Divider(height: 20, color: colors.border),
                  Expanded(
                    child: reports.lowStockVariants.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, color: colors.success, size: 32),
                                const SizedBox(height: 8),
                                Text('جميع الأصناف بمستويات مخزون جيدة', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: reports.lowStockVariants.length,
                            separatorBuilder: (_, _) => Divider(color: colors.border),
                            itemBuilder: (context, index) {
                              final v = reports.lowStockVariants[index];
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${v.size} - ${v.color}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary),
                                      ),
                                      Text(
                                        'باركود: ${v.skuBarcode}',
                                        style: TextStyle(fontSize: 10, color: colors.textMuted),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: v.stockQuantity <= 0 ? colors.error.withValues(alpha: 0.15) : colors.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      v.stockQuantity <= 0 ? 'نفد (0)' : 'متبقي ${v.stockQuantity} فقط',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: v.stockQuantity <= 0 ? colors.error : colors.warning,
                                      ),
                                    ),
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

          if (isShortHeight || isVeryNarrow) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.financialReports,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: colors.primary),
                        tooltip: 'تحديث البيانات',
                        onPressed: () => reports.loadReports(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  buildTopCards(),
                  const SizedBox(height: 16),
                  buildTopSellingCard(fillParent: false),
                  const SizedBox(height: 16),
                  buildLowStockCard(fillParent: false),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.financialReports,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: colors.primary),
                      tooltip: 'تحديث البيانات',
                      onPressed: () => reports.loadReports(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Top KPI Cards
                buildTopCards(),

                const SizedBox(height: 16),

                // Split Section: Top Selling Items (Right) & Low Stock Alerts (Left)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Selling Clothing Items
                      Expanded(
                        flex: 3,
                        child: buildTopSellingCard(fillParent: true),
                      ),

                      const SizedBox(width: 16),

                      // Low Stock Alerts (تنبيهات نقص المخزون)
                      Expanded(
                        flex: 2,
                        child: buildLowStockCard(fillParent: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
