import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/playlist_detail_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/playlists/playlist_banner_card.dart';

class DesktopPlaylistDetailPage extends StatefulWidget {
  const DesktopPlaylistDetailPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  State<DesktopPlaylistDetailPage> createState() =>
      _DesktopPlaylistDetailPageState();
}

class _DesktopPlaylistDetailPageState extends State<DesktopPlaylistDetailPage> {
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

        return ColoredBox(
          color: context.appColors.surfaceElevated,
          child: SingleChildScrollView(
            controller: _moviesController.scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PlaylistBannerCard(
                  key: Key('playlist-banner-card-${playlist.id}'),
                  title: playlist.name,
                  subtitle:
                      playlist.description.trim().isEmpty
                          ? null
                          : playlist.description.trim(),
                  coverImageUrl:
                      _moviesController
                          .items
                          .firstOrNull
                          ?.coverImage
                          ?.bestAvailableUrl,
                ),
                SizedBox(height: context.appSpacing.lg),
                Text(
                  '${playlist.movieCount} 部影片',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                SizedBox(height: context.appSpacing.lg),
                MovieSummaryGrid(
                  items: _moviesController.items,
                  isLoading: _moviesController.isInitialLoading,
                  errorMessage: _moviesController.initialErrorMessage,
                  onMovieTap:
                      (movie) => context.go(
                        '/desktop/library/movies/${movie.movieNumber}',
                        extra: '$desktopPlaylistsPath/${widget.playlistId}',
                      ),
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
          ),
        );
      },
    );
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
