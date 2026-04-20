import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/playlist_detail_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/playlists/playlist_banner_card.dart';

class PlaylistDetailContent extends StatefulWidget {
  const PlaylistDetailContent({
    super.key,
    required this.playlistId,
    required this.onMovieTap,
    this.enablePullToRefresh = false,
  });

  final int playlistId;
  final ValueChanged<MovieListItemDto> onMovieTap;
  final bool enablePullToRefresh;

  @override
  State<PlaylistDetailContent> createState() => _PlaylistDetailContentState();
}

class _PlaylistDetailContentState extends State<PlaylistDetailContent> {
  late final PlaylistDetailController _detailController;
  late final PagedMovieSummaryController _moviesController;

  Listenable get _pageListenable =>
      Listenable.merge(<Listenable>[_detailController, _moviesController]);

  @override
  void initState() {
    super.initState();
    final playlistsApi = context.read<PlaylistsApi>();
    final moviesApi = context.read<MoviesApi>();
    _detailController = PlaylistDetailController(
      playlistId: widget.playlistId,
      fetchPlaylistDetail: playlistsApi.getPlaylistDetail,
    )..load();
    _moviesController = PagedMovieSummaryController(
      fetchPage:
          (page, pageSize) => playlistsApi.getPlaylistMovies(
            playlistId: widget.playlistId,
            page: page,
            pageSize: pageSize,
          ),
      subscribeMovie: moviesApi.subscribeMovie,
      unsubscribeMovie: moviesApi.unsubscribeMovie,
      pageSize: 24,
      loadMoreTriggerOffset: 300,
      initialLoadErrorText: '影片列表加载失败，请稍后重试',
      loadMoreErrorText: '加载更多失败，请点击重试',
    );
    _moviesController.attachScrollListener();
    _moviesController.initialize();
  }

  @override
  void dispose() {
    _detailController.dispose();
    _moviesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pageListenable,
      builder: (context, _) {
        if (_detailController.isLoading && _detailController.playlist == null) {
          return const SizedBox.expand(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (_detailController.errorMessage != null ||
            _detailController.playlist == null) {
          return AppEmptyState(
            message: _detailController.errorMessage ?? '播放列表详情暂时无法加载，请稍后重试',
          );
        }

        final playlist = _detailController.playlist!;
        final scrollView = SingleChildScrollView(
          physics:
              widget.enablePullToRefresh
                  ? const AlwaysScrollableScrollPhysics()
                  : null,
          controller: _moviesController.scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlaylistBannerCard(
                key: Key('playlist-banner-card-${playlist.id}'),
                title: playlist.name,
                coverImageUrl:
                    _moviesController
                        .items
                        .firstOrNull
                        ?.coverImage
                        ?.bestAvailableUrl,
              ),
              SizedBox(height: context.appSpacing.sm),
              Text(
                '${playlist.movieCount} 部影片',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: context.appSpacing.sm),
              MovieSummaryGrid(
                items: _moviesController.items,
                isLoading: _moviesController.isInitialLoading,
                errorMessage: _moviesController.initialErrorMessage,
                onMovieTap: widget.onMovieTap,
                onMovieSubscriptionTap:
                    (movie) => _toggleMovieSubscription(movie.movieNumber),
                isMovieSubscriptionUpdating:
                    (movie) => _moviesController.isSubscriptionUpdating(
                      movie.movieNumber,
                    ),
                emptyMessage: '暂无影片数据',
              ),
              if (_buildLoadMoreFooter(context) case final footer?) ...[
                SizedBox(height: context.appSpacing.md),
                footer,
              ],
            ],
          ),
        );

        if (!widget.enablePullToRefresh) {
          return scrollView;
        }

        return AppPullToRefresh(onRefresh: _handleRefresh, child: scrollView);
      },
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await Future.wait<void>([
        _detailController.refresh(),
        _moviesController.refresh(),
      ]);
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await _moviesController.toggleSubscription(
      movieNumber: movieNumber,
    );
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  Widget? _buildLoadMoreFooter(BuildContext context) {
    if (_moviesController.items.isEmpty) {
      return null;
    }

    if (_moviesController.isLoadingMore) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
          child: SizedBox(
            width: context.appComponentTokens.movieCardLoaderSize,
            height: context.appComponentTokens.movieCardLoaderSize,
            child: CircularProgressIndicator(
              strokeWidth:
                  context.appComponentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }

    if (_moviesController.loadMoreErrorMessage == null) {
      return null;
    }

    return Center(
      child: TextButton(
        onPressed: _moviesController.loadMore,
        child: Text(_moviesController.loadMoreErrorMessage!),
      ),
    );
  }
}
