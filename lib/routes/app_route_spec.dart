import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/routes/app_route.dart';

class AppNavItem {
  const AppNavItem({
    required this.routeId,
    required this.name,
    required this.label,
    required this.path,
    required this.icon,
    required this.description,
    this.activeIcon,
    this.sectionLabel,
  });

  final AppRouteId routeId;
  final String name;
  final String label;
  final String path;
  final IconData icon;

  /// 选中态使用的实心图标；`null` 时回退到 [icon]。
  final IconData? activeIcon;
  final String description;

  /// 该目的地所属分区的标题。`null` 表示其前不渲染分区标题（如概览置顶）。
  final String? sectionLabel;
}

class AppDrawerSection {
  const AppDrawerSection({
    required this.id,
    required this.header,
    required this.entries,
  });

  final String id;
  final String header;
  final List<AppDrawerEntry> entries;
}

class AppDrawerEntry {
  const AppDrawerEntry({
    required this.key,
    required this.routeId,
    required this.label,
    required this.icon,
    this.badge,
    this.visible,
  });

  final String key;
  final AppRouteId routeId;
  final String label;
  final IconData icon;
  final AppDrawerBadge? badge;
  final bool Function()? visible;
}
