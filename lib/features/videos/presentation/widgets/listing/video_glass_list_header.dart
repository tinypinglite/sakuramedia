import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_glass_list_popover.dart';

/// 桌面视频列表的液态玻璃控制条。
///
/// 筛选/总数和排序/选择各自是一个 [GlassButtonGroup]，中间保持透明。
/// 两个弹层都由库的 [GlassPopover] 承载，内容使用透明轨道的分段控件；
/// 选中态只靠中性浮起胶囊和字重区分，不给选项上品牌色。
class VideoGlassListHeader extends StatelessWidget {
  const VideoGlassListHeader({
    super.key,
    required this.filterState,
    required this.total,
    required this.filterUpdate,
    required this.hasPreviousFilterItems,
    required this.onFilterChanged,
    required this.onRetryFilter,
    this.onEnterSelection,
    this.selectionHeader,
    this.totalKey,
  });

  final VideoFilterState filterState;
  final int total;
  final FilterUpdateState filterUpdate;
  final bool hasPreviousFilterItems;
  final ValueChanged<VideoFilterState> onFilterChanged;
  final VoidCallback onRetryFilter;
  final VoidCallback? onEnterSelection;
  final Widget? selectionHeader;
  final Key? totalKey;

  static const double _groupHeight = 44;
  static const double _groupRadius = 22;

  @override
  Widget build(BuildContext context) {
    if (selectionHeader != null) {
      return selectionHeader!;
    }

    final l10n = AppLocalizations.of(context);
    final settings = _glassSettings(context);
    final bodyStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.medium,
      tone: AppTextTone.primary,
    );
    final popoverSettings = _popoverSettings(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GlassPopover(
              popoverWidth: 468,
              popoverBorderRadius: 24,
              autoAdjustToScreen: true,
              screenPadding: const EdgeInsets.all(16),
              quality: GlassQuality.minimal,
              settings: popoverSettings,
              triggerBuilder: (context, toggle) =>
                  _filterGroup(context, l10n, bodyStyle, settings, toggle),
              contentBuilder: (context, _) => VideoGlassFilterPopoverContent(
                key: const Key('videos-filter-popover'),
                filterState: filterState,
                onChanged: onFilterChanged,
              ),
            ),
            const Spacer(),
            GlassPopover(
              popoverWidth: 468,
              popoverBorderRadius: 24,
              autoAdjustToScreen: true,
              screenPadding: const EdgeInsets.all(16),
              quality: GlassQuality.minimal,
              settings: popoverSettings,
              triggerBuilder: (context, toggle) => _sortAndSelectionGroup(
                context,
                l10n,
                bodyStyle,
                settings,
                toggle,
              ),
              contentBuilder: (context, _) => VideoGlassSortPopoverContent(
                key: const Key('videos-sort-popover'),
                filterState: filterState,
                onChanged: onFilterChanged,
              ),
            ),
          ],
        ),
        AppFilterUpdateBar(
          state: filterUpdate,
          hasPreviousItems: hasPreviousFilterItems,
          onRetry: onRetryFilter,
        ),
      ],
    );
  }

  Widget _filterGroup(
    BuildContext context,
    AppLocalizations l10n,
    TextStyle bodyStyle,
    LiquidGlassSettings settings,
    VoidCallback toggle,
  ) {
    final spacing = context.appSpacing;
    return GlassButtonGroup(
      borderRadius: _groupRadius,
      quality: GlassQuality.premium,
      useOwnLayer: true,
      settings: settings,
      showDividers: false,
      children: [
        GlassButton.custom(
          key: const Key('videos-filter-trigger'),
          onTap: toggle,
          height: _groupHeight,
          style: GlassButtonStyle.transparent,
          shape: const LiquidRoundedRectangle(borderRadius: _groupRadius),
          stretch: 0.15,
          child: _GroupContent(
            children: [
              Icon(
                Icons.tune_rounded,
                size: context.appComponentTokens.iconSizeXs,
              ),
              SizedBox(width: spacing.xs),
              Text(filterState.triggerLabel(l10n), style: bodyStyle),
              SizedBox(width: spacing.xs),
              Icon(
                Icons.expand_more_rounded,
                size: context.appComponentTokens.iconSizeXs,
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md),
          child: Text(
            l10n.videoTotalCount(total),
            key: totalKey ?? const Key('videos-page-total'),
            style: bodyStyle,
          ),
        ),
      ],
    );
  }

  Widget _sortAndSelectionGroup(
    BuildContext context,
    AppLocalizations l10n,
    TextStyle bodyStyle,
    LiquidGlassSettings settings,
    VoidCallback toggle,
  ) {
    final spacing = context.appSpacing;
    final field = filterState.sortField;
    return GlassButtonGroup(
      borderRadius: _groupRadius,
      quality: GlassQuality.premium,
      useOwnLayer: true,
      settings: settings,
      showDividers: false,
      children: [
        GlassButton.custom(
          key: const Key('videos-sort-trigger'),
          onTap: toggle,
          height: _groupHeight,
          style: GlassButtonStyle.transparent,
          shape: const LiquidRoundedRectangle(borderRadius: _groupRadius),
          stretch: 0.15,
          child: _GroupContent(
            children: [
              Icon(
                Icons.swap_vert_rounded,
                size: context.appComponentTokens.iconSizeXs,
              ),
              SizedBox(width: spacing.xs),
              Text(
                '${field.labelWith(l10n)} ${filterState.sortDirection.symbol}',
                style: bodyStyle,
              ),
              SizedBox(width: spacing.xs),
              Icon(
                Icons.expand_more_rounded,
                size: context.appComponentTokens.iconSizeXs,
              ),
            ],
          ),
        ),
        if (onEnterSelection != null)
          GlassButton.custom(
            key: const Key('videos-enter-selection-button'),
            onTap: onEnterSelection!,
            height: _groupHeight,
            style: GlassButtonStyle.transparent,
            shape: const LiquidRoundedRectangle(borderRadius: _groupRadius),
            stretch: 0.15,
            child: _GroupContent(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: context.appComponentTokens.iconSizeXs,
                ),
                SizedBox(width: spacing.xs),
                Text(l10n.baseSelect, style: bodyStyle),
              ],
            ),
          ),
      ],
    );
  }

  LiquidGlassSettings _glassSettings(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? LiquidGlassSettings.ios27Dark
        : LiquidGlassSettings.ios27Light;
  }

  LiquidGlassSettings _popoverSettings(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _glassSettings(context).copyWith(
      glassColor: isDark
          ? context.appColors.surfaceCard
          : context.appColors.surfaceMuted,
      blur: 0,
      frost: 0,
      frostOpacity: 0,
      bodyMode: GlassBodyMode.clear,
      shadowElevation: isDark ? 0 : 2,
    );
  }
}

class _GroupContent extends StatelessWidget {
  const _GroupContent({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.appSpacing.md),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
