import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/actor_detail_controller.dart';
import 'package:sakuramedia/features/actors/presentation/paged_actor_summary_controller.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/actors/actor_avatar.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/movies/movie_filter_toolbar.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';

class MobileActorDetailPage extends StatefulWidget {
  const MobileActorDetailPage({super.key, required this.actorId});

  final int actorId;

  @override
  State<MobileActorDetailPage> createState() => _MobileActorDetailPageState();
}

class _MobileActorDetailPageState extends State<MobileActorDetailPage> {
  late final ActorDetailController _actorController;
  late final PagedMovieSummaryController _moviesController;

  MovieFilterState _filterState = MovieFilterState.initial;
  bool? _isActorSubscribedOverride;
  bool _isActorSubscriptionUpdating = false;

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

  Future<void> _toggleActorSubscription({required bool isSubscribed}) async {
    if (_isActorSubscriptionUpdating) {
      return;
    }

    setState(() {
      _isActorSubscriptionUpdating = true;
    });

    ActorSubscriptionToggleResult result;

    try {
      if (isSubscribed) {
        await context.read<ActorsApi>().unsubscribeActor(
          actorId: widget.actorId,
        );
        result = const ActorSubscriptionToggleResult.unsubscribed();
        _isActorSubscribedOverride = false;
      } else {
        await context.read<ActorsApi>().subscribeActor(actorId: widget.actorId);
        result = const ActorSubscriptionToggleResult.subscribed();
        _isActorSubscribedOverride = true;
      }
    } catch (error) {
      result = ActorSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: isSubscribed ? '取消订阅女优失败' : '订阅女优失败',
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isActorSubscriptionUpdating = false;
    });
    showActorSubscriptionFeedback(result);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pageListenable,
      builder: (context, _) {
        if (_actorController.isLoading && _actorController.actor == null) {
          return const _MobileActorDetailLoadingSkeleton();
        }

        if (_actorController.errorMessage != null ||
            _actorController.actor == null) {
          return _MobileActorDetailErrorState(
            message: _actorController.errorMessage ?? '女优详情暂时无法加载，请稍后重试',
            onRetry: _actorController.load,
          );
        }

        final actor = _actorController.actor!;
        final isActorSubscribed =
            _isActorSubscribedOverride ?? actor.isSubscribed;
        final footer = _buildLoadMoreFooter(context);

        return ColoredBox(
          color: context.appColors.surfaceCard,
          child: AppPullToRefresh(
            onRefresh: _handleRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _moviesController.scrollController,
              child: Column(
                key: const Key('mobile-actor-detail-page'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MobileActorDetailHeader(
                    actor: actor,
                    total: _moviesController.total,
                    isSubscribed: isActorSubscribed,
                    isSubscriptionUpdating: _isActorSubscriptionUpdating,
                    onSubscriptionTap:
                        _isActorSubscriptionUpdating
                            ? null
                            : () => _toggleActorSubscription(
                              isSubscribed: isActorSubscribed,
                            ),
                  ),
                  SizedBox(height: context.appSpacing.md),
                  MovieFilterToolbar(
                    filterState: _filterState,
                    onChanged: _applyFilter,
                    onReset: _resetFilters,
                  ),
                  SizedBox(height: context.appSpacing.md),
                  MovieSummaryGrid(
                    items: _moviesController.items,
                    isLoading: _moviesController.isInitialLoading,
                    errorMessage: _moviesController.initialErrorMessage,
                    onMovieTap:
                        (movie) => MobileMovieDetailRouteData(
                          movieNumber: movie.movieNumber,
                        ).push(context),
                    onMovieMenuRequest: (movie, globalPosition) {
                      unawaited(
                        showMovieCollectionFeatureActionMenu(
                          context: context,
                          movieNumber: movie.movieNumber,
                          globalPosition: globalPosition,
                        ),
                      );
                    },
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
          ),
        );
      },
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await Future.wait<void>([
        _actorController.refresh(),
        _moviesController.refresh(),
      ]);
      if (mounted) {
        setState(() {
          _isActorSubscribedOverride = null;
        });
      }
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }

  Widget? _buildLoadMoreFooter(BuildContext context) {
    if (_moviesController.items.isEmpty) {
      return null;
    }
    return AppPagedLoadMoreFooter(
      isLoading: _moviesController.isLoadingMore,
      errorMessage: _moviesController.loadMoreErrorMessage,
      onRetry: _moviesController.loadMore,
    );
  }
}

class _MobileActorDetailHeader extends StatelessWidget {
  const _MobileActorDetailHeader({
    required this.actor,
    required this.total,
    required this.isSubscribed,
    required this.isSubscriptionUpdating,
    required this.onSubscriptionTap,
  });

  final ActorListItemDto actor;
  final int total;
  final bool isSubscribed;
  final bool isSubscriptionUpdating;
  final VoidCallback? onSubscriptionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('mobile-actor-detail-header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ActorAvatar(
          imageUrl: actor.profileImage?.bestAvailableUrl,
          size: context.appComponentTokens.movieDetailActorAvatarSize,
          placeholderKey: const Key('mobile-actor-detail-avatar-placeholder'),
        ),
        SizedBox(width: context.appSpacing.md),
        Expanded(
          child: Text(
            actor.displayName,
            key: const Key('mobile-actor-detail-name'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.appColors.textPrimary,
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.md),
        _MobileActorSubscriptionBadge(
          actorId: actor.id,
          isSubscribed: isSubscribed,
          isUpdating: isSubscriptionUpdating,
          onTap: onSubscriptionTap,
        ),
        SizedBox(width: context.appSpacing.sm),
        Text(
          '$total 部',
          key: const Key('mobile-actor-detail-total'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MobileActorSubscriptionBadge extends StatelessWidget {
  const _MobileActorSubscriptionBadge({
    required this.actorId,
    required this.isSubscribed,
    required this.isUpdating,
    required this.onTap,
  });

  final int actorId;
  final bool isSubscribed;
  final bool isUpdating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;
    final colors = context.appColors;

    final badge = SizedBox(
      key: Key('mobile-actor-detail-subscription-$actorId'),
      width: componentTokens.movieCardStatusBadgeSize,
      height: componentTokens.movieCardStatusBadgeSize,
      child: Center(
        child:
            isUpdating
                ? SizedBox(
                  width: componentTokens.movieCardLoaderSize,
                  height: componentTokens.movieCardLoaderSize,
                  child: CircularProgressIndicator(
                    key: Key(
                      'mobile-actor-detail-subscription-loading-$actorId',
                    ),
                    strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
                    color: colors.subscriptionHeartIcon,
                  ),
                )
                : Icon(
                  isSubscribed
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: componentTokens.iconSizeXl,
                  color: colors.subscriptionHeartIcon,
                ),
      ),
    );

    if (onTap == null || isUpdating) {
      return badge;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: badge,
    );
  }
}

class _MobileActorDetailLoadingSkeleton extends StatelessWidget {
  const _MobileActorDetailLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        key: const Key('mobile-actor-detail-loading-skeleton'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SkeletonBlock(height: 54, width: 54),
              SizedBox(width: context.appSpacing.md),
              const Expanded(child: _SkeletonBlock(height: 24)),
              SizedBox(width: context.appSpacing.md),
              const _SkeletonBlock(height: 24, width: 24),
              SizedBox(width: context.appSpacing.sm),
              const _SkeletonBlock(height: 18, width: 56),
            ],
          ),
          SizedBox(height: context.appSpacing.md),
          const _SkeletonBlock(height: 32, width: 136),
          SizedBox(height: context.appSpacing.md),
          const _SkeletonBlock(height: 360),
        ],
      ),
    );
  }
}

class _MobileActorDetailErrorState extends StatelessWidget {
  const _MobileActorDetailErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('mobile-actor-detail-error-state'),
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
