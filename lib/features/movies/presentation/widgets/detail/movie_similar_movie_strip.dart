import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subscription_toggle_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';

import 'movie_detail_strip.dart';

const double _similarMovieCardWidthFactor = 0.75;

class MovieSimilarMovieStrip extends ConsumerWidget {
  const MovieSimilarMovieStrip({
    super.key,
    required this.movies,
    required this.isLoading,
    this.errorMessage,
    this.onRetry,
    this.onMovieTap,
    this.onMovieMenuRequest,
    this.onMovieToggleCollectionType,
    this.onMovieBlacklist,
  });

  final List<MovieListItemDto> movies;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final ValueChanged<MovieListItemDto>? onMovieTap;
  final void Function(MovieListItemDto movie, Offset globalPosition)?
  onMovieMenuRequest;

  /// 悬停动作行「标记为合集 / 单体」回调；为 `null` 时该按钮不显示。
  final ValueChanged<MovieListItemDto>? onMovieToggleCollectionType;

  /// 悬停动作行「屏蔽影片」回调；为 `null` 或影片已订阅时该按钮不显示。
  final ValueChanged<MovieListItemDto>? onMovieBlacklist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardWidth =
        context.appComponentTokens.movieCardTargetWidth *
        _similarMovieCardWidthFactor;
    final updatingMovieNumbers = ref.watch(movieSubscriptionToggleProvider);

    if (isLoading && movies.isEmpty) {
      // loading 用占位影片渲染真实卡片，由 [AppSkeletonizer] 灰化。
      return AppSkeletonizer(
        enabled: true,
        child: MovieDetailStripScroller(
          scrollViewKey: const Key('movie-similar-strip-loading'),
          children: [
            for (final movie in movieListItemPlaceholders(count: 4))
              SizedBox(
                width: cardWidth,
                child: MovieSummaryCard(movie: movie),
              ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return MovieDetailStripFeedback(
        feedbackKey: const Key('movie-similar-strip-error'),
        message: errorMessage!,
        actionLabel: AppLocalizations.of(context).commonRetry,
        onAction: onRetry,
        retryKey: const Key('movie-similar-strip-retry'),
      );
    }

    if (movies.isEmpty) {
      return MovieDetailStripFeedback(
        feedbackKey: const Key('movie-similar-strip-empty'),
        message: AppLocalizations.of(context).movieWidgetNoSimilarMovies,
      );
    }

    return MovieDetailStripScroller(
      scrollViewKey: const Key('movie-similar-strip-scroll'),
      children: movies
          .map(
            (movie) => SizedBox(
              width: cardWidth,
              child: MovieSummaryCard(
                movie: movie,
                onTap: onMovieTap == null ? null : () => onMovieTap!(movie),
                onRequestMenu: onMovieMenuRequest == null
                    ? null
                    : (globalPosition) =>
                          onMovieMenuRequest!(movie, globalPosition),
                onSubscriptionTap: () =>
                    unawaited(_toggleMovieSubscription(ref, context, movie)),
                onToggleCollectionType: onMovieToggleCollectionType == null
                    ? null
                    : () => onMovieToggleCollectionType!(movie),
                onBlacklist: onMovieBlacklist == null
                    ? null
                    : () => onMovieBlacklist!(movie),
                isSubscriptionUpdating: updatingMovieNumbers.contains(
                  movie.movieNumber,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

Future<void> _toggleMovieSubscription(
  WidgetRef ref,
  BuildContext context,
  MovieListItemDto movie,
) async {
  final result = await ref
      .read(movieSubscriptionToggleProvider.notifier)
      .toggle(movieNumber: movie.movieNumber, isSubscribed: movie.isSubscribed);
  if (context.mounted) {
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }
}
