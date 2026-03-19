import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_card.dart';

class RankedMovieSummaryGrid extends StatelessWidget {
  const RankedMovieSummaryGrid({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onMovieTap,
    this.onMovieSubscriptionTap,
    this.isMovieSubscriptionUpdating,
    this.emptyMessage = '暂无榜单数据',
    this.placeholderCount = 8,
  });

  final List<RankedMovieListItemDto> items;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<RankedMovieListItemDto>? onMovieTap;
  final ValueChanged<RankedMovieListItemDto>? onMovieSubscriptionTap;
  final bool Function(RankedMovieListItemDto movie)? isMovieSubscriptionUpdating;
  final String emptyMessage;
  final int placeholderCount;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _RankedMovieSummaryGridLayout(
        children: List<Widget>.generate(
          placeholderCount,
          (index) => _RankedMovieSummaryCardSkeleton(
            key: Key('ranked-movie-summary-card-skeleton-$index'),
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

    return _RankedMovieSummaryGridLayout(
      children: items
          .map((item) {
            final movie = item.toMovieListItem();
            return MovieSummaryCard(
              movie: movie,
              rank: item.rank,
              onTap: onMovieTap == null ? null : () => onMovieTap!(item),
              onSubscriptionTap:
                  onMovieSubscriptionTap == null
                      ? null
                      : () => onMovieSubscriptionTap!(item),
              isSubscriptionUpdating:
                  isMovieSubscriptionUpdating?.call(item) ?? false,
            );
          })
          .toList(growable: false),
    );
  }
}

class _RankedMovieSummaryGridLayout extends StatelessWidget {
  const _RankedMovieSummaryGridLayout({required this.children});

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
          key: const Key('ranked-movie-summary-grid'),
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
        aspectRatio: 0.7,
        child: DecoratedBox(
          key: Key('ranked-movie-summary-card-skeleton-poster-${_indexFromKey()}'),
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
