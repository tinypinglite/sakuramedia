import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_card.dart';

const double _similarMovieCardWidthFactor = 0.75;

class MovieSimilarMovieStrip extends StatelessWidget {
  const MovieSimilarMovieStrip({
    super.key,
    required this.movies,
    required this.isLoading,
    this.errorMessage,
    this.onRetry,
    this.onMovieTap,
  });

  final List<MovieListItemDto> movies;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final ValueChanged<MovieListItemDto>? onMovieTap;

  @override
  Widget build(BuildContext context) {
    final cardWidth =
        context.appComponentTokens.movieCardTargetWidth *
        _similarMovieCardWidthFactor;

    if (isLoading) {
      return _MovieSimilarMovieStripScroller(
        scrollViewKey: const Key('movie-similar-strip-loading'),
        children: List<Widget>.generate(
          4,
          (index) => _MovieSimilarMovieSkeleton(
            key: Key('movie-similar-strip-skeleton-$index'),
            width: cardWidth,
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return _MovieSimilarMovieFeedback(
        feedbackKey: const Key('movie-similar-strip-error'),
        message: errorMessage!,
        actionLabel: '重试',
        onAction: onRetry,
      );
    }

    if (movies.isEmpty) {
      return const _MovieSimilarMovieFeedback(
        feedbackKey: Key('movie-similar-strip-empty'),
        message: '暂无相似影片',
      );
    }

    return _MovieSimilarMovieStripScroller(
      scrollViewKey: const Key('movie-similar-strip-scroll'),
      children: movies
          .map(
            (movie) => SizedBox(
              width: cardWidth,
              child: MovieSummaryCard(
                movie: movie,
                onTap: onMovieTap == null ? null : () => onMovieTap!(movie),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _MovieSimilarMovieStripScroller extends StatelessWidget {
  const _MovieSimilarMovieStripScroller({
    required this.children,
    this.scrollViewKey,
  });

  final List<Widget> children;
  final Key? scrollViewKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing.sm;
    return SingleChildScrollView(
      key: scrollViewKey,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(children.length, (index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index == children.length - 1 ? 0 : spacing,
            ),
            child: children[index],
          );
        }),
      ),
    );
  }
}

class _MovieSimilarMovieFeedback extends StatelessWidget {
  const _MovieSimilarMovieFeedback({
    required this.message,
    this.feedbackKey,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Key? feedbackKey;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: feedbackKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.appColors.movieDetailEmptyBackground,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(width: context.appSpacing.sm),
            TextButton(
              key: const Key('movie-similar-strip-retry'),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _MovieSimilarMovieSkeleton extends StatelessWidget {
  const _MovieSimilarMovieSkeleton({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
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
          decoration: BoxDecoration(color: context.appColors.surfaceMuted),
        ),
      ),
    );
  }
}
