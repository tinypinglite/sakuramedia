import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';

/// 移动端底部 tab 主页通用顶部头：一行 chip 横滚 + 右上 filter icon。
///
/// 国内 App 列表 tab 的统一形态（小红书 / 抖音 / 微信视频号 / B 站）：
/// chip 当快速筛选切换、icon 弹底抽屉做完整筛选；不再显示「共 N 部」总数。
class AppMobileTabHeader extends StatelessWidget {
  const AppMobileTabHeader({
    super.key,
    required this.chips,
    this.onFilterTap,
    this.filterIcon = Icons.tune_rounded,
    this.filterTooltip,
    this.filterButtonKey,
    this.trailing,
  });

  final List<AppMobileTabChip> chips;
  final VoidCallback? onFilterTap;
  final IconData filterIcon;
  final String? filterTooltip;
  final Key? filterButtonKey;

  /// 可选：filter icon 左侧的尾随节点（如「更新于 …」小字）。
  /// chip 与它之间用 [Spacer]/[Expanded] 分开，chip 过长会自动横向滚。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    // 与概览页 _MobileOverviewHeader 视觉对齐：top: xs + 固定高度 mobileTopTabHeight。
    return Padding(
      padding: EdgeInsets.only(top: spacing.xs),
      child: SizedBox(
        height: componentTokens.mobileTopTabHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < chips.length; i++) ...[
                      if (i > 0) SizedBox(width: spacing.sm),
                      _ChipButton(chip: chips[i]),
                    ],
                  ],
                ),
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: spacing.sm),
              trailing!,
            ],
            if (onFilterTap != null) ...[
              SizedBox(width: spacing.sm),
              AppIconButton(
                key: filterButtonKey,
                icon: Icon(filterIcon),
                tooltip: filterTooltip,
                onPressed: onFilterTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppMobileTabChip {
  const AppMobileTabChip({
    this.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.trailingIcon,
  });

  final Key? key;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// 「维度 ▾」模式（榜单 tab 的 source/period/sort chip）才传。
  final IconData? trailingIcon;
}

/// chip 自行渲染（不复用 AppTextButton），用「字色+字重」表达选中态而非底色：
/// 未选 → 次色 regular；选中 → 主色 semibold。完全无底色、无边框，最克制。
class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.chip});

  final AppMobileTabChip chip;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tone = chip.isSelected ? AppTextTone.accent : AppTextTone.secondary;
    final weight = chip.isSelected
        ? AppTextWeight.semibold
        : AppTextWeight.regular;
    final foregroundColor = resolveAppTextToneColor(context, tone);
    // 字号 s16 与概览页 AppTabBar.mobileTop 对齐。
    final labelStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s16,
      weight: weight,
      tone: tone,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: chip.key,
        onTap: chip.onTap,
        borderRadius: context.appRadius.smBorder,
        // 去掉 Material 默认的水波纹/按压高光/悬浮态，保留点击区域但视觉无反馈。
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Padding(
          // 整行高度由外层 SizedBox(mobileTopTabHeight) 决定，chip 自身只补
          // 横向 padding 与文字之间的最小留白。
          padding: EdgeInsets.symmetric(horizontal: spacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(chip.label, style: labelStyle),
              if (chip.trailingIcon != null) ...[
                SizedBox(width: spacing.xs),
                Icon(
                  chip.trailingIcon,
                  size: context.appComponentTokens.iconSizeMd,
                  color: foregroundColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
