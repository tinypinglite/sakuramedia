import 'package:flutter/material.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';

class ImageSearchFilterPanel extends StatelessWidget {
  const ImageSearchFilterPanel({
    super.key,
    required this.filterState,
    required this.summaryText,
    required this.onCurrentMovieScopeChanged,
    required this.onModeChanged,
    required this.onSelectActors,
    required this.onSearch,
    this.currentMovieNumber,
    this.isSearching = false,
  });

  final ImageSearchFilterState filterState;
  final String summaryText;
  final String? currentMovieNumber;
  final ValueChanged<ImageSearchCurrentMovieScope> onCurrentMovieScopeChanged;
  final ValueChanged<ImageSearchActorFilterMode> onModeChanged;
  final VoidCallback onSelectActors;
  final VoidCallback onSearch;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Container(
      key: const Key('desktop-image-search-filter-panel'),
      width: double.infinity,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined),
              SizedBox(width: spacing.sm),
              Text(
                '搜索筛选',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
            ],
          ),
          if (currentMovieNumber != null &&
              currentMovieNumber!.trim().isNotEmpty) ...[
            SizedBox(height: spacing.sm),
            Text(
              '当前影片范围',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: spacing.xs),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: ImageSearchCurrentMovieScope.values
                  .map(
                    (scope) => AppButton(
                      label: scope.label,
                      size: AppButtonSize.xSmall,
                      variant: AppButtonVariant.secondary,
                      isSelected: filterState.currentMovieScope == scope,
                      onPressed: () => onCurrentMovieScopeChanged(scope),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          SizedBox(height: spacing.sm),
          Text(
            '已订阅女优范围',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.sm),
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: ImageSearchActorFilterMode.values
                .map(
                  (mode) => AppButton(
                    label: mode.label,
                    size: AppButtonSize.xSmall,
                    variant: AppButtonVariant.secondary,
                    isSelected: filterState.actorFilterMode == mode,
                    onPressed: () => onModeChanged(mode),
                  ),
                )
                .toList(growable: false),
          ),
          SizedBox(height: spacing.sm),
          AppButton(
            label: '选择已订阅女优',
            icon: const Icon(Icons.groups_2_outlined),
            size: AppButtonSize.small,
            variant: AppButtonVariant.secondary,
            onPressed: onSelectActors,
          ),
          SizedBox(height: spacing.sm),
          Text(
            summaryText,
            key: const Key('desktop-image-search-filter-summary'),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.sm),
          SizedBox(
            width: double.infinity,

            child: AppButton(
              label: '搜索',
              size: AppButtonSize.small,
              variant: AppButtonVariant.primary,
              isLoading: isSearching,
              onPressed:
                  filterState.requiresActorSelection &&
                          filterState.selectedActors.isEmpty
                      ? null
                      : onSearch,
            ),
          ),
        ],
      ),
    );
  }
}
