import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_chrome_settings.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_quality.dart';

/// 桌面列表的玻璃控制条骨架。
///
/// 左右两组由页面自行组合：左侧通常是筛选入口 + 总数，右侧通常是排序入口 +
/// 选择入口。弹层、间距和筛选更新反馈由本组件统一处理。
class AppGlassListHeader extends StatelessWidget {
  const AppGlassListHeader({
    super.key,
    this.leading,
    this.trailing,
    this.filterUpdate = const FilterUpdateState.idle(),
    this.hasPreviousFilterItems = true,
    this.onRetryFilter,
  });

  final Widget? leading;
  final Widget? trailing;

  final FilterUpdateState filterUpdate;
  final bool hasPreviousFilterItems;
  final VoidCallback? onRetryFilter;

  @override
  Widget build(BuildContext context) {
    final leadingWidget = leading;
    final trailingWidget = trailing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [?leadingWidget, ?trailingWidget],
              ),
            ),
          ),
        ),
        AppFilterUpdateBar(
          state: filterUpdate,
          hasPreviousItems: hasPreviousFilterItems,
          onRetry: onRetryFilter,
        ),
      ],
    );
  }
}

/// 玻璃控制条里的一组按钮。
class AppGlassHeaderGroup extends StatelessWidget {
  const AppGlassHeaderGroup({super.key, required this.children});

  static const double height = 36;
  static const double radius = height / 2;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return GlassButtonGroup(
      borderRadius: radius,
      quality: AppGlassQuality.groupedActions,
      useOwnLayer: true,
      settings: appGlassHeaderSettings(context),
      showDividers: false,
      children: children,
    );
  }
}

/// 玻璃分组里的可点击项：图标 + 文案 + 可选尾部箭头。
class AppGlassHeaderButton extends StatelessWidget {
  const AppGlassHeaderButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingIcon,
    this.enabled = true,
    this.tooltip,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconData? trailingIcon;
  final bool enabled;
  final String? tooltip;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    final bodyStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.medium,
      tone: AppTextTone.primary,
    ).copyWith(color: foregroundColor);
    final button = GlassButton.custom(
      onTap: onTap,
      enabled: enabled,
      height: AppGlassHeaderGroup.height,
      style: GlassButtonStyle.transparent,
      shape: const LiquidRoundedRectangle(
        borderRadius: AppGlassHeaderGroup.radius,
      ),
      stretch: 0.15,
      label: label,
      child: AppGlassGroupContent(
        children: [
          Icon(icon, size: componentTokens.iconSizeXs, color: foregroundColor),
          SizedBox(width: spacing.xs),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: componentTokens.mobileFilterEntryMaxLabelWidth,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle,
            ),
          ),
          if (trailingIcon != null) ...[
            SizedBox(width: spacing.xs),
            Icon(
              trailingIcon,
              size: componentTokens.iconSizeXs,
              color: foregroundColor,
            ),
          ],
        ],
      ),
    );
    final resolvedTooltip = tooltip;
    if (resolvedTooltip == null || resolvedTooltip.isEmpty) {
      return button;
    }
    return Tooltip(message: resolvedTooltip, child: button);
  }
}

/// 玻璃分组里的只读信息，例如总数。
class AppGlassHeaderText extends StatelessWidget {
  const AppGlassHeaderText({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.appSpacing.md),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.appComponentTokens.mobileFilterEntryMaxLabelWidth,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.primary,
          ),
        ),
      ),
    );
  }
}

/// 标准筛选入口 + 可选只读信息（总数等）。
class AppGlassFilterGroup extends StatelessWidget {
  const AppGlassFilterGroup({
    super.key,
    required this.label,
    required this.onTap,
    this.buttonKey,
    this.tooltip,
    this.info = const <Widget>[],
  });

  final String label;
  final VoidCallback onTap;
  final Key? buttonKey;
  final String? tooltip;
  final List<Widget> info;

  @override
  Widget build(BuildContext context) {
    return AppGlassHeaderGroup(
      children: [
        AppGlassHeaderButton(
          key: buttonKey,
          icon: Icons.tune_rounded,
          label: label,
          trailingIcon: Icons.expand_more_rounded,
          tooltip: tooltip ?? appL10n(context).baseFilterTooltip,
          onTap: onTap,
        ),
        ...info,
      ],
    );
  }
}

/// 玻璃多选顶栏里的一个批量动作。
class AppGlassSelectionAction {
  const AppGlassSelectionAction({
    required this.label,
    required this.onTap,
    this.key,
    this.icon = Icons.check_circle_outline,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onTap;
  final Key? key;
  final IconData icon;
  final Color? foregroundColor;
}

/// 玻璃多选顶栏：左侧退出 + 已选计数，右侧全选 + 批量动作。
class AppGlassSelectionHeader extends StatelessWidget {
  const AppGlassSelectionHeader({
    super.key,
    required this.selectionLabel,
    required this.selectAllLabel,
    required this.onExitSelection,
    required this.onToggleAll,
    required this.actions,
    this.countKey,
    this.selectAllKey,
    this.exitKey,
  });

  final String selectionLabel;
  final String selectAllLabel;
  final VoidCallback? onExitSelection;
  final VoidCallback? onToggleAll;
  final List<AppGlassSelectionAction> actions;
  final Key? countKey;
  final Key? selectAllKey;
  final Key? exitKey;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppGlassHeaderGroup(
          children: <Widget>[
            AppGlassHeaderButton(
              key: exitKey,
              icon: Icons.close_rounded,
              label: l10n.commonCancel,
              onTap: onExitSelection ?? () {},
              enabled: onExitSelection != null,
            ),
            AppGlassHeaderText(key: countKey, label: selectionLabel),
          ],
        ),
        const Spacer(),
        AppGlassHeaderGroup(
          children: <Widget>[
            AppGlassHeaderButton(
              key: selectAllKey,
              icon: Icons.select_all_rounded,
              label: selectAllLabel,
              onTap: onToggleAll ?? () {},
              enabled: onToggleAll != null,
            ),
            for (final action in actions)
              AppGlassHeaderButton(
                key: action.key,
                icon: action.icon,
                label: action.label,
                onTap: action.onTap ?? () {},
                enabled: action.onTap != null,
                foregroundColor: action.foregroundColor,
              ),
          ],
        ),
      ],
    );
  }
}

class AppGlassGroupContent extends StatelessWidget {
  const AppGlassGroupContent({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.appSpacing.md),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
