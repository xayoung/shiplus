import 'package:flutter/material.dart';
import 'home_page.dart';
import 'archive_page.dart';
import 'download_manager_page.dart';
import 'settings_page.dart';

// Navigation helper class for navigating between pages
class NavigationHelper {
  // Tab index constants
  static const int homeTab = 0;
  static const int archiveTab = 1;
  static const int downloadTab = 2;
  static const int settingsTab = 3;

  static _MainLayoutState? _getMainLayoutState(BuildContext context) {
    return context.findAncestorStateOfType<_MainLayoutState>();
  }

  static NavigatorState? getNavigatorState(BuildContext context, int tabIndex) {
    final mainLayoutState = _getMainLayoutState(context);
    return mainLayoutState?._navigatorKeys[tabIndex].currentState;
  }

  // Get the currently selected tab index
  static int getCurrentTabIndex(BuildContext context) {
    final mainLayoutState = _getMainLayoutState(context);
    return mainLayoutState?.currentTabIndex ?? 0;
  }

  // Push a new page in the specified tab
  static void pushPage(BuildContext context, int tabIndex, Widget page) {
    final navigator = getNavigatorState(context, tabIndex);
    navigator?.push(MaterialPageRoute(builder: (context) => page));
  }

  // Push a new page in the current tab
  static void pushPageInCurrentTab(BuildContext context, Widget page) {
    final currentTab = getCurrentTabIndex(context);
    pushPage(context, currentTab, page);
  }

  // Pop a page from the specified tab
  static void popPage(BuildContext context, int tabIndex) {
    final navigator = getNavigatorState(context, tabIndex);
    if (navigator?.canPop() == true) {
      navigator?.pop();
    }
  }

  // Pop a page from the current tab
  static void popPageInCurrentTab(BuildContext context) {
    final currentTab = getCurrentTabIndex(context);
    popPage(context, currentTab);
  }

  // Check if the specified tab can pop a page
  static bool canPop(BuildContext context, int tabIndex) {
    final navigator = getNavigatorState(context, tabIndex);
    return navigator?.canPop() ?? false;
  }

  // Check if the current tab can pop a page
  static bool canPopInCurrentTab(BuildContext context) {
    final currentTab = getCurrentTabIndex(context);
    return canPop(context, currentTab);
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isCollapsed = false;
  AnimationController? _animationController;
  Animation<double>? _widthAnimation;

  // Create independent GlobalKey for each page to maintain Navigator state
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.home,
      label: 'Home',
      page: const HomePage(),
    ),
    NavigationItem(
      icon: Icons.archive,
      label: 'Archive',
      page: const ArchivePage(),
    ),
    NavigationItem(
      icon: Icons.download,
      label: 'Download',
      page: const DownloadManagerPage(),
    ),
    NavigationItem(
      icon: Icons.settings,
      label: 'Settings',
      page: const SettingsPage(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _widthAnimation = Tween<double>(
      begin: 200.0,
      end: 60.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isCollapsed = !_isCollapsed;
      if (_isCollapsed) {
        _animationController?.forward();
      } else {
        _animationController?.reverse();
      }
    });
  }

  // Get the currently selected tab index
  int get currentTabIndex => _selectedIndex;

  // Handle back button logic
  Future<bool> _onWillPop() async {
    final navigator = _navigatorKeys[_selectedIndex].currentState;
    if (navigator?.canPop() == true) {
      navigator?.pop();
      return false; // Don't exit app
    }
    return true; // Exit app
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Row(
          children: [
            // Left sidebar
            AnimatedBuilder(
              animation: _widthAnimation ?? const AlwaysStoppedAnimation(200.0),
              builder: (context, child) {
                return Container(
                  width:
                      _widthAnimation?.value ?? (_isCollapsed ? 60.0 : 200.0),
                  color: const Color(0xFF1E1E1E),
                  child: Column(
                    children: [
                      // Top title and collapse button
                      Container(
                        padding: EdgeInsets.all(_isCollapsed ? 8 : 16),
                        child: _isCollapsed
                            ? Center(
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.menu,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: _toggleSidebar,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  const Icon(
                                    Icons.dashboard,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'shiplus',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.menu_open,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: _toggleSidebar,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const Divider(
                        color: Color(0xFF333333),
                        height: 1,
                      ),
                      // Navigation items
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _navigationItems.length,
                          itemBuilder: (context, index) {
                            final item = _navigationItems[index];
                            final isSelected = _selectedIndex == index;

                            Widget navigationItem = Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = index;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: _isCollapsed ? 8 : 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF333333)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _isCollapsed
                                        ? Center(
                                            child: Icon(
                                              item.icon,
                                              color: isSelected
                                                  ? Colors.white
                                                  : const Color(0xFF888888),
                                              size: 20,
                                            ),
                                          )
                                        : Row(
                                            children: [
                                              Icon(
                                                item.icon,
                                                color: isSelected
                                                    ? Colors.white
                                                    : const Color(0xFF888888),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                item.label,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : const Color(0xFF888888),
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w500
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            );

                            // Add tooltip in collapsed state
                            if (_isCollapsed) {
                              return Tooltip(
                                message: item.label,
                                preferBelow: false,
                                child: navigationItem,
                              );
                            }

                            return navigationItem;
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Right content area
            Expanded(
              child: Container(
                color: const Color(0xFFF5F5F5),
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _navigationItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Navigator(
                      key: _navigatorKeys[index],
                      onGenerateRoute: (settings) {
                        return MaterialPageRoute(
                          builder: (context) => item.page,
                          settings: settings,
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final Widget page;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.page,
  });
}
