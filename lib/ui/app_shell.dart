import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/capsule_list_page.dart';
import 'pages/settings_page.dart';
import '../l10n/app_localizations.dart';

class AppShell extends StatefulWidget {
  final dynamic
  settings; // AppSettings passed from main for theme & locale controls
  const AppShell({super.key, this.settings});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final List<Widget> _pages;

  void _onCreateCapsule() {
    // Delegate to current page if it supports creation
    if (_index == 0 || _index == 1) {
      // Use Navigator to push the create page defined in list page file
      // To avoid circular import, we request the page by route name.
      Navigator.of(context).pushNamed('/create');
    }
  }

  @override
  Widget build(BuildContext context) {
    _pages = [
      const DashboardPage(),
      const CapsuleListPage(),
      SettingsPage(settings: widget.settings),
    ];
    final isWide = MediaQuery.of(context).size.width >= 800;
    final l10n = AppLocalizations.of(context);
    final rail = NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      labelType: isWide
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.selected,
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: Text(l10n.dashboard),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.list_alt_outlined),
          selectedIcon: const Icon(Icons.list_alt),
          label: Text(l10n.capsules),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: Text(l10n.settings),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: 'Language',
            icon: Icon(
              Localizations.localeOf(context).languageCode == 'zh'
                  ? Icons.language
                  : Icons.translate,
            ),
            onPressed: () {
              final isZh = Localizations.localeOf(context).languageCode == 'zh';
              widget.settings?.setLocale(
                isZh ? const Locale('en') : const Locale('zh'),
              );
            },
          ),
          IconButton(
            tooltip: 'Theme',
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              widget.settings?.setThemeMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          rail,
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
        ],
      ),
      floatingActionButton: (_index == 0 || _index == 1)
          ? FloatingActionButton(
              onPressed: _onCreateCapsule,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
