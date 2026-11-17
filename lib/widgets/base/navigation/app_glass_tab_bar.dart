import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_backend.dart';

class AppGlassTabItem {
  const AppGlassTabItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });

  final Widget icon;
  final Widget? activeIcon;
  final String label;
}

class AppGlassTabBar extends StatelessWidget {
  const AppGlassTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.barHeight,
    required this.verticalPadding,
    required this.horizontalPadding,
    required this.barBorderRadius,
    required this.iconSize,
    required this.labelFontSize,
    required this.selectedIconColor,
    required this.unselectedIconColor,
    required this.selectedLabelColor,
    required this.unselectedLabelColor,
    required this.selectedLabelStyle,
    required this.unselectedLabelStyle,
  });

  final List<AppGlassTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double barHeight;
  final double verticalPadding;
  final double horizontalPadding;
  final double barBorderRadius;
  final double iconSize;
  final double labelFontSize;
  final Color selectedIconColor;
  final Color unselectedIconColor;
  final Color selectedLabelColor;
  final Color unselectedLabelColor;
  final TextStyle selectedLabelStyle;
  final TextStyle unselectedLabelStyle;

  @override
  Widget build(BuildContext context) {
    return AppGlassTabBarBackend(
      tabs: <AppGlassTabData>[
        for (final tab in tabs)
          AppGlassTabData(
            icon: tab.icon,
            activeIcon: tab.activeIcon,
            label: tab.label,
          ),
      ],
      selectedIndex: selectedIndex,
      onTabSelected: onTabSelected,
      barHeight: barHeight,
      verticalPadding: verticalPadding,
      horizontalPadding: horizontalPadding,
      barBorderRadius: barBorderRadius,
      iconSize: iconSize,
      labelFontSize: labelFontSize,
      selectedIconColor: selectedIconColor,
      unselectedIconColor: unselectedIconColor,
      selectedLabelColor: selectedLabelColor,
      unselectedLabelColor: unselectedLabelColor,
      selectedLabelStyle: selectedLabelStyle,
      unselectedLabelStyle: unselectedLabelStyle,
    );
  }
}
