import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'archive_page.dart';
import 'download_manager_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

class NavigationHelper {
  static const int homeTab = 0;
  static const int archiveTab = 1;
  static const int downloadTab = 2;
  static const int settingsTab = 3;

  static _MainLayoutState? _state(BuildContext context) {
    return context.findAncestorStateOfType<_MainLayoutState>();
  }

  static NavigatorState? getNavigatorState(BuildContext context, int tabIndex) {
    return _state(context)?._navigatorKeys[tabIndex].currentState;
  }

  static int getCurrentTabIndex(BuildContext context) {
    return _state(context)?.currentTabIndex ?? homeTab;
  }

  static void pushPage(BuildContext context, int tabIndex, Widget page) {
    getNavigatorState(
      context,
      tabIndex,
    )?.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  static void pushPageInCurrentTab(BuildContext context, Widget page) {
    pushPage(context, getCurrentTabIndex(context), page);
  }

  static void popPage(BuildContext context, int tabIndex) {
    final navigator = getNavigatorState(context, tabIndex);
    if (navigator?.canPop() ?? false) navigator?.pop();
  }

  static void popPageInCurrentTab(BuildContext context) {
    popPage(context, getCurrentTabIndex(context));
  }

  static bool canPop(BuildContext context, int tabIndex) {
    return getNavigatorState(context, tabIndex)?.canPop() ?? false;
  }

  static bool canPopInCurrentTab(BuildContext context) {
    return canPop(context, getCurrentTabIndex(context));
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static const double _expandedWidth = 224;
  static const double _collapsedWidth = 72;

  int _selectedIndex = 0;
  bool _isCollapsed = false;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );

  late final List<NavigationItem> _navigationItems = const [
    NavigationItem(icon: LucideIcons.house, label: 'Home', page: HomePage()),
    NavigationItem(
      icon: LucideIcons.archive,
      label: 'Archive',
      page: ArchivePage(),
    ),
    NavigationItem(
      icon: LucideIcons.download,
      label: 'Downloads',
      page: DownloadManagerPage(),
    ),
    NavigationItem(
      icon: LucideIcons.settings,
      label: 'Settings',
      page: SettingsPage(),
    ),
  ];

  int get currentTabIndex => _selectedIndex;

  void _selectTab(int index) {
    if (_selectedIndex == index) {
      final navigator = _navigatorKeys[index].currentState;
      navigator?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _handleBack(bool didPop) {
    if (didPop) return;
    final navigator = _navigatorKeys[_selectedIndex].currentState;
    if (navigator?.canPop() ?? false) navigator?.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return PopScope<void>(
      canPop: !(_navigatorKeys[_selectedIndex].currentState?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: Row(
          children: [
            if (!isCompact) _buildSidebar(theme),
            Expanded(child: _buildContent(theme)),
          ],
        ),
        bottomNavigationBar: isCompact ? _buildBottomNavigation(theme) : null,
      ),
    );
  }

  Widget _buildSidebar(ShadThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: _isCollapsed ? _collapsedWidth : _expandedWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(right: BorderSide(color: theme.colorScheme.border)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: _isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      LucideIcons.ship,
                      size: 19,
                      color: theme.colorScheme.primaryForeground,
                    ),
                  ),
                  if (!_isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(child: Text('shiplus', style: theme.textTheme.h4)),
                  ],
                ],
              ),
            ),
            ShadSeparator.horizontal(
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _navigationItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (_, index) {
                  final item = _navigationItems[index];
                  return _NavigationButton(
                    item: item,
                    selected: _selectedIndex == index,
                    collapsed: _isCollapsed,
                    onPressed: () => _selectTab(index),
                  );
                },
              ),
            ),
            ShadSeparator.horizontal(
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ShadButton.ghost(
                width: double.infinity,
                leading: Icon(
                  _isCollapsed
                      ? LucideIcons.panelLeftOpen
                      : LucideIcons.panelLeftClose,
                  size: 18,
                ),
                onPressed: () {
                  setState(() => _isCollapsed = !_isCollapsed);
                },
                child: _isCollapsed ? null : const Text('Collapse'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ShadThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.background,
      child: IndexedStack(
        index: _selectedIndex,
        children: _navigationItems.asMap().entries.map((entry) {
          return Navigator(
            key: _navigatorKeys[entry.key],
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              builder: (_) => entry.value.page,
              settings: settings,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomNavigation(ShadThemeData theme) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.card,
          border: Border(top: BorderSide(color: theme.colorScheme.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            children: _navigationItems.asMap().entries.map((entry) {
              final selected = _selectedIndex == entry.key;
              return Expanded(
                child: ShadButton.ghost(
                  foregroundColor: selected
                      ? theme.colorScheme.foreground
                      : theme.colorScheme.mutedForeground,
                  backgroundColor: selected
                      ? theme.colorScheme.accent
                      : Colors.transparent,
                  onPressed: () => _selectTab(entry.key),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(entry.value.icon, size: 19),
                      const SizedBox(height: 3),
                      Text(
                        entry.value.label,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onPressed,
  });

  final NavigationItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final button = ShadButton.ghost(
      width: double.infinity,
      mainAxisAlignment: collapsed
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      foregroundColor: selected
          ? theme.colorScheme.accentForeground
          : theme.colorScheme.mutedForeground,
      backgroundColor: selected ? theme.colorScheme.accent : Colors.transparent,
      leading: Icon(item.icon, size: 19),
      onPressed: onPressed,
      child: collapsed ? null : Text(item.label),
    );

    if (!collapsed) return button;
    return ShadTooltip(builder: (_) => Text(item.label), child: button);
  }
}

class NavigationItem {
  const NavigationItem({
    required this.icon,
    required this.label,
    required this.page,
  });

  final IconData icon;
  final String label;
  final Widget page;
}
