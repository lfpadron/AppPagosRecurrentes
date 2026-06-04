import 'package:flutter/material.dart';

import '../features/calendar/presentation/calendar_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/payments/presentation/payments_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/services/presentation/services_page.dart';
import '../features/settings/presentation/settings_page.dart';
import 'icons/fixed_icon_manifest.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _refreshTokens = List<int>.filled(6, 0);

  Widget _pageForIndex(int index) {
    final key = ValueKey('page-$index-${_refreshTokens[index]}');
    return switch (index) {
      0 => DashboardPage(key: key),
      1 => ServicesPage(key: key),
      2 => PaymentsPage(key: key),
      3 => CalendarPage(key: key),
      4 => ReportsPage(key: key),
      _ => SettingsPage(key: key),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pageForIndex(_index),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() {
          _index = value;
          _refreshTokens[value]++;
        }),
        destinations: const [
          NavigationDestination(
            icon: _NavAssetIcon(FixedIconManifest.navHome),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: _NavAssetIcon(FixedIconManifest.navServices),
            label: 'Servicios',
          ),
          NavigationDestination(
            icon: _NavAssetIcon(FixedIconManifest.navPayments),
            label: 'Pagos',
          ),
          NavigationDestination(
            icon: _NavAssetIcon(FixedIconManifest.navCalendar),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: _NavAssetIcon(FixedIconManifest.navReports),
            label: 'Reportes',
          ),
          NavigationDestination(
            icon: _NavAssetIcon(FixedIconManifest.navSettings),
            label: 'Config',
          ),
        ],
      ),
    );
  }
}

class _NavAssetIcon extends StatelessWidget {
  const _NavAssetIcon(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, width: 26, height: 26, fit: BoxFit.contain);
  }
}
