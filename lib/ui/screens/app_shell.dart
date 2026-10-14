import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/ad_popup_dialog.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'radio_screen.dart';

/// Root navigation shell with 4 destinations:
/// Home | Library | Radio | Profile
/// Responsive: Bottom Bar (mobile), Navigation Rail (desktop/tablet).
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  static void selectTab(BuildContext context, int index) {
    final _AppShellState? state = context.findAncestorStateOfType<_AppShellState>();
    state?._onDestinationSelected(index);
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdPopupDialog.showIfAvailable(context);
    });
  }

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    LibraryScreen(),
    RadioScreen(),
    ProfileScreen(),
  ];

  void _onDestinationSelected(int i) {
    if (_index == i) {
      // Re-tapping current active tab
      if (i == 0) {
        HomeScreen.resetToDefaultAndRefresh();
      } else if (i == 1) {
        // Tapped Library again -> reset search query and category filter
        LibraryScreen.resetToDefault(context);
      }
      return;
    }

    final int prevIndex = _index;
    setState(() => _index = i);

    // If switching to Home, reset mood tabs to 'All'
    if (i == 0) {
      HomeScreen.resetToDefaultAndRefresh();
    }
    // If switching to or leaving library tab, ensure filter and search are reset
    if (i == 1 || prevIndex == 1) {
      LibraryScreen.resetToDefault(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 800;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            // Desktop Sidebar Navigation Rail
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _onDestinationSelected,
              backgroundColor: isDark ? AppColors.darkBg : AppColors.lightNavSurface,
              indicatorColor: isDark
                  ? AppColors.primary.withValues(alpha: 0.20)
                  : AppColors.lightPrimaryAccent.withValues(alpha: 0.14),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 24),
                ),
              ),
              destinations: <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded, color: isDark ? AppColors.primaryLight : AppColors.lightSelectedNav),
                  label: const Text('Home'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded, color: isDark ? AppColors.primaryLight : AppColors.lightSelectedNav),
                  label: const Text('Library'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.radio_outlined),
                  selectedIcon: Icon(Icons.radio_rounded, color: isDark ? AppColors.primaryLight : AppColors.lightSelectedNav),
                  label: const Text('Radio'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded, color: isDark ? AppColors.primaryLight : AppColors.lightSelectedNav),
                  label: const Text('Profile'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // Main Content Area + Desktop MiniPlayer
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: IndexedStack(index: _index, children: _pages),
                  ),
                  const MiniPlayer(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Navigation Shell
    final Widget mobileScaffold = Scaffold(
      extendBody: false,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const MiniPlayer(),
            Container(
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkBg : AppColors.lightNavSurface).withValues(alpha: 0.94),
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                    width: 0.8,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _onDestinationSelected,
                height: 64,
                elevation: 0,
                backgroundColor: Colors.transparent,
                destinations: const <NavigationDestination>[
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.library_music_outlined),
                    selectedIcon: Icon(Icons.library_music_rounded),
                    label: 'Library',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.radio_outlined),
                    selectedIcon: Icon(Icons.radio_rounded),
                    label: 'Radio',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        final bool? exitApp = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Exit Kalpkrut Beats?'),
            content: const Text('Are you sure you want to close the application?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primary : AppColors.lightPrimaryAccent,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (exitApp == true) {
          SystemNavigator.pop();
        }
      },
      child: mobileScaffold,
    );
  }
}
