import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/number_parser.dart';
import '../../models/shift_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shift_provider.dart';

class ShiftsView extends StatefulWidget {
  const ShiftsView({super.key});

  @override
  State<ShiftsView> createState() => _ShiftsViewState();
}

class _ShiftsViewState extends State<ShiftsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final cashierId = auth.currentUser?.id ?? 1;
      context.read<ShiftProvider>().checkActiveShift(cashierId);
    });
  }

  void _showOpenShiftDialog(BuildContext context) {
    final colors = context.colors;
    final floatController = TextEditingController(text: '500');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(AppStrings.openShift, style: TextStyle(color: colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('أدخل رصيد بداية الدرج (العهدة النقدية):', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              controller: floatController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: '500.00',
                hintStyle: TextStyle(color: colors.textMuted),
                prefixIcon: Icon(Icons.account_balance_wallet, color: colors.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppStrings.cancel, style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = NumberParser.tryParseDouble(floatController.text.trim(), 0.0);
              final auth = context.read<AuthProvider>();
              final cashierId = auth.currentUser?.id ?? 1;
              await context.read<ShiftProvider>().startShift(cashierId, amount);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('تأكيد وفتح الوردية'),
          ),
        ],
      ),
    );
  }

  void _showCloseShiftDialog(BuildContext context, ShiftModel shift) {
    final colors = context.colors;
    final actualCashController = TextEditingController(text: shift.expectedCash.toStringAsFixed(0));
    double discrepancy = 0.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final settings = context.watch<SettingsProvider>().settings;
          final actual = NumberParser.tryParseDouble(actualCashController.text.trim(), 0.0);
          discrepancy = actual - shift.expectedCash;

          return AlertDialog(
            backgroundColor: colors.surface,
            title: Text(AppStrings.closeShift, style: TextStyle(color: colors.textPrimary)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryItem(context, 'رصيد البداية (العهدة):', shift.openingFloat, settings.currencySymbol),
                  _buildSummaryItem(context, 'المبيعات النقدية (+):', shift.cashSales, settings.currencySymbol),
                  _buildSummaryItem(context, 'المرتجعات النقدية (-):', shift.cashReturns, settings.currencySymbol),
                  Divider(height: 20, color: colors.border),
                  _buildSummaryItem(
                    context,
                    'النقد المتوقع في الدرج:',
                    shift.expectedCash,
                    settings.currencySymbol,
                    isBold: true,
                    fontSize: 14,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    AppStrings.actualCash,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: actualCashController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'أدخل المبلغ الفعلي بعد العد اليدوي',
                      hintStyle: TextStyle(color: colors.textMuted),
                      prefixIcon: Icon(Icons.attach_money, color: colors.primary),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 16),

                  // Discrepancy indicator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: discrepancy == 0
                          ? colors.success.withValues(alpha: 0.15)
                          : (discrepancy < 0 ? colors.error.withValues(alpha: 0.15) : colors.warning.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          discrepancy == 0
                              ? AppStrings.shiftMatched
                              : (discrepancy < 0 ? AppStrings.shiftShortage : AppStrings.shiftOverage),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: discrepancy == 0
                                ? colors.success
                                : (discrepancy < 0 ? colors.error : colors.warning),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(discrepancy.abs(), symbol: settings.currencySymbol),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: discrepancy == 0
                                ? colors.success
                                : (discrepancy < 0 ? colors.error : colors.warning),
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
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(AppStrings.cancel, style: TextStyle(color: colors.textSecondary)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
                icon: const Icon(Icons.lock_clock, size: 18),
                label: const Text(AppStrings.closeShift),
                onPressed: () async {
                  final actualVal = NumberParser.tryParseDouble(actualCashController.text.trim(), 0.0);
                  await context.read<ShiftProvider>().endShift(actualVal);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, double amount, String currency, {bool isBold = false, double fontSize = 12}) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: colors.textPrimary)),
          Text(
            CurrencyFormatter.format(amount, symbol: currency),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? colors.primary : colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shift = context.watch<ShiftProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final active = shift.activeShift;
    final history = shift.shiftHistory;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 850;
          final isShortHeight = constraints.maxHeight < 700;

          Widget buildActiveShiftCard() {
            if (active == null || !active.isOpen) return const SizedBox.shrink();

            final metricTiles = [
              _buildMetricTile(
                context,
                'رصيد البداية (العهدة)',
                active.openingFloat,
                Icons.wallet,
                colors.info,
                settings.currencySymbol,
              ),
              _buildMetricTile(
                context,
                'مبيعات نقدية (+)',
                active.cashSales,
                Icons.trending_up,
                colors.primary,
                settings.currencySymbol,
              ),
              _buildMetricTile(
                context,
                'مرتجعات نقدية (-)',
                active.cashReturns,
                Icons.assignment_return,
                colors.warning,
                settings.currencySymbol,
              ),
              _buildMetricTile(
                context,
                'النقد المتوقع بالدرج',
                active.expectedCash,
                Icons.account_balance_wallet,
                colors.primary,
                settings.currencySymbol,
                isHighlighted: true,
              ),
            ];

            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.surface, colors.surface.withValues(alpha: 0.9)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.primary.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.point_of_sale, color: colors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الوردية الحالية النشطة (#${active.id})',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.textPrimary),
                              ),
                              Text(
                                'بدأت في: ${DateFormatter.formatDateTime(active.startTime)}',
                                style: TextStyle(fontSize: 11, color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.warning,
                          foregroundColor: Colors.black87,
                        ),
                        icon: const Icon(Icons.lock_outlined, size: 18),
                        label: const Text(AppStrings.closeShift, style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _showCloseShiftDialog(context, active),
                      ),
                    ],
                  ),

                  Divider(height: 24, color: colors.border),

                  // Responsive Metrics Grid
                  if (isNarrow)
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: metricTiles[0]),
                            const SizedBox(width: 10),
                            Expanded(child: metricTiles[1]),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: metricTiles[2]),
                            const SizedBox(width: 10),
                            Expanded(child: metricTiles[3]),
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: metricTiles[0]),
                        const SizedBox(width: 12),
                        Expanded(child: metricTiles[1]),
                        const SizedBox(width: 12),
                        Expanded(child: metricTiles[2]),
                        const SizedBox(width: 12),
                        Expanded(child: metricTiles[3]),
                      ],
                    ),
                ],
              ),
            );
          }

          Widget buildHistoryList({bool fillParent = true}) {
            return Container(
              height: fillParent ? null : 350,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: history.isEmpty
                  ? Center(child: Text('لا يوجد سجل ورديات سابقة', style: TextStyle(color: colors.textMuted)))
                  : ListView.separated(
                      shrinkWrap: !fillParent,
                      itemCount: history.length,
                      separatorBuilder: (_, _) => Divider(color: colors.border),
                      itemBuilder: (context, index) {
                        final item = history[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                item.isOpen ? Icons.lock_open : Icons.lock_outline,
                                color: item.isOpen ? colors.success : colors.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('وردية #${item.id} (${item.cashierName ?? ""})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary)),
                                    Text(
                                      'من: ${DateFormatter.formatDateTime(item.startTime)}',
                                      style: TextStyle(fontSize: 10, color: colors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('المبيعات: ${CurrencyFormatter.format(item.cashSales, symbol: settings.currencySymbol)}', style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('المتوقع: ${CurrencyFormatter.format(item.expectedCash, symbol: settings.currencySymbol)}', style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'الفعلي: ${CurrencyFormatter.format(item.actualCash, symbol: settings.currencySymbol)}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            );
          }

          if (isShortHeight) {
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
                        AppStrings.shiftTitle,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                      ),
                      if (!shift.hasActiveShift)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text(AppStrings.openShift),
                          onPressed: () => _showOpenShiftDialog(context),
                        ),
                    ],
                  ),
                  if (active != null && active.isOpen) ...[
                    const SizedBox(height: 16),
                    buildActiveShiftCard(),
                  ],
                  const SizedBox(height: 20),
                  Text('سجل الورديات السابقة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.textPrimary)),
                  const SizedBox(height: 10),
                  buildHistoryList(fillParent: false),
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
                      AppStrings.shiftTitle,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    if (!shift.hasActiveShift)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text(AppStrings.openShift),
                        onPressed: () => _showOpenShiftDialog(context),
                      ),
                  ],
                ),

                if (active != null && active.isOpen) ...[
                  const SizedBox(height: 18),
                  buildActiveShiftCard(),
                ],

                const SizedBox(height: 20),

                // Shifts History Table
                Text('سجل الورديات السابقة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.textPrimary)),
                const SizedBox(height: 12),

                Expanded(
                  child: buildHistoryList(fillParent: true),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricTile(BuildContext context, String title, double amount, IconData icon, Color color, String currency, {bool isHighlighted = false}) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withValues(alpha: 0.15) : colors.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isHighlighted ? color : colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(amount, symbol: currency),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? color : colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
