import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../tables/screens/tables_screen.dart';
import 'dashboard_screen.dart';
import '../../menu/screens/menu_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../orders/screens/admin_orders_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    TablesScreen(),
    DashboardScreen(),
    AdminOrdersScreen(),
    MenuScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final mediaQuery = MediaQuery.of(context);
    final isTablet = mediaQuery.size.width >= 600;

    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.table_restaurant_outlined),
        selectedIcon: const Icon(Icons.table_restaurant, color: Colors.white),
        label: l10n.translate('tables'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard, color: Colors.white),
        label: l10n.translate('dashboard'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.admin_panel_settings_outlined),
        selectedIcon: const Icon(Icons.admin_panel_settings, color: Colors.white),
        label: l10n.translate('admin_orders'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.restaurant_menu_outlined),
        selectedIcon: const Icon(Icons.restaurant_menu, color: Colors.white),
        label: l10n.translate('grill_menu'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long, color: Colors.white),
        label: l10n.translate('reports'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings, color: Colors.white),
        label: l10n.translate('settings'),
      ),
    ];

    return Directionality(
      textDirection: l10n.textDirection,
      child: Scaffold(
        body: Column(
          children: [
            if (!isOnline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: Colors.amber.shade800,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.translate('offline_sync'),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Row(
                children: [
                  if (isTablet) ...[
                    // Sidebar Navigation Rail for Tablets / Wide Screens
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) {
                        setState(() => _selectedIndex = index);
                      },
                      backgroundColor: Theme.of(context).cardTheme.color,
                      indicatorColor: AppTheme.primaryColor,
                      labelType: NavigationRailLabelType.all,
                      extended: mediaQuery.size.width >= 900,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 48,
                          errorBuilder: (context, _, __) => const Icon(
                            Icons.local_fire_department_rounded,
                            color: AppTheme.primaryColor,
                            size: 36,
                          ),
                        ),
                      ),
                      destinations: destinations
                          .map(
                            (d) => NavigationRailDestination(
                              icon: d.icon,
                              selectedIcon: d.selectedIcon,
                              label: Text(d.label),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                  ],
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _screens[_selectedIndex],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: !isTablet
            ? NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
                backgroundColor: Theme.of(context).cardTheme.color,
                indicatorColor: AppTheme.primaryColor,
                destinations: destinations,
              )
            : null,
      ),
    );
  }
}
