import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
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

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // If not authenticated, show login view
    if (!auth.isAuthenticated) {
      return const LoginView();
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
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
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
        ],
      ),
    );
  }
}
