import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';

class AppMobileShell extends StatelessWidget {
  const AppMobileShell({
    super.key,
    required this.currentPath,
    required this.navGroups,
    this.currentIndex,
    this.onDestinationSelected = _noopDestinationSelected,
    this.drawer,
    this.drawerEnableOpenDragGesture = false,
    required this.child,
  });

  final String currentPath;
  final List<AppNavGroup> navGroups;
  final int? currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget? drawer;
  final bool drawerEnableOpenDragGesture;
  final Widget child;

  static void _noopDestinationSelected(int _) {}

  @override
  Widget build(BuildContext context) {
    final navItems = navGroups
        .expand((group) => group.items)
        .toList(growable: false);
    final resolvedCurrentIndex =
        currentIndex ?? _resolveCurrentIndex(currentPath, navItems);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _mobileSystemOverlayStyle(context),
      child: Scaffold(
        backgroundColor: context.appColors.surfaceCard,
        drawer: drawer,
        drawerEnableOpenDragGesture:
            drawer != null && drawerEnableOpenDragGesture,
        body: SafeArea(
          key: const Key('mobile-shell-body-safe-area'),
          bottom: false,
          child: Padding(
            key: const Key('mobile-shell-body-padding'),
            padding: AppPageInsets.compactStandard,
            child: child,
          ),
        ),
        bottomNavigationBar: SafeArea(
          key: const Key('mobile-shell-bottom-safe-area'),
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.appColors.divider)),
            ),
            child: CupertinoTabBar(
              key: const Key('mobile-bottom-navigation'),
              height: context.appComponentTokens.mobileBottomNavHeight,
              iconSize: context.appComponentTokens.iconSizeXl,
              backgroundColor: context.appColors.surfaceCard,
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: context.appTextPalette.secondary,
              currentIndex: resolvedCurrentIndex,
              items: navItems
                  .map(
                    (item) => BottomNavigationBarItem(
                      icon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(growable: false),
              onTap: (index) => _handleDestinationTap(context, navItems, index),
            ),
          ),
        ),
      ),
    );
  }

  void _handleDestinationTap(
    BuildContext context,
    List<AppNavItem> navItems,
    int index,
  ) {
    if (onDestinationSelected != _noopDestinationSelected) {
      onDestinationSelected(index);
      return;
    }
    // 在未接入 StatefulShellRoute 的场景下，回退到传统的 go 导航。
    final router = GoRouter.maybeOf(context);
    if (router == null || index < 0 || index >= navItems.length) {
      return;
    }
    router.go(navItems[index].path);
  }

  int _resolveCurrentIndex(String path, List<AppNavItem> navItems) {
    for (var index = 0; index < navItems.length; index += 1) {
      final item = navItems[index];
      if (path == item.path || path.startsWith('${item.path}/')) {
        return index;
      }
    }
    return 0;
  }

  SystemUiOverlayStyle _mobileSystemOverlayStyle(BuildContext context) {
    return SystemUiOverlayStyle(
      statusBarColor: context.appColors.surfaceCard,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: context.appColors.surfaceCard,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: context.appColors.divider,
    );
  }
}
