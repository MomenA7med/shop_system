import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/invoices_provider.dart';
import '../providers/license_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/reports_provider.dart';
import '../providers/returns_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shift_provider.dart';
import '../widgets/custom_sidebar.dart';
import '../widgets/desktop_header.dart';
import 'auth/login_view.dart';
import 'invoices/invoices_view.dart';
import 'pos/pos_view.dart';
import 'inventory/inventory_view.dart';
import 'returns/returns_view.dart';
import 'shifts/shifts_view.dart';
import 'reports/reports_view.dart';
import 'settings/settings_view.dart';
import 'license/activation_dialog.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });

    final auth = context.read<AuthProvider>();
    final cashierId = auth.currentUser?.id ?? 1;

    // Proactively refresh the selected view's data from database
    switch (index) {
      case 0:
        context.read<POSProvider>().loadPOSData();
        break;
      case 1:
        context.read<InvoicesProvider>().loadInvoices();
        break;
      case 2:
        context.read<InventoryProvider>().loadInventory();
        break;
      case 3:
        context.read<ReturnsProvider>().loadReturnsHistory();
        break;
      case 4:
        context.read<ShiftProvider>().checkActiveShift(cashierId);
        break;
      case 5:
        context.read<ReportsProvider>().loadReports();
        break;
      case 6:
        context.read<SettingsProvider>().loadSettings();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // If not authenticated, show login view and ensure index is reset
    if (!auth.isAuthenticated) {
      if (_selectedIndex != 0) {
        _selectedIndex = 0;
      }
      return const LoginView();
    }

    // If non-admin is on an admin-only view (e.g. Reports, Settings), reset to POS
    if (!auth.isAdmin && _selectedIndex >= 5) {
      _selectedIndex = 0;
    }

    final views = [
      const POSView(),
      const InvoicesView(),
      const InventoryView(),
      const ReturnsView(),
      const ShiftsView(),
      const ReportsView(),
      const SettingsView(),
    ];

    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // Top Desktop Header
          const DesktopHeader(),

          // Main Body (Sidebar + Active View)
          Expanded(
            child: Row(
              children: [
                // Right Sidebar in RTL layout
                CustomSidebar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onTabSelected,
                ),

                // Main Content View
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: views,
                  ),
                ),
              ],
            ),
          ),

          // Trial Version Bottom Watermark / Bar
          Consumer<LicenseProvider>(
            builder: (context, license, _) {
              if (license.isActivated) return const SizedBox.shrink();

              final isExpired = license.isTrialExpired;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isExpired
                      ? AppColors.error.withValues(alpha: 0.12)
                      : Colors.amber.withValues(alpha: 0.12),
                  border: Border(
                    top: BorderSide(
                      color: isExpired
                          ? AppColors.error.withValues(alpha: 0.3)
                          : Colors.amber.shade700.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExpired ? Icons.lock_clock_rounded : Icons.info_outline_rounded,
                      size: 16,
                      color: isExpired ? AppColors.error : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isExpired
                          ? (license.status?.expirationReason ?? 'نسخة تجريبية منتهية: يرجى تفعيل البرنامج لمتابعة إنشاء الفواتير.')
                          : 'نسخة تجريبية: لا يمكنك إجراء أكثر من 5 فواتير (متبقي ${license.remainingInvoices} فواتير | ${license.daysRemaining} يوم)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isExpired ? AppColors.error : Colors.amber.shade900,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => ActivationDialog.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isExpired ? AppColors.error : Colors.amber.shade800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.vpn_key_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'شراء وتفعيل الآن',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
