import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _tabs = [
    _TabItem(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home, path: '/'),
    _TabItem(label: 'Trips', icon: Icons.flight_takeoff_outlined, activeIcon: Icons.flight_takeoff, path: '/trip/manage'),
    _TabItem(label: 'Market', icon: Icons.store_mall_directory_outlined, activeIcon: Icons.store_mall_directory, path: '/market'),
    _TabItem(label: 'Wallet', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, path: '/wallet'),
    _TabItem(label: 'Inbox', icon: Icons.inbox_outlined, activeIcon: Icons.inbox, path: '/chat'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRealtimeProvider).ensureConnected();
    });
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/market')) return 2;
    if (location.startsWith('/trip') || location.startsWith('/saved-trips')) {
      return 1;
    }
    if (location.startsWith('/wallet')) return 3;
    if (location.startsWith('/chat')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      body: SafeArea(child: widget.child),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) {
          if (i != index) context.go(_tabs[i].path);
        },
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.activeIcon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.label, required this.icon, required this.activeIcon, required this.path});
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;
}
