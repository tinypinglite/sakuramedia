import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';

class AppMobileShell extends StatelessWidget {
  const AppMobileShell({
    super.key,
    required this.currentPath,
    required this.navGroups,
    required this.child,
  });

  final String currentPath;
  final List<AppNavGroup> navGroups;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final navItems = navGroups
        .expand((group) => group.items)
        .toList(growable: false);
    final selectedIndex = _selectedIndex(navItems, currentPath);

    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.appColors.divider)),
        ),
        child: CupertinoTabBar(
          key: const Key('mobile-bottom-navigation'),
          height: 52,
          iconSize: 24,
          backgroundColor: context.appColors.surfaceCard,
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: context.appColors.textSecondary,
          currentIndex: selectedIndex,
          items: navItems
              .map(
                (item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  label: item.label,
                ),
              )
              .toList(growable: false),
          onTap: (index) {
            final targetPath = navItems[index].path;
            if (targetPath == currentPath) {
              return;
            }
            context.go(targetPath);
          },
        ),
      ),
    );
  }

  int _selectedIndex(List<AppNavItem> navItems, String path) {
    final exactIndex = navItems.indexWhere((item) => item.path == path);
    if (exactIndex >= 0) {
      return exactIndex;
    }
    final prefixIndex = navItems.indexWhere(
      (item) => path.startsWith(item.path),
    );
    if (prefixIndex >= 0) {
      return prefixIndex;
    }
    return 0;
  }
}
