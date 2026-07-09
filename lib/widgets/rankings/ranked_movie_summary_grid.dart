import 'package:flutter/material.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_card.dart';

class RankedMovieSummaryGrid extends StatelessWidget {
  const RankedMovieSummaryGrid({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onMovieTap,
    this.onMovieMenuRequest,
    this.onMovieSubscriptionTap,
    this.isMovieSubscriptionUpdating,
    this.emptyMessage = '暂无榜单数据',
    this.placeholderCount = 8,
  });

  final List<RankedMovieListItemDto> items;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<RankedMovieListItemDto>? onMovieTap;
  final void Function(RankedMovieListItemDto movie, Offset globalPosition)?
  onMovieMenuRequest;
  final ValueChanged<RankedMovieListItemDto>? onMovieSubscriptionTap;
  final bool Function(RankedMovieListItemDto movie)?
  isMovieSubscriptionUpdating;
  final String emptyMessage;
  final int placeholderCount;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardGrid<RankedMovieListItemDto>(
      gridKey: const Key('ranked-movie-summary-grid'),
      items: items,
      isLoading: isLoading,
      errorMessage: errorMessage,
      emptyMessage: emptyMessage,
      placeholderCount: placeholderCount,
      skeletonBuilder: (context, index) => _RankedMovieSummaryCardSkeleton(
        key: Key('ranked-movie-summary-card-skeleton-$index'),
      ),
      itemBuilder: (context, item, index) => MovieSummaryCard(
        movie: item.toMovieListItem(),
        rank: item.rank,
        onTap: onMovieTap == null ? null : () => onMovieTap!(item),
        onRequestMenu: onMovieMenuRequest == null
            ? null
            : (globalPosition) => onMovieMenuRequest!(item, globalPosition),
        onSubscriptionTap: onMovieSubscriptionTap == null
            ? null
            : () => onMovieSubscriptionTap!(item),
        isSubscriptionUpdating:
            isMovieSubscriptionUpdating?.call(item) ?? false,
      ),
    );
  }
}

class _RankedMovieSummaryCardSkeleton extends StatelessWidget {
  const _RankedMovieSummaryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: context.appComponentTokens.movieCardAspectRatio,
        child: DecoratedBox(
          key: Key(
            'ranked-movie-summary-card-skeleton-poster-${_indexFromKey()}',
          ),
          decoration: BoxDecoration(color: context.appColors.surfaceMuted),
        ),
      ),
    );
  }

  String _indexFromKey() {
    final currentKey = key;
    if (currentKey is ValueKey<String>) {
      const prefix = 'ranked-movie-summary-card-skeleton-';
      if (currentKey.value.startsWith(prefix)) {
        return currentKey.value.substring(prefix.length);
      }
      return currentKey.value;
    }
    return 'unknown';
  }
}
