import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
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
  bool _focused = false;

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
    final isHighlighted = !widget.selected && (_hovered || _focused);
    final backgroundColor = useDesktopSidebarGlass
        ? widget.selected
              ? appColors.desktopSidebarGlassActive
              : isHighlighted
              ? appColors.desktopSidebarGlassHover
              : Colors.transparent
        : widget.selected
        ? appColors.sidebarActiveBackground
        : isHighlighted
        ? appColors.sidebarHoverBackground
        : appColors.sidebarBackground;

    final foregroundColor = context.appTextPalette.primary;
    final focusBorderColor = Theme.of(context).colorScheme.primary;
    final labelStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s14,
      weight: widget.selected ? AppTextWeight.medium : AppTextWeight.regular,
      tone: widget.selected ? AppTextTone.primary : AppTextTone.secondary,
    );

    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.xs),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: context.appRadius.smBorder,
            mouseCursor: SystemMouseCursors.click,
            onTap: widget.onTap,
            onHover: (hovered) {
              if (_hovered == hovered) {
                return;
              }
              setState(() => _hovered = hovered);
            },
            onFocusChange: (focused) {
              if (!mounted || _focused == focused) {
                return;
              }
              setState(() => _focused = focused);
            },
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: sidebarTokens.itemHeight,
              padding: EdgeInsets.symmetric(horizontal: context.appSpacing.md),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: context.appRadius.smBorder,
              ),
              foregroundDecoration: _focused
                  ? BoxDecoration(
                      borderRadius: context.appRadius.smBorder,
                      border: Border.all(color: focusBorderColor, width: 1.5),
                    )
                  : null,
              child: Row(
                children: [
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
      ),
    );
  }
}
