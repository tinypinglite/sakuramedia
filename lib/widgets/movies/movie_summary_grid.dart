import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_card.dart';

class MovieSummaryGrid extends StatelessWidget {
  const MovieSummaryGrid({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onMovieTap,
    this.onMovieMenuRequest,
    this.onMovieSubscriptionTap,
    this.isMovieSubscriptionUpdating,
    this.emptyMessage = '当前没有可展示的影片数据。',
    this.placeholderCount = 8,
  });

  final List<MovieListItemDto> items;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<MovieListItemDto>? onMovieTap;
  final void Function(MovieListItemDto movie, Offset globalPosition)?
  onMovieMenuRequest;
  final ValueChanged<MovieListItemDto>? onMovieSubscriptionTap;
  final bool Function(MovieListItemDto movie)? isMovieSubscriptionUpdating;
  final String emptyMessage;
  final int placeholderCount;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardGrid<MovieListItemDto>(
      gridKey: const Key('movie-summary-grid'),
      items: items,
      isLoading: isLoading,
      errorMessage: errorMessage,
      emptyMessage: emptyMessage,
      placeholderCount: placeholderCount,
      skeletonBuilder: (context, index) => _MovieSummaryCardSkeleton(
        key: Key('movie-summary-card-skeleton-$index'),
      ),
      itemBuilder: (context, movie, index) => MovieSummaryCard(
        movie: movie,
        onTap: onMovieTap == null ? null : () => onMovieTap!(movie),
        onRequestMenu: onMovieMenuRequest == null
            ? null
            : (globalPosition) => onMovieMenuRequest!(movie, globalPosition),
        onSubscriptionTap: onMovieSubscriptionTap == null
            ? null
            : () => onMovieSubscriptionTap!(movie),
        isSubscriptionUpdating:
            isMovieSubscriptionUpdating?.call(movie) ?? false,
      ),
    );
  }
}

class _MovieSummaryCardSkeleton extends StatelessWidget {
  const _MovieSummaryCardSkeleton({super.key});

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
          key: Key('movie-summary-card-skeleton-poster-${_indexFromKey()}'),
          decoration: BoxDecoration(color: context.appColors.surfaceMuted),
        ),
      ),
    );
  }

  String _indexFromKey() {
    final currentKey = key;
    if (currentKey is ValueKey<String>) {
      const prefix = 'movie-summary-card-skeleton-';
      if (currentKey.value.startsWith(prefix)) {
        return currentKey.value.substring(prefix.length);
      }
      return currentKey.value;
    }
    return 'unknown';
  }
}
