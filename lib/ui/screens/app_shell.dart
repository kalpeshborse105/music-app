import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

/// Root navigation shell: 4 Stitch destinations with responsive navigation
/// (Bottom Bar for Mobile, Navigation Rail for Desktop/Tablet Web) and a
/// persistent floating MiniPlayer.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    ProfileScreen(),
  ];

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
              onDestinationSelected: (int i) => setState(() => _index = i),
              backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
              indicatorColor: AppColors.primary.withValues(alpha: 0.20),
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
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryLight),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.search_rounded),
                  selectedIcon: Icon(Icons.search_rounded, color: AppColors.primaryLight),
                  label: Text('Search'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded, color: AppColors.primaryLight),
                  label: Text('Library'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded, color: AppColors.primaryLight),
                  label: Text('Profile'),
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
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const MiniPlayer(),
            Container(
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkBg : AppColors.lightBg).withValues(alpha: 0.94),
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                    width: 0.8,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (int i) => setState(() => _index = i),
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
                    icon: Icon(Icons.search_rounded),
                    selectedIcon: Icon(Icons.search_rounded),
                    label: 'Search',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.library_music_outlined),
                    selectedIcon: Icon(Icons.library_music_rounded),
                    label: 'Library',
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
  }
}
