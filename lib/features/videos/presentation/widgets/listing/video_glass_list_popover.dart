import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

/// 桌面视频列表筛选弹层内容。
///
/// 选中态不使用品牌色：轨道保持透明，只让当前项浮起成一枚中性胶囊，
/// 再用字重和下方阴影区分状态。弹层外壳由 [GlassPopover] 提供。
class VideoGlassFilterPopoverContent extends StatelessWidget {
  const VideoGlassFilterPopoverContent({
    super.key,
    required this.filterState,
    required this.onChanged,
  });

  final VideoFilterState filterState;
  final ValueChanged<VideoFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(l10n.videoFilterSectionCollectionOwnership),
          SizedBox(height: spacing.sm),
          _NeutralGlassSegmented<bool>(
            key: const Key('videos-filter-collection'),
            items: [
              _NeutralGlassSegment(value: false, label: l10n.videoFilterAll),
              _NeutralGlassSegment(
                value: true,
                label: l10n.videoFilterNotInCollection,
              ),
            ],
            selected: filterState.uncollected,
            onChanged: (uncollected) =>
                onChanged(filterState.copyWith(uncollected: uncollected)),
          ),
          SizedBox(height: spacing.lg),
          Row(
            children: [
              Text(
                l10n.videoFilterAppliesImmediately,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ),
              ),
              const Spacer(),
              _NeutralResetButton(
                enabled: filterState.hasActiveFilters,
                onPressed: () => onChanged(filterState.resetFilters()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 桌面视频列表排序弹层内容。
class VideoGlassSortPopoverContent extends StatelessWidget {
  const VideoGlassSortPopoverContent({
    super.key,
    required this.filterState,
    required this.onChanged,
  });

  final VideoFilterState filterState;
  final ValueChanged<VideoFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(l10n.baseSortTitle),
          SizedBox(height: spacing.sm),
          _NeutralGlassSegmented<VideoSortField>(
            key: const Key('videos-sort-field'),
            items: [
              for (final field in VideoSortField.values)
                _NeutralGlassSegment(
                  value: field,
                  label: field.labelWith(l10n),
                ),
            ],
            selected: filterState.sortField,
            onChanged: (field) =>
                onChanged(filterState.copyWith(sortField: field)),
          ),
          SizedBox(height: spacing.lg),
          _SectionTitle(l10n.videoSortDirectionTitle),
          SizedBox(height: spacing.sm),
          _NeutralGlassSegmented<SortDirection>(
            key: const Key('videos-sort-direction'),
            items: [
              for (final direction in SortDirection.values)
                _NeutralGlassSegment(
                  value: direction,
                  label: direction.label(l10n),
                ),
            ],
            selected: filterState.sortDirection,
            onChanged: (direction) =>
                onChanged(filterState.copyWith(sortDirection: direction)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.medium,
        tone: AppTextTone.secondary,
      ),
    );
  }
}

class _NeutralGlassSegment<T> {
  const _NeutralGlassSegment({required this.value, required this.label});

  final T value;
  final String label;
}

class _NeutralGlassSegmented<T> extends StatelessWidget {
  const _NeutralGlassSegmented({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final List<_NeutralGlassSegment<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = items.indexWhere((item) => item.value == selected);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inheritedFontFamily = DefaultTextStyle.of(context).style.fontFamily;
    final resolvedUnselectedText = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.secondary,
    );
    final resolvedSelectedText = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.semibold,
      tone: AppTextTone.primary,
    );
    final unselectedText = resolvedUnselectedText.copyWith(
      fontFamily: resolvedUnselectedText.fontFamily ?? inheritedFontFamily,
    );
    final selectedText = resolvedSelectedText.copyWith(
      fontFamily: resolvedSelectedText.fontFamily ?? inheritedFontFamily,
    );
    final indicatorColor = isDark
        ? context.appColors.surfaceMuted
        : context.appColors.surfaceElevated;

    return GlassSegmentedControl.scrollable(
      segments: [
        for (final item in items)
          GlassSegment(
            id: item.value,
            label: item.label,
            semanticLabel: item.label,
          ),
      ],
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onSegmentSelected: (index) {
        if (index < 0 || index >= items.length) {
          return;
        }
        final value = items[index].value;
        if (value == selected) {
          return;
        }
        onChanged(value);
      },
      height: 34,
      borderRadius: 17,
      indicatorBorderRadius: 17,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      backgroundColor: Colors.transparent,
      indicatorColor: indicatorColor,
      indicatorShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
          blurRadius: 7,
          offset: const Offset(0, 2),
        ),
      ],
      selectedTextStyle: selectedText,
      unselectedTextStyle: unselectedText,
      quality: GlassQuality.standard,
    );
  }
}

class _NeutralResetButton extends StatelessWidget {
  const _NeutralResetButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spacing = context.appSpacing;
    return GlassButton.custom(
      key: const Key('videos-filter-reset'),
      onTap: enabled ? onPressed : () {},
      enabled: enabled,
      height: 34,
      shape: const LiquidRoundedRectangle(borderRadius: 17),
      style: GlassButtonStyle.filled,
      settings: LiquidGlassSettings(
        glassColor: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.58),
        thickness: 18,
        frost: 6,
        frostOpacity: 0.5,
        rimLight: 1.4,
        shadowElevation: 0,
        bodyMode: GlassBodyMode.clear,
      ),
      quality: GlassQuality.standard,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restart_alt_rounded,
              size: context.appComponentTokens.iconSize2xs,
            ),
            SizedBox(width: spacing.xs),
            Text(
              AppLocalizations.of(context).baseFilterReset,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.medium,
                tone: AppTextTone.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
