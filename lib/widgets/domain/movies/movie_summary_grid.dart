import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subscription_toggle_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_cover_card_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';

class MovieSummaryGrid extends ConsumerWidget {
  const MovieSummaryGrid({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onMovieTap,
    this.onMovieMenuRequest,
    this.onMovieSubscriptionTap,
    this.isMovieSubscriptionUpdating,
    this.useDefaultSubscriptionActions = false,
    this.secondaryLabelForMovie,
    this.emptyMessage = '当前没有可展示的影片数据。',
    this.placeholderCount = 8,
    this.selectionMode = false,
    this.isMovieSelected,
    this.onMovieSelectedChanged,
    this.maxRows,
    this.maxColumns = 6,
  });

  final List<MovieListItemDto> items;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<MovieListItemDto>? onMovieTap;
  final void Function(MovieListItemDto movie, Offset globalPosition)?
  onMovieMenuRequest;
  final ValueChanged<MovieListItemDto>? onMovieSubscriptionTap;
  final bool Function(MovieListItemDto movie)? isMovieSubscriptionUpdating;

  /// 未传自定义订阅回调时，接入跨列表复用的默认订阅动作。
  final bool useDefaultSubscriptionActions;
  final String? Function(MovieListItemDto movie)? secondaryLabelForMovie;
  final String emptyMessage;
  final int placeholderCount;

  /// 选择模式开关：向 [MovieSummaryCard] 透传，卡片进入多选态。
  final bool selectionMode;
  final bool Function(MovieListItemDto movie)? isMovieSelected;
  final void Function(MovieListItemDto movie, bool selected)?
  onMovieSelectedChanged;

  /// 首页等预览区可限制为固定行数；列表页保持不传以展示全部项目。
  final int? maxRows;

  /// 网格的最大列数；默认保持影片列表既有的 6 列上限。
  final int maxColumns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usesDefaultSubscriptionActions =
        useDefaultSubscriptionActions && onMovieSubscriptionTap == null;
    final updatingMovieNumbers = usesDefaultSubscriptionActions
        ? ref.watch(movieSubscriptionToggleProvider)
        : const <String>{};
    return AppAdaptiveCardGrid<MovieListItemDto>(
      gridKey: const Key('movie-summary-grid'),
      items: items,
      isLoading: isLoading,
      errorMessage: errorMessage,
      emptyMessage: emptyMessage,
      placeholderCount: placeholderCount,
      maxRows: maxRows,
      maxColumns: maxColumns,
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
        onSubscriptionTap: onMovieSubscriptionTap != null
            ? () => onMovieSubscriptionTap!(movie)
            : usesDefaultSubscriptionActions
            ? () => unawaited(
                _toggleDefaultMovieSubscription(ref, context, movie),
              )
            : null,
        isSubscriptionUpdating:
            isMovieSubscriptionUpdating?.call(movie) ??
            updatingMovieNumbers.contains(movie.movieNumber),
        secondaryLabel: secondaryLabelForMovie?.call(movie),
        selectionMode: selectionMode,
        isSelected: isMovieSelected?.call(movie) ?? false,
        onSelectedChanged: onMovieSelectedChanged == null
            ? null
            : (selected) => onMovieSelectedChanged!(movie, selected),
      ),
    );
  }
}

/// 累计分页影片列表使用的 Sliver 网格版本。
class MovieSummarySliver extends ConsumerWidget {
  const MovieSummarySliver({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onMovieTap,
    this.onMovieMenuRequest,
    this.onMovieSubscriptionTap,
    this.isMovieSubscriptionUpdating,
    this.useDefaultSubscriptionActions = false,
    this.secondaryLabelForMovie,
    this.emptyMessage = '当前没有可展示的影片数据。',
    this.placeholderCount = 8,
    this.selectionMode = false,
    this.isMovieSelected,
    this.onMovieSelectedChanged,
  });

  final List<MovieListItemDto> items;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<MovieListItemDto>? onMovieTap;
  final void Function(MovieListItemDto movie, Offset globalPosition)?
  onMovieMenuRequest;
  final ValueChanged<MovieListItemDto>? onMovieSubscriptionTap;
  final bool Function(MovieListItemDto movie)? isMovieSubscriptionUpdating;

  /// 未传自定义订阅回调时，接入跨列表复用的默认订阅动作。
  final bool useDefaultSubscriptionActions;
  final String? Function(MovieListItemDto movie)? secondaryLabelForMovie;
  final String emptyMessage;
  final int placeholderCount;

  final bool selectionMode;
  final bool Function(MovieListItemDto movie)? isMovieSelected;
  final void Function(MovieListItemDto movie, bool selected)?
  onMovieSelectedChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usesDefaultSubscriptionActions =
        useDefaultSubscriptionActions && onMovieSubscriptionTap == null;
    final updatingMovieNumbers = usesDefaultSubscriptionActions
        ? ref.watch(movieSubscriptionToggleProvider)
        : const <String>{};
    return AppAdaptiveCardSliver<MovieListItemDto>(
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
        onSubscriptionTap: onMovieSubscriptionTap != null
            ? () => onMovieSubscriptionTap!(movie)
            : usesDefaultSubscriptionActions
            ? () => unawaited(
                _toggleDefaultMovieSubscription(ref, context, movie),
              )
            : null,
        isSubscriptionUpdating:
            isMovieSubscriptionUpdating?.call(movie) ??
            updatingMovieNumbers.contains(movie.movieNumber),
        secondaryLabel: secondaryLabelForMovie?.call(movie),
        selectionMode: selectionMode,
        isSelected: isMovieSelected?.call(movie) ?? false,
        onSelectedChanged: onMovieSelectedChanged == null
            ? null
            : (selected) => onMovieSelectedChanged!(movie, selected),
      ),
    );
  }
}

Future<void> _toggleDefaultMovieSubscription(
  WidgetRef ref,
  BuildContext context,
  MovieListItemDto movie,
) async {
  final result = await ref
      .read(movieSubscriptionToggleProvider.notifier)
      .toggle(movieNumber: movie.movieNumber, isSubscribed: movie.isSubscribed);
  if (context.mounted) showMovieSubscriptionFeedback(result);
}
