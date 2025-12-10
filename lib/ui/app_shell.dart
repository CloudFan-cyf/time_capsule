import 'package:flutter/material.dart';
import 'package:time_capsule/generated/l10n.dart';

import 'pages/dashboard_page.dart';
import 'pages/capsule_list_page.dart';
import 'pages/settings_page.dart';
import 'package:time_capsule/providers/auxiliary/theme_manager.dart';
import 'package:time_capsule/providers/auxiliary/theme_scope.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final _pages = const [DashboardPage(), CapsuleListPage(), SettingsPage()];

  void _onCreateCapsule() {
    if (_index == 0 || _index == 1) {
      Navigator.of(context).pushNamed('/create');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 800;
    final l10n = S.of(context);

    final railDestinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: Text(l10n.navDashboard),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.list_alt_outlined),
        selectedIcon: const Icon(Icons.list_alt),
        label: Text(l10n.navCapsules),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: Text(l10n.navSettings),
      ),
    ];

    final barDestinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: l10n.navDashboard,
      ),
      NavigationDestination(
        icon: const Icon(Icons.list_alt_outlined),
        selectedIcon: const Icon(Icons.list_alt),
        label: l10n.navCapsules,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: l10n.navSettings,
      ),
    ];

    final content = IndexedStack(index: _index, children: _pages);

    final rail = NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      extended: width >= 1000, // 更宽时自动展开显示文字（可按需调整）
      destinations: railDestinations,
    );

    final bottomBar = NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      destinations: barDestinations,
    );

    final showFab = (_index == 0 || _index == 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          Builder(
            builder: (context) {
              final tm = ThemeScope.of(context);
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                onPressed: () {
                  // 切换为明/暗主题；再次点击可来回切换
                  tm.themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
                },
              );
            },
          ),
        ],
      ),
      body: useRail
          ? Row(
              children: [
                rail,
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: useRail ? null : bottomBar,
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: _onCreateCapsule,
              tooltip: l10n.createCapsule,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
