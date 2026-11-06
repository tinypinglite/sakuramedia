import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

/// 设置页左侧分类栏的单项描述。
class AppSettingsRailItem {
  const AppSettingsRailItem({
    required this.itemKey,
    required this.label,
    this.icon,
  });

  /// 用于测试与点击定位的 key（挂在可点击行上）。
  final Key itemKey;
  final String label;
  final IconData? icon;
}

/// 设置页左侧竖向分类栏（飞书/钉钉式桌面设置骨架）。
///
/// 选中态用浅品牌底 + 品牌色文字，hover 用浅灰；圆角填充项而非通栏，
/// 更贴近国内主流桌面设置的观感。配合右侧分组卡片内容区使用。
class AppSettingsRail extends StatelessWidget {
  const AppSettingsRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.width = _kSettingsRailWidth,
  });

  final List<AppSettingsRailItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double width;

  static const double _kSettingsRailWidth = 188;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return SizedBox(
      width: width,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: spacing.xs),
                child: _RailItem(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppSettingsRailItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final primary = Theme.of(context).colorScheme.primary;

    final labelStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s14,
      weight: selected ? AppTextWeight.medium : AppTextWeight.regular,
      tone: selected ? AppTextTone.primary : AppTextTone.secondary,
    ).copyWith(color: selected ? primary : null);
    final iconColor = selected ? primary : context.appTextPalette.muted;

    return AppInteractiveSurface(
      key: item.itemKey,
      onTap: onTap,
      focusRingRadius: context.appRadius.mdBorder,
      child: Material(
        color: selected ? primary.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: context.appRadius.mdBorder,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm + spacing.xs / 2,
          ),
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: context.appComponentTokens.iconSizeSm,
                  color: iconColor,
                ),
                SizedBox(width: spacing.sm),
              ],
              Expanded(
                child: Text(
                  item.label,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
