import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/actor_detail_controller.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/actors/actor_avatar.dart';
import 'package:sakuramedia/widgets/movies/movie_filter_toolbar.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';

class DesktopActorDetailPage extends StatefulWidget {
  const DesktopActorDetailPage({super.key, required this.actorId});

  final int actorId;

  @override
  State<DesktopActorDetailPage> createState() => _DesktopActorDetailPageState();
}

class _DesktopActorDetailPageState extends State<DesktopActorDetailPage> {
  late final ActorDetailController _actorController;
  late final PagedMovieSummaryController _moviesController;
  MovieFilterState _filterState = MovieFilterState.initial;

  Listenable get _pageListenable =>
      Listenable.merge(<Listenable>[_actorController, _moviesController]);

  @override
  void initState() {
    super.initState();
    _actorController = ActorDetailController(
      actorId: widget.actorId,
      fetchActorDetail: context.read<ActorsApi>().getActorDetail,
    )..load();
    _moviesController = PagedMovieSummaryController(
      fetchPage:
          (page, pageSize) => context.read<MoviesApi>().getMovies(
            actorId: widget.actorId,
            page: page,
            pageSize: pageSize,
            status: _filterState.status,
            collectionType: _filterState.collectionType,
            sort: _filterState.sortExpression,
          ),
      subscribeMovie: context.read<MoviesApi>().subscribeMovie,
      unsubscribeMovie: context.read<MoviesApi>().unsubscribeMovie,
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
    _actorController.dispose();
    _moviesController.dispose();
    super.dispose();
  }

  void _applyFilter(MovieFilterState nextState) {
    if (nextState.status == _filterState.status &&
        nextState.collectionType == _filterState.collectionType &&
        nextState.sortField == _filterState.sortField &&
        nextState.sortDirection == _filterState.sortDirection) {
      return;
    }
    setState(() {
      _filterState = nextState;
    });
    if (_moviesController.scrollController.hasClients) {
      _moviesController.scrollController.jumpTo(0);
    }
    unawaited(_moviesController.reload());
  }

  void _resetFilters() {
    _applyFilter(MovieFilterState.initial);
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pageListenable,
      builder: (context, _) {
        if (_actorController.isLoading && _actorController.actor == null) {
          return const _ActorDetailLoadingSkeleton();
        }

        if (_actorController.errorMessage != null ||
            _actorController.actor == null) {
          return _ActorDetailErrorState(
            message: _actorController.errorMessage ?? '女优详情暂时无法加载，请稍后重试',
            onRetry: _actorController.load,
          );
        }

        final actor = _actorController.actor!;
        final footer = _buildLoadMoreFooter(context);

        return ColoredBox(
          color: context.appColors.surfaceElevated,
          child: SingleChildScrollView(
            controller: _moviesController.scrollController,
            child: Column(
              key: const Key('actor-detail-page'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActorDetailHeader(
                  actor: actor,
                  total: _moviesController.total,
                ),
                SizedBox(height: context.appSpacing.lg),
                MovieFilterToolbar(
                  filterState: _filterState,
                  onChanged: _applyFilter,
                  onReset: _resetFilters,
                ),
                SizedBox(height: context.appSpacing.lg),
                MovieSummaryGrid(
                  items: _moviesController.items,
                  isLoading: _moviesController.isInitialLoading,
                  errorMessage: _moviesController.initialErrorMessage,
                  onMovieTap:
                      (movie) => context.goNamed(
                        'desktop-movie-detail',
                        pathParameters: <String, String>{
                          'movieNumber': movie.movieNumber,
                        },
                        extra: '/desktop/library/actors/${widget.actorId}',
                      ),
                  onMovieSubscriptionTap:
                      (movie) => _toggleMovieSubscription(movie.movieNumber),
                  isMovieSubscriptionUpdating:
                      (movie) => _moviesController.isSubscriptionUpdating(
                        movie.movieNumber,
                      ),
                  emptyMessage: '暂无影片数据',
                ),
                if (footer != null) ...[
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

  Widget? _buildLoadMoreFooter(BuildContext context) {
    if (_moviesController.items.isEmpty) {
      return null;
    }

    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;

    if (_moviesController.isLoadingMore) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.md),
          child: SizedBox(
            width: componentTokens.movieCardLoaderSize,
            height: componentTokens.movieCardLoaderSize,
            child: CircularProgressIndicator(
              strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }

    if (_moviesController.loadMoreErrorMessage == null) {
      return null;
    }

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: componentTokens.iconSizeXl,
                color: colors.textSecondary,
              ),
              SizedBox(width: spacing.sm),
              Text(
                _moviesController.loadMoreErrorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
              SizedBox(width: spacing.sm),
              TextButton(
                onPressed: _moviesController.loadMore,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.sm,
                    vertical: spacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActorDetailHeader extends StatelessWidget {
  const _ActorDetailHeader({required this.actor, required this.total});

  final ActorListItemDto actor;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('actor-detail-header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ActorAvatar(
          imageUrl: actor.profileImage?.bestAvailableUrl,
          size: context.appComponentTokens.movieDetailActorAvatarSize,
          placeholderKey: const Key('actor-detail-avatar-placeholder'),
        ),
        SizedBox(width: context.appSpacing.md),
        Expanded(
          child: Text(
            actor.displayName,
            key: const Key('actor-detail-name'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.appColors.textPrimary,
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.lg),
        Text(
          '$total 部',
          key: const Key('actor-detail-total'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ActorDetailLoadingSkeleton extends StatelessWidget {
  const _ActorDetailLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        key: const Key('actor-detail-loading-skeleton'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SkeletonBlock(height: 54, width: 54),
              SizedBox(width: context.appSpacing.md),
              const Expanded(child: _SkeletonBlock(height: 24)),
              SizedBox(width: context.appSpacing.lg),
              const _SkeletonBlock(height: 18, width: 56),
            ],
          ),
          SizedBox(height: context.appSpacing.lg),
          const _SkeletonBlock(height: 32, width: 136),
          SizedBox(height: context.appSpacing.lg),
          const _SkeletonBlock(height: 360),
        ],
      ),
    );
  }
}

class _ActorDetailErrorState extends StatelessWidget {
  const _ActorDetailErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.lg),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
    );
  }
}
