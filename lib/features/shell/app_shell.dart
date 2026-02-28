import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home, path: '/home'),
    _TabItem(label: 'Network', icon: Icons.people_outline, activeIcon: Icons.people, path: '/network'),
    _TabItem(label: 'Calendar', icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, path: '/calendar'),
    _TabItem(label: 'Chat', icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, path: '/chat'),
    _TabItem(label: 'Alerts', icon: Icons.notifications_outlined, activeIcon: Icons.notifications, path: '/alerts'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(_tabs[index].path),
        items: _tabs
            .map((tab) => BottomNavigationBarItem(
                  icon: Icon(tab.icon),
                  activeIcon: Icon(tab.activeIcon),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}
