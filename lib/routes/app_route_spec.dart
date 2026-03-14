import 'package:flutter/material.dart';
import 'package:sakuramedia/app/app_platform.dart';

class AppNavItem {
  const AppNavItem({
    required this.name,
    required this.label,
    required this.path,
    required this.icon,
    required this.description,
  });

  final String name;
  final String label;
  final String path;
  final IconData icon;
  final String description;
}

class AppNavGroup {
  const AppNavGroup({
    required this.id,
    required this.label,
    required this.icon,
    required this.items,
    this.isCollapsible = true,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<AppNavItem> items;
  final bool isCollapsible;

  bool get showsChildrenInSidebar => isCollapsible && items.length > 1;

  bool matchesPath(String path) {
    return items.any((item) => item.path == path);
  }
}

class AppRouteSpec {
  const AppRouteSpec({
    required this.platform,
    required this.name,
    required this.path,
    required this.title,
    required this.description,
    required this.groupId,
    required this.layout,
    required this.builder,
  });

  final AppPlatform platform;
  final String name;
  final String path;
  final String title;
  final String description;
  final String groupId;
  final AppShellLayout layout;
  final WidgetBuilder builder;
}
