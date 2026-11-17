import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';
import 'package:sakuramedia/widgets/shell/desktop/desktop_chrome_policy.dart';

class AppSidebarItem extends StatefulWidget {
  const AppSidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.selected,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  /// 尾部未读角标数；`null` 或 `<= 0` 不显示。
  final int? badgeCount;

  @override
  State<AppSidebarItem> createState() => _AppSidebarItemState();
}

class _AppSidebarItemState extends State<AppSidebarItem> {
  bool _hovered = false;

  bool get _hasBadge => (widget.badgeCount ?? 0) > 0;

  String get _badgeLabel {
    final count = widget.badgeCount ?? 0;
    return count > 99 ? '99+' : '$count';
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final sidebarTokens = context.appSidebarTokens;
    final useDesktopSidebarGlass = DesktopChromePolicy.of(
      context,
    ).usesGlassSidebar;
    final flat = AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat;
    final selected = widget.selected;
    final hoverBackground = flat
        ? appColors.surfaceMuted.withValues(alpha: 0.5)
        : useDesktopSidebarGlass
        ? appColors.desktopSidebarGlassHover
        : appColors.sidebarHoverBackground.withValues(alpha: 0.5);
    final selectedBackground = flat
        ? appColors.surfaceMuted
        : useDesktopSidebarGlass
        ? appColors.desktopSidebarGlassActive
        : appColors.sidebarActiveBackground;
    final idleBackground = hoverBackground.withValues(alpha: 0);
    final backgroundColor = selected
        ? selectedBackground
        : _hovered
        ? hoverBackground
        : idleBackground;

    final foregroundColor = context.appTextPalette.primary;
    final labelStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s14,
      weight: selected ? AppTextWeight.medium : AppTextWeight.regular,
      tone: selected ? AppTextTone.primary : AppTextTone.secondary,
    );

    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.xs),
        child: AppInteractiveSurface(
          onTap: widget.onTap,
          onHoverChanged: (hovered) {
            if (_hovered == hovered) {
              return;
            }
            setState(() => _hovered = hovered);
          },
          focusRingRadius: context.appRadius.smBorder,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: sidebarTokens.itemHeight,
            padding: EdgeInsets.symmetric(horizontal: context.appSpacing.md),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: context.appRadius.smBorder,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  widget.icon,
                  size: context.appComponentTokens.iconSizeSm,
                  color: foregroundColor,
                ),
                SizedBox(width: context.appSpacing.md),
                Expanded(child: Text(widget.label, style: labelStyle)),
                if (_hasBadge) ...[
                  SizedBox(width: context.appSpacing.sm),
                  AppBadge(
                    key: const Key('sidebar-item-badge'),
                    label: _badgeLabel,
                    tone: AppBadgeTone.error,
                    size: AppBadgeSize.compact,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
