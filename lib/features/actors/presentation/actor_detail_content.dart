import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/data/actor_movie_year_dto.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/actor_detail_controller.dart';
import 'package:sakuramedia/features/actors/presentation/paged_actor_summary_controller.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/data/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movies/movie_filter_toolbar.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';

typedef ActorDetailBodyBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
  Widget child,
  Future<void> Function()? onRefresh,
);

typedef ActorDetailHeaderBuilder = Widget Function(
  BuildContext context,
  ActorListItemDto actor,
  int total,
  bool isSubscribed,
  bool isSubscriptionUpdating,
  VoidCallback? onSubscriptionTap,
);

typedef ActorDetailErrorBuilder = Widget Function(
    BuildContext context, String message, VoidCallback onRetry);

typedef ActorDetailFooterBuilder = Widget? Function(
  BuildContext context,
  PagedMovieSummaryController moviesController,
);

class ActorDetailContent extends StatefulWidget {
  const ActorDetailContent({
    super.key,
    required this.actorId,
    required this.surfaceColor,
    required this.contentKey,
    required this.sectionSpacing,
    required this.onMovieTap,
    required this.headerBuilder,
    required this.loadingBuilder,
    required this.errorBuilder,
    required this.footerBuilder,
    required this.bodyBuilder,
    this.enableRefresh = false,
    this.onRefreshFailure,
  });

  final int actorId;
  final Color surfaceColor;
  final Key contentKey;
  final double sectionSpacing;
  final void Function(BuildContext context, String movieNumber) onMovieTap;
  final ActorDetailHeaderBuilder headerBuilder;
  final WidgetBuilder loadingBuilder;
  final ActorDetailErrorBuilder errorBuilder;
  final ActorDetailFooterBuilder footerBuilder;
  final ActorDetailBodyBuilder bodyBuilder;
  final bool enableRefresh;
  final void Function(BuildContext context)? onRefreshFailure;

  @override
  State<ActorDetailContent> createState() => _ActorDetailContentState();
}

class _ActorDetailContentState extends State<ActorDetailContent> {
  late final ActorDetailController _actorController;
  late final PagedMovieSummaryController _moviesController;
  late final MovieCollectionTypeChangeNotifier _collectionChangeNotifier;
  late final MovieSubscriptionChangeNotifier _subscriptionChangeNotifier;

  MovieFilterState _filterState = MovieFilterState.initial;
  List<MovieFilterYearOption> _movieYearOptions =
      const <MovieFilterYearOption>[];
  bool _hasLoadedMovieYears = false;
  bool _isMovieYearsLoading = false;
  String? _movieYearsErrorMessage;
  bool? _isActorSubscribedOverride;
  bool _isActorSubscriptionUpdating = false;

  Listenable get _pageListenable =>
      Listenable.merge(<Listenable>[_actorController, _moviesController]);

  @override
  void initState() {
    super.initState();
    _collectionChangeNotifier =
        context.read<MovieCollectionTypeChangeNotifier>();
    _collectionChangeNotifier.addListener(_onCollectionTypeChanged);
    _subscriptionChangeNotifier =
        context.read<MovieSubscriptionChangeNotifier>();
    _subscriptionChangeNotifier.addListener(_onMovieSubscriptionChanged);

    _actorController = ActorDetailController(
      actorId: widget.actorId,
      fetchActorDetail: context.read<ActorsApi>().getActorDetail,
    )..load();
    _moviesController = PagedMovieSummaryController(
      fetchPage: (page, pageSize) => context.read<MoviesApi>().getMovies(
            actorId: widget.actorId,
            page: page,
            pageSize: pageSize,
            status: _filterState.status,
            collectionType: _filterState.collectionType,
            sort: _filterState.sortExpression,
            year: _filterState.year,
          ),
      subscribeMovie: context.read<MoviesApi>().subscribeMovie,
      unsubscribeMovie: context.read<MoviesApi>().unsubscribeMovie,
      onSubscriptionChanged: _reportSubscriptionChange,
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
    _collectionChangeNotifier.removeListener(_onCollectionTypeChanged);
    _subscriptionChangeNotifier.removeListener(_onMovieSubscriptionChanged);
    _actorController.dispose();
    _moviesController.dispose();
    super.dispose();
  }

  void _onCollectionTypeChanged() {
    final change = _collectionChangeNotifier.lastChange;
    if (change == null) {
      return;
    }
    if (change.targetType == MovieCollectionType.collection &&
        _filterState.collectionType == MovieCollectionTypeFilter.single) {
      _moviesController.removeItem(change.movieNumber);
    }
  }

  void _onMovieSubscriptionChanged() {
    final change = _subscriptionChangeNotifier.lastChange;
    if (change == null) {
      return;
    }
    _moviesController.applySubscriptionChange(
      movieNumber: change.movieNumber,
      isSubscribed: change.isSubscribed,
    );
  }

  void _reportSubscriptionChange({
    required String movieNumber,
    required bool isSubscribed,
  }) {
    _subscriptionChangeNotifier.reportChange(
      movieNumber: movieNumber,
      isSubscribed: isSubscribed,
    );
  }

  void _applyFilter(MovieFilterState nextState) {
    if (nextState.matches(_filterState)) {
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

  void _loadMovieYearsIfNeeded() {
    if (_hasLoadedMovieYears || _isMovieYearsLoading) {
      return;
    }
    unawaited(_loadMovieYears());
  }

  Future<void> _loadMovieYears({bool force = false}) async {
    if (_isMovieYearsLoading || (_hasLoadedMovieYears && !force)) {
      return;
    }
    setState(() {
      _isMovieYearsLoading = true;
      _movieYearsErrorMessage = null;
    });

    try {
      final years = await context.read<ActorsApi>().getActorMovieYears(
            actorId: widget.actorId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _movieYearOptions = years.map(_toFilterYearOption).toList(
              growable: false,
            );
        _hasLoadedMovieYears = true;
        _isMovieYearsLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMovieYearsLoading = false;
        _movieYearsErrorMessage = '年份加载失败';
      });
    }
  }

  MovieFilterYearOption _toFilterYearOption(ActorMovieYearDto item) {
    return MovieFilterYearOption(
      year: item.year,
      movieCount: item.movieCount,
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

  Future<void> _handleRefresh() async {
    try {
      await Future.wait<void>([
        _actorController.refresh(),
        _moviesController.refresh(),
        if (_hasLoadedMovieYears) _loadMovieYears(force: true),
      ]);
      if (mounted) {
        setState(() {
          _isActorSubscribedOverride = null;
        });
      }
    } catch (_) {
      if (mounted) {
        final onRefreshFailure = widget.onRefreshFailure;
        if (onRefreshFailure != null) {
          onRefreshFailure(context);
        } else {
          showToast('刷新失败');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.surfaceColor,
      child: AnimatedBuilder(
        animation: _pageListenable,
        builder: (context, _) {
          if (_actorController.isLoading && _actorController.actor == null) {
            return widget.loadingBuilder(context);
          }

          if (_actorController.errorMessage != null ||
              _actorController.actor == null) {
            return widget.errorBuilder(
              context,
              _actorController.errorMessage ?? '女优详情暂时无法加载，请稍后重试',
              _actorController.load,
            );
          }

          final actor = _actorController.actor!;
          final isActorSubscribed =
              _isActorSubscribedOverride ?? actor.isSubscribed;
          final footer = widget.footerBuilder(context, _moviesController);

          return widget.bodyBuilder(
            context,
            _moviesController.scrollController,
            Column(
              key: widget.contentKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.headerBuilder(
                  context,
                  actor,
                  _moviesController.total,
                  isActorSubscribed,
                  _isActorSubscriptionUpdating,
                  _isActorSubscriptionUpdating
                      ? null
                      : () => _toggleActorSubscription(
                            isSubscribed: isActorSubscribed,
                          ),
                ),
                SizedBox(height: widget.sectionSpacing),
                MovieFilterToolbar(
                  filterState: _filterState,
                  onChanged: _applyFilter,
                  onReset: _resetFilters,
                  yearOptions: _movieYearOptions,
                  isYearOptionsLoading: _isMovieYearsLoading,
                  yearOptionsErrorMessage: _movieYearsErrorMessage,
                  onYearOptionsRetry: () => unawaited(
                    _loadMovieYears(force: true),
                  ),
                  onOpened: _loadMovieYearsIfNeeded,
                ),
                SizedBox(height: widget.sectionSpacing),
                MovieSummaryGrid(
                  items: _moviesController.items,
                  isLoading: _moviesController.isInitialLoading,
                  errorMessage: _moviesController.initialErrorMessage,
                  onMovieTap: (movie) =>
                      widget.onMovieTap(context, movie.movieNumber),
                  onMovieMenuRequest: (movie, globalPosition) {
                    unawaited(
                      showMovieCollectionFeatureActionMenu(
                        context: context,
                        movieNumber: movie.movieNumber,
                        globalPosition: globalPosition,
                      ),
                    );
                  },
                  onMovieSubscriptionTap: (movie) =>
                      _toggleMovieSubscription(movie.movieNumber),
                  isMovieSubscriptionUpdating: (movie) =>
                      _moviesController.isSubscriptionUpdating(
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
            widget.enableRefresh ? _handleRefresh : null,
          );
        },
      ),
    );
  }
}
