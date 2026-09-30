import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/print_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/stat_card.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView>
    with SingleTickerProviderStateMixin {
  bool _isExporting = false;
  bool _isPrinting = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().loadReports();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onPrintReport() async {
    setState(() => _isPrinting = true);
    final reports = context.read<ReportsProvider>();
    final settings = context.read<SettingsProvider>().settings;

    try {
      await PrintService.printFinancialReport(
        financialStats: reports.financialStats,
        topProducts: reports.topProducts,
        categorySales: reports.categorySales,
        settings: settings,
        periodLabel: reports.periodDisplayName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء طباعة التقرير: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _onExportPdf() async {
    setState(() => _isExporting = true);
    final reports = context.read<ReportsProvider>();
    final settings = context.read<SettingsProvider>().settings;

    try {
      final savedPath = await PrintService.exportFinancialReportPdf(
        financialStats: reports.financialStats,
        topProducts: reports.topProducts,
        categorySales: reports.categorySales,
        settings: settings,
        periodLabel: reports.periodDisplayName,
      );

      if (mounted && savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير وحفظ التقرير بنجاح: $savedPath'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تصدير ملف PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _onPickCustomDateRange() async {
    final reports = context.read<ReportsProvider>();
    final initialRange = reports.startDate != null && reports.endDate != null
        ? DateTimeRange(start: reports.startDate!, end: reports.endDate!)
        : DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialRange,
      locale: const Locale('ar'),
      helpText: 'اختر الفترة الزمنية للتقرير',
      cancelText: 'إلغاء',
      confirmText: 'تطبيق',
      saveText: 'تطبيق',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      reports.setPeriod(
        ReportPeriod.custom,
        customStart: picked.start,
        customEnd: picked.end,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportsProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 1020;

          final statCards = [
            StatCard(
              title: AppStrings.totalSales,
              value: CurrencyFormatter.format(
                reports.totalSales,
                symbol: settings.currencySymbol,
              ),
              icon: Icons.monetization_on_outlined,
              accentColor: colors.primary,
              subtitle: 'عدد الفواتير: ${reports.totalOrders}',
            ),
            StatCard(
              title: AppStrings.netProfit,
              value: CurrencyFormatter.format(
                reports.netProfit,
                symbol: settings.currencySymbol,
              ),
              icon: Icons.trending_up,
              accentColor: AppColors.success,
              subtitle:
                  'هامش الربح: ${reports.profitMarginPercentage.toStringAsFixed(1)}%',
            ),
            StatCard(
              title: 'تكلفة البضاعة (COGS)',
              value: CurrencyFormatter.format(
                reports.totalCogs,
                symbol: settings.currencySymbol,
              ),
              icon: Icons.account_balance,
              accentColor: colors.secondary,
              subtitle: 'إجمالي سعر التكلفة',
            ),
            StatCard(
              title: AppStrings.totalReturns,
              value: CurrencyFormatter.format(
                reports.totalReturns,
                symbol: settings.currencySymbol,
              ),
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

          Widget buildPeriodSelector() {
            final activePeriod = reports.selectedPeriod;

            final periods = [
              {
                'period': ReportPeriod.all,
                'label': 'جميع الفترات',
                'icon': Icons.all_inclusive_rounded,
              },
              {
                'period': ReportPeriod.today,
                'label': 'اليوم',
                'icon': Icons.today_rounded,
              },
              {
                'period': ReportPeriod.weekly,
                'label': 'أسبوعي',
                'icon': Icons.date_range_rounded,
              },
              {
                'period': ReportPeriod.monthly,
                'label': 'شهري',
                'icon': Icons.calendar_month_rounded,
              },
              {
                'period': ReportPeriod.yearly,
                'label': 'سنوي',
                'icon': Icons.event_note_rounded,
              },
              {
                'period': ReportPeriod.custom,
                'label': 'نطاق مخصص',
                'icon': Icons.edit_calendar_rounded,
              },
            ];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: periods.map((item) {
                      final period = item['period'] as ReportPeriod;
                      final label = item['label'] as String;
                      final icon = item['icon'] as IconData;
                      final isSelected = activePeriod == period;

                      return ChoiceChip(
                        avatar: Icon(
                          icon,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : colors.textSecondary,
                        ),
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: colors.cardSurface,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? Colors.white : colors.textPrimary,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            if (period == ReportPeriod.custom) {
                              _onPickCustomDateRange();
                            } else {
                              reports.setPeriod(period);
                            }
                          }
                        },
                      );
                    }).toList(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          reports.periodDisplayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.primaryLight,
                          ),
                        ),
                        if (activePeriod == ReportPeriod.custom) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: _onPickCustomDateRange,
                            child: const Icon(
                              Icons.edit,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          Widget buildPaymentMethodsBar() {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceAround,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'مبيعات نقدية (كاش): ',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(
                          reports.cashSales,
                          symbol: settings.currencySymbol,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.credit_card_outlined,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'مبيعات شبكة / إلكتروني: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(
                          reports.cardSales,
                          symbol: settings.currencySymbol,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          Widget buildTopSellingList() {
            if (reports.topProducts.isEmpty) {
              return Center(
                child: Text(
                  'لا توجد مبيعات مسجلة في هذه الفترة',
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
              );
            }

            return ListView.separated(
              itemCount: reports.topProducts.length,
              separatorBuilder: (_, _) => Divider(color: colors.border),
              itemBuilder: (context, index) {
                final item = reports.topProducts[index];
                final soldQty =
                    (item['total_sold_qty'] as num?)?.toDouble() ?? 0.0;
                final revenue =
                    (item['total_revenue'] as num?)?.toDouble() ?? 0.0;

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: colors.primary.withValues(alpha: 0.18),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['product_name'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            '${item['size']} - ${item['color']} (باركود: ${item['sku_barcode']})',
                            style: TextStyle(
                              fontSize: 10,
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
                          '$soldQty قطعة مباعة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(
                            revenue,
                            symbol: settings.currencySymbol,
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          }

          Widget buildCategorySalesList() {
            if (reports.categorySales.isEmpty) {
              return Center(
                child: Text(
                  'لا توجد مبيعات تصنيفات مسجلة في هذه الفترة',
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
              );
            }

            return ListView.separated(
              itemCount: reports.categorySales.length,
              separatorBuilder: (_, _) => Divider(color: colors.border),
              itemBuilder: (context, index) {
                final item = reports.categorySales[index];
                final categoryName = item['category_name'] as String? ?? 'عام';
                final soldQty =
                    (item['total_sold_qty'] as num?)?.toDouble() ?? 0.0;
                final revenue =
                    (item['total_revenue'] as num?)?.toDouble() ?? 0.0;
                final percentage = reports.totalSales > 0
                    ? (revenue / reports.totalSales) * 100
                    : 0.0;

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        size: 16,
                        color: colors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'النسبة من الإجمالي: ${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 10,
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
                          '$soldQty قطعة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(
                            revenue,
                            symbol: settings.currencySymbol,
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          }

          Widget buildLowStockList() {
            if (reports.lowStockVariants.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: colors.success,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'جميع الأصناف بمستويات مخزون جيدة',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              itemCount: reports.lowStockVariants.length,
              separatorBuilder: (_, _) => Divider(color: colors.border),
              itemBuilder: (context, index) {
                final v = reports.lowStockVariants[index];
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.productName ?? 'منتج',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.cardSurface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: colors.border,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  '${v.size} - ${v.color}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'باركود: ${v.skuBarcode}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: v.stockQuantity <= 0
                            ? colors.error.withValues(alpha: 0.15)
                            : colors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        v.stockQuantity <= 0
                            ? 'نفد (0)'
                            : 'متبقي ${v.stockQuantity} فقط',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: v.stockQuantity <= 0
                              ? colors.error
                              : colors.warning,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          }

          Widget buildTabsSection() {
            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: colors.textSecondary,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.star_rounded, size: 18),
                        text:
                            'الأصناف الأكثر مبيعاً (${reports.topProducts.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.category_rounded, size: 18),
                        text:
                            'المبيعات حسب التصنيف (${reports.categorySales.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.warning_amber_rounded, size: 18),
                        text:
                            'نواقص المخزون (${reports.lowStockVariants.length})',
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: reports.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                buildTopSellingList(),
                                buildCategorySalesList(),
                                buildLowStockList(),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            );
          }

          final isScrollMode = constraints.maxHeight < 780 || isNarrow;

          final headerAndFilters = [
            // Top Header with Action Buttons
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.financialReports,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تحليل المبيعات، تكلفة البضاعة، صافي الأرباح، والأصناف الأكثر طلباً',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (isAdmin) ...[
                      OutlinedButton.icon(
                        icon: _isExporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 18,
                              ),
                        label: const Text('تصدير PDF'),
                        onPressed: _isExporting ? null : _onExportPdf,
                      ),
                      ElevatedButton.icon(
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.print_outlined, size: 18),
                        label: const Text('طباعة التقرير'),
                        onPressed: _isPrinting ? null : _onPrintReport,
                      ),
                    ],
                    IconButton(
                      icon: Icon(Icons.refresh, color: colors.primary),
                      tooltip: 'تحديث البيانات',
                      onPressed: () => reports.loadReports(),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Period Filter Chips Bar
            buildPeriodSelector(),

            const SizedBox(height: 14),

            // 4 KPI Stat Cards
            buildTopCards(),

            const SizedBox(height: 10),

            // Payment Methods Mini Summary
            buildPaymentMethodsBar(),

            const SizedBox(height: 14),
          ];

          if (isScrollMode) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...headerAndFilters,
                  SizedBox(height: 380, child: buildTabsSection()),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...headerAndFilters,
                Expanded(child: buildTabsSection()),
              ],
            ),
          );
        },
      ),
    );
  }
}
