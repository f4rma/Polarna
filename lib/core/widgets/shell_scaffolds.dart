import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../constants/route_constants.dart';
import 'offline_banner.dart';

// -----------------------------------------------------------------------------
// Shell scaffolds
//
// Each shell wraps the current route's [child] in a [Scaffold] with a
// [BottomNavigationBar]. The selected tab is derived from the current
// GoRouter location (read via `GoRouterState.of(context).uri.path`) so the
// scaffold stays in sync with the URL regardless of how navigation happened.
//
// Navigation uses `context.go(...)` so each tab is a top-level destination
// (no deep back-stack across tabs).
// -----------------------------------------------------------------------------

/// Generic shell — factored out so each role-specific shell only describes
/// its tabs.
class _BottomNavShell extends StatelessWidget {
  final Widget child;
  final List<_NavTab> tabs;

  const _BottomNavShell({
    required this.child,
    required this.tabs,
  });

  int _selectedIndex(String location) {
    // Pick the tab whose path is the longest prefix of the current location.
    var bestIndex = 0;
    var bestLen = -1;
    for (var i = 0; i < tabs.length; i++) {
      final path = tabs[i].path;
      if (location == path || location.startsWith('$path/')) {
        if (path.length > bestLen) {
          bestLen = path.length;
          bestIndex = i;
        }
      }
    }
    return bestIndex;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selected = _selectedIndex(location);
    final homePath = tabs.first.path;
    final isAtHome = location == homePath;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!isAtHome) {
          // Navigasi ke tab Home dulu
          context.go(homePath);
        } else {
          // Sudah di Home → konfirmasi keluar
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Keluar Aplikasi?'),
              content: const Text('Apakah Anda yakin ingin keluar dari Polarna?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          );
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: OfflineBanner(child: child),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) {
            final target = tabs[i].path;
            if (target != location) context.go(target);
          },
          destinations: [
            for (final tab in tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon ?? tab.icon),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTab {
  final String path;
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const _NavTab({
    required this.path,
    required this.icon,
    required this.label,
    this.selectedIcon,
  });
}

// -----------------------------------------------------------------------------
// Role-specific shells
// -----------------------------------------------------------------------------

/// Bottom-nav shell used for the UMKM area of the app.
///
/// Tabs match Figma: Home, Cari, Transaksi, Profil.
class UmkmShell extends StatelessWidget {
  final Widget child;
  const UmkmShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return _BottomNavShell(
      tabs: const [
        _NavTab(
          path: RouteConstants.umkmHome,
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'Home',
        ),
        _NavTab(
          path: _umkmSearchTab,
          icon: Icons.search_outlined,
          selectedIcon: Icons.search,
          label: 'Cari',
        ),
        _NavTab(
          path: RouteConstants.umkmBookings,
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Transaksi',
        ),
        _NavTab(
          path: RouteConstants.umkmProfile,
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profil',
        ),
      ],
      child: child,
    );
  }
}

/// Bottom-nav shell used for the Mitra area of the app.
///
/// Tabs match Figma: Beranda, Gudang, Transaksi, Profil.
class MitraShell extends StatelessWidget {
  final Widget child;
  const MitraShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return _BottomNavShell(
      tabs: const [
        _NavTab(
          path: RouteConstants.mitraDashboard,
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'Beranda',
        ),
        _NavTab(
          path: RouteConstants.mitraWarehouses,
          icon: Icons.warehouse_outlined,
          selectedIcon: Icons.warehouse,
          label: 'Gudang',
        ),
        _NavTab(
          path: _mitraTransactionsTab,
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Transaksi',
        ),
        _NavTab(
          path: RouteConstants.mitraProfile,
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profil',
        ),
      ],
      child: child,
    );
  }
}

/// Bottom-nav shell used for the Admin area of the app.
class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return _BottomNavShell(
      tabs: const [
        _NavTab(
          path: RouteConstants.adminDashboard,
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Dashboard',
        ),
        _NavTab(
          path: RouteConstants.adminUsers,
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'Pengguna',
        ),
        _NavTab(
          path: RouteConstants.adminWarehouses,
          icon: Icons.warehouse_outlined,
          selectedIcon: Icons.warehouse,
          label: 'Gudang',
        ),
        _NavTab(
          path: RouteConstants.adminIncidents,
          icon: Icons.report_problem_outlined,
          selectedIcon: Icons.report_problem,
          label: 'Insiden',
        ),
      ],
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------
// Tab prefix constants
// -----------------------------------------------------------------------------

// The search tab uses the same path as umkmHome (warehouse search page).
// This constant is used for highlight detection in the bottom nav.
const String _umkmSearchTab = '/umkm/search';

// The Mitra transactions tab — shows booking/transaction list for the mitra.
const String _mitraTransactionsTab = '/mitra/transactions';
