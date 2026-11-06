import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 移动端一级列表页的大标题。
class AppMobilePageTitle extends StatelessWidget {
  const AppMobilePageTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.appSpacing.lg,
        0,
        context.appSpacing.lg,
        context.appSpacing.md,
      ),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s32,
          weight: AppTextWeight.semibold,
          tone: AppTextTone.primary,
          height: 1.05,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

/// 移动列表控制行左侧的标题与计数。
class AppMobileHeaderText extends StatelessWidget {
  const AppMobileHeaderText({
    super.key,
    this.title,
    this.countLabel,
    this.secondaryLabel,
    this.secondaryKey,
  });

  final String? title;
  final String? countLabel;
  final String? secondaryLabel;
  final Key? secondaryKey;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title?.trim() ?? '';
    final resolvedCount = countLabel?.trim() ?? '';
    final resolvedSecondary = secondaryLabel?.trim() ?? '';
    if (resolvedTitle.isEmpty &&
        resolvedCount.isEmpty &&
        resolvedSecondary.isEmpty) {
      return const SizedBox.shrink();
    }

    final titleStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s18,
      weight: AppTextWeight.semibold,
      tone: AppTextTone.primary,
    );
    final metaStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    final primary = Row(
      children: <Widget>[
        if (resolvedTitle.isNotEmpty)
          Flexible(
            child: Text(
              resolvedTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
        if (resolvedTitle.isNotEmpty && resolvedCount.isNotEmpty)
          SizedBox(width: context.appSpacing.xs),
        if (resolvedCount.isNotEmpty)
          Flexible(
            child: Text(
              resolvedCount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: metaStyle,
            ),
          ),
      ],
    );
    if (resolvedSecondary.isEmpty) {
      return primary;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        primary,
        Text(
          resolvedSecondary,
          key: secondaryKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: metaStyle,
        ),
      ],
    );
  }
}

/// 移动列表的透明控制行。
///
/// 标题与计数保持普通文本，操作使用独立的 44×44 玻璃图标钮。筛选项的完整摘要
/// 只放在 tooltip / semantics 中，避免窄屏上恢复文字摘要。
class AppMobileListHeader extends StatelessWidget {
  const AppMobileListHeader({
    super.key,
    this.leading,
    this.actions = const <Widget>[],
    this.filterUpdate = const FilterUpdateState.idle(),
    this.hasPreviousFilterItems = true,
    this.onRetryFilter,
  }) : assert(actions.length <= 4, '移动列表头最多放 4 个图标动作');

  final Widget? leading;
  final List<Widget> actions;
  final FilterUpdateState filterUpdate;
  final bool hasPreviousFilterItems;
  final VoidCallback? onRetryFilter;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final leadingWidget = leading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.sm),
          child: SizedBox(
            height: context.appComponentTokens.mobileTopTabHeight,
            child: Row(
              children: <Widget>[
                if (leadingWidget != null)
                  Expanded(child: leadingWidget)
                else
                  const Spacer(),
                if (actions.isNotEmpty) SizedBox(width: spacing.xs),
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0) SizedBox(width: spacing.xs),
                  actions[index],
                ],
              ],
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

/// 移动列表的紧凑多选头：只保留退出、计数、全选。
///
/// 批量动作仍由页面放在贴底 [AppSelectionBottomBar] 中，避免危险操作与退出挤在
/// 同一处。
class AppMobileSelectionHeader extends StatelessWidget {
  const AppMobileSelectionHeader({
    super.key,
    required this.selectionLabel,
    required this.onExitSelection,
    required this.onToggleAll,
    this.selectAllTooltip,
    this.countKey,
    this.selectAllKey,
    this.exitKey,
  });

  final String selectionLabel;
  final VoidCallback? onExitSelection;
  final VoidCallback? onToggleAll;
  final String? selectAllTooltip;
  final Key? countKey;
  final Key? selectAllKey;
  final Key? exitKey;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.appSpacing.sm),
      child: SizedBox(
        height: context.appComponentTokens.mobileTopTabHeight,
        child: Row(
          children: <Widget>[
            AppGlassIconButton(
              key: exitKey,
              tooltip: l10n.commonCancel,
              icon: Icons.close_rounded,
              onPressed: onExitSelection,
            ),
            SizedBox(width: context.appSpacing.sm),
            Expanded(
              child: Text(
                selectionLabel,
                key: countKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
            AppGlassIconButton(
              key: selectAllKey,
              tooltip: selectAllTooltip ?? l10n.baseSelect,
              icon: Icons.select_all_rounded,
              onPressed: onToggleAll,
            ),
          ],
        ),
      ),
    );
  }
}

/// 移动列表的筛选入口图标钮。
class AppGlassFilterIconButton extends StatelessWidget {
  const AppGlassFilterIconButton({
    super.key,
    required this.summary,
    required this.isActive,
    required this.onPressed,
  });

  final String summary;
  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppGlassIconButton(
      tooltip: summary,
      semanticLabel: summary,
      icon: Icons.tune_rounded,
      foregroundColor: isActive ? Theme.of(context).colorScheme.primary : null,
      onPressed: onPressed,
    );
  }
}
