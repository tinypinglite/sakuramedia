import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

class DesktopFollowPage extends ConsumerStatefulWidget {
  const DesktopFollowPage({super.key});

  @override
  ConsumerState<DesktopFollowPage> createState() => _DesktopFollowPageState();
}

class _DesktopFollowPageState extends ConsumerState<DesktopFollowPage> {
  static const _scope = MovieSummaryScope.subscribedActorsLatest();
  late final ScrollController _scrollController;

  MovieCardHoverFeatureActions get _hoverFeatureActions =>
      movieCardHoverFeatureActions(
        context,
        onBlacklisted: (movieNumber) => ref
            .read(movieSummaryProvider(_scope).notifier)
            .removeMovies(<String>[movieNumber]),
      );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final summary = ref.read(movieSummaryProvider(_scope)).value;
    if (summary == null ||
        summary.paged.loadMoreErrorMessage != null ||
        position.pixels < position.maxScrollExtent - 300) {
      return;
    }
    unawaited(ref.read(movieSummaryProvider(_scope).notifier).loadMore());
  }

  Future<void> _refresh() async {
    await ref.read(movieSummaryProvider(_scope).notifier).refresh();
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(movieSummaryProvider(_scope).notifier)
        .toggleSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(movieSummaryProvider(_scope));
    final summary = moviesAsync.value;
    final paged = summary?.paged;
    final items = paged?.items ?? const [];
    final isInitialLoading = moviesAsync.isLoading && summary == null;
    final initialErrorMessage = moviesAsync.hasError && summary == null
        ? _scope.initialLoadErrorText
        : null;
    final showFooter =
        items.isNotEmpty &&
        (paged!.isLoadingMore || paged.loadMoreErrorMessage != null);

    return AppPageRefreshScope(
      onRefresh: _refresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverMainAxisGroup(
              key: const Key('desktop-follow-page'),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: context.appSpacing.lg),
                ),
                AppSkeletonizer.sliver(
                  enabled: isInitialLoading,
                  child: MovieSummarySliver(
                    items: isInitialLoading
                        ? movieListItemPlaceholders(count: 24)
                        : items,
                    errorMessage: initialErrorMessage,
                    onMovieTap: (movie) => context.pushDesktopMovieDetail(
                      movieNumber: movie.movieNumber,
                      fallbackPath: desktopFollowPath,
                    ),
                    onMovieMenuRequest: (movie, globalPosition) {
                      unawaited(
                        showMovieCollectionFeatureActionMenu(
                          context: context,
                          movieNumber: movie.movieNumber,
                          globalPosition: globalPosition,
                          isSubscribed: movie.isSubscribed,
                        ),
                      );
                    },
                    onMovieSubscriptionTap: (movie) =>
                        _toggleMovieSubscription(movie.movieNumber),
                    onMovieToggleCollectionType:
                        _hoverFeatureActions.toggleCollectionType,
                    onMovieBlacklist: _hoverFeatureActions.blacklist,
                    isMovieSubscriptionUpdating: (movie) =>
                        summary?.isSubscriptionUpdating(movie.movieNumber) ??
                        false,
                    emptyMessage: '暂无关注影片',
                  ),
                ),
                if (showFooter)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: context.appSpacing.md),
                      child: AppPagedLoadMoreFooter(
                        isLoading: paged.isLoadingMore,
                        errorMessage: paged.loadMoreErrorMessage,
                        onRetry: () => ref
                            .read(movieSummaryProvider(_scope).notifier)
                            .loadMore(),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
