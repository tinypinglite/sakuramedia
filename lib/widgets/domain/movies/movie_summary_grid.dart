import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_cover_card_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';

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
      skeletonBuilder: (context, index) => AppCoverCardSkeleton(
        key: Key('movie-summary-card-skeleton-$index'),
        posterKey: Key('movie-summary-card-skeleton-poster-$index'),
        aspectRatio: context.appComponentTokens.movieCardAspectRatio,
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

