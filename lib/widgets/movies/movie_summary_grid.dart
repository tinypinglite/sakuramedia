import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_card.dart';

class MovieSummaryGrid extends StatelessWidget {
  const MovieSummaryGrid({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onMovieTap,
    this.onMovieSubscriptionTap,
    this.isMovieSubscriptionUpdating,
    this.emptyMessage = '当前没有可展示的影片数据。',
    this.placeholderCount = 8,
  });

  final List<MovieListItemDto> items;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<MovieListItemDto>? onMovieTap;
  final ValueChanged<MovieListItemDto>? onMovieSubscriptionTap;
  final bool Function(MovieListItemDto movie)? isMovieSubscriptionUpdating;
  final String emptyMessage;
  final int placeholderCount;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _MovieSummaryGridLayout(
        children: List<Widget>.generate(
          placeholderCount,
          (index) => _MovieSummaryCardSkeleton(
            key: Key('movie-summary-card-skeleton-$index'),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return AppEmptyState(message: errorMessage!);
    }

    if (items.isEmpty) {
      return AppEmptyState(message: emptyMessage);
    }

    return _MovieSummaryGridLayout(
      children: items
          .map(
            (movie) => MovieSummaryCard(
              movie: movie,
              onTap: onMovieTap == null ? null : () => onMovieTap!(movie),
              onSubscriptionTap:
                  onMovieSubscriptionTap == null
                      ? null
                      : () => onMovieSubscriptionTap!(movie),
              isSubscriptionUpdating:
                  isMovieSubscriptionUpdating?.call(movie) ?? false,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _MovieSummaryGridLayout extends StatelessWidget {
  const _MovieSummaryGridLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing.md;
        final componentTokens = context.appComponentTokens;
        final columns = _resolveColumnCount(
          width: constraints.maxWidth,
          spacing: spacing,
          targetWidth: componentTokens.movieCardTargetWidth,
        );

        return GridView.builder(
          key: const Key('movie-summary-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: componentTokens.movieCardAspectRatio,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }

  int _resolveColumnCount({
    required double width,
    required double spacing,
    required double targetWidth,
  }) {
    final columns = ((width + spacing) / (targetWidth + spacing)).floor();
    return math.max(2, math.min(6, columns));
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
        aspectRatio: 0.7,
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
