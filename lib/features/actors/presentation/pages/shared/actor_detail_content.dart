import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_movie_year_dto.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/detail/actor_detail_controller.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/paged_actor_summary_controller.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_filter_drawer.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

typedef ActorDetailBodyBuilder =
    Widget Function(
      BuildContext context,
      ScrollController scrollController,
      Widget child,
      Future<void> Function()? onRefresh,
    );

typedef ActorDetailHeaderBuilder =
    Widget Function(
      BuildContext context,
      ActorListItemDto actor,
      int total,
      bool isSubscribed,
      bool isSubscriptionUpdating,
      VoidCallback? onSubscriptionTap,
    );

typedef ActorDetailErrorBuilder =
    Widget Function(BuildContext context, String message, VoidCallback onRetry);

typedef ActorDetailFooterBuilder =
    Widget? Function(
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
    this.useMobileFilterDrawer = false,
    this.useMobileSelectionLayout = false,
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

  /// 顶栏筛选入口点开什么：`true` 弹底部抽屉（移动端），`false` 就地展开浮层
  /// （桌面端）。两端按钮外观、面板内容、即时生效行为完全一致，只有容器不同。
  final bool useMobileFilterDrawer;

  /// 移动端多选布局：入口挂到**卡片长按浮层**（顶栏不再常驻「选择」），多选态
  /// 顶栏只留退出/计数/全选，批量动作走贴底的 `AppSelectionBottomBar`。
  /// 桌面端保持 `false`——批量动作在顶栏内联。语义对齐 `MovieListContent`。
  final bool useMobileSelectionLayout;

  @override
  State<ActorDetailContent> createState() => _ActorDetailContentState();
}

class _ActorDetailContentState extends State<ActorDetailContent>
    with
        MultiSelectStateMixin<ActorDetailContent, String>,
        MovieBatchSelectionMixin<ActorDetailContent> {
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

  @override
  String get batchKeyPrefix => 'actor-detail';

  @override
  MovieBatchToggleExecutor get batchSubscriptionExecutor =>
      _moviesController.batchToggleSubscription;

  @override
  List<String> get batchSelectableNumbers => _moviesController.items
      .map((movie) => movie.movieNumber)
      .toList(growable: false);

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
      fetchPage:
          (page, pageSize) => context.read<MoviesApi>().getMovies(
            actorId: widget.actorId,
            page: page,
            pageSize: pageSize,
            status: _filterState.status,
            collectionType: _filterState.collectionType,
            numberSource: _filterState.numberSource,
            sort: _filterState.sortExpression,
            year: _filterState.year,
          ),
      subscribeMovie: context.read<MoviesApi>().subscribeMovie,
      unsubscribeMovie: context.read<MoviesApi>().unsubscribeMovie,
      batchSubscribeMovies: context.read<MoviesApi>().batchSubscribeMovies,
      batchUnsubscribeMovies: context.read<MoviesApi>().batchUnsubscribeMovies,
      onSubscriptionChanged: _reportSubscriptionChange,
      onSubscriptionsBatchChanged: _subscriptionChangeNotifier.reportBatch,
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
      if (selectionMode && selectedIds.contains(change.movieNumber)) {
        setState(() => selectedIds.remove(change.movieNumber));
      }
    }
  }

  void _onMovieSubscriptionChanged() {
    _subscriptionChangeNotifier.consumePendingChanges(
      _moviesController.applySubscriptionChanges,
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
    // 切筛选跨结果集，选中态失去意义，对齐 MovieListContent 行为。
    if (selectionMode) {
      exitSelection();
    }
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
        _movieYearOptions = years
            .map(_toFilterYearOption)
            .toList(growable: false);
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
    return MovieFilterYearOption(year: item.year, movieCount: item.movieCount);
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

  /// 影片区顶栏：与影片 / 女优列表页共用同一条 `AppListHeader`。
  /// 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
  ///
  /// 总数不进信息槽：女优信息头里已经有「N 部」，再放一遍是重复。
  Widget _buildFilterHeader(BuildContext context) {
    return AppListHeader(
      filterButtonKey: const Key('actor-detail-filter-trigger'),
      filterLabel: _filterState.triggerLabel,
      filterPanelKey: const Key('actor-detail-filter-panel'),
      onFilterPanelOpened:
          widget.useMobileFilterDrawer ? null : _loadMovieYearsIfNeeded,
      onFilterTap:
          widget.useMobileFilterDrawer
              ? () => unawaited(_openFilterDrawer())
              : null,
      filterPanelBuilder:
          widget.useMobileFilterDrawer
              ? null
              : (_) => MovieFilterSectionGroup(
                filterState: _filterState,
                onChanged: _applyFilter,
                yearOptions: _movieYearOptions,
                isYearOptionsLoading: _isMovieYearsLoading,
                yearOptionsErrorMessage: _movieYearsErrorMessage,
                onYearOptionsRetry:
                    () => unawaited(_loadMovieYears(force: true)),
              ),
      filterPanelFooter: AppFilterPanelFooter(
        isDefault: _filterState.isDefault,
        onReset: _resetFilters,
      ),
      actionSlots: [
        // 移动端多选入口挂在卡片长按菜单里，顶栏不常驻「选择」。
        if (!widget.useMobileSelectionLayout) buildEnterSelectionButton(),
      ],
    );
  }

  Future<void> _openFilterDrawer() async {
    // 年份是懒加载的，而抽屉内容是**打开那一刻的快照**（不像桌面浮层会随
    // didUpdateWidget 重建）。所以这里先把年份取回来再弹，否则抽屉里的年份分节
    // 会永远停在转圈状态。只有首次点击会等这一次请求。
    if (!_hasLoadedMovieYears) {
      await _loadMovieYears();
    }
    if (!mounted) {
      return;
    }
    await showMobileMovieFilterDrawer(
      context,
      current: _filterState,
      onChanged: _applyFilter,
      yearOptions: _movieYearOptions,
      yearOptionsErrorMessage: _movieYearsErrorMessage,
      onYearOptionsRetry: () => unawaited(_loadMovieYears(force: true)),
    );
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
    // 分两层监听：外层只跟 _actorController（切 loading / error / normal 分支），
    // 内层跟 _moviesController（分页 tick 只重建 sliver body，不重建外层
    // CustomScrollView / RefreshIndicator）。对齐 MovieListContent 的写法。
    final body = AppPageRefreshScope(
      onRefresh: _handleRefresh,
      child: ColoredBox(
        color: widget.surfaceColor,
        child: AnimatedBuilder(
          animation: _actorController,
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

            return widget.bodyBuilder(
              context,
              _moviesController.scrollController,
              AnimatedBuilder(
                animation: _moviesController,
                builder: (context, _) {
                  final footer = widget.footerBuilder(
                    context,
                    _moviesController,
                  );
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: widget.contentKey,
                          child: widget.headerBuilder(
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
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: widget.sectionSpacing),
                      ),
                      SliverToBoxAdapter(
                        child:
                            selectionMode
                                ? (widget.useMobileSelectionLayout
                                    ? buildMobileBatchSelectionHeader()
                                    : buildBatchSelectionToolbar())
                                : _buildFilterHeader(context),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: widget.sectionSpacing),
                      ),
                      MovieSummarySliver(
                        items: _moviesController.items,
                        isLoading: _moviesController.isInitialLoading,
                        errorMessage: _moviesController.initialErrorMessage,
                        onMovieTap:
                            (movie) =>
                                widget.onMovieTap(context, movie.movieNumber),
                        onMovieMenuRequest: (movie, globalPosition) {
                          unawaited(
                            showMovieCollectionFeatureActionMenu(
                              context: context,
                              movieNumber: movie.movieNumber,
                              globalPosition: globalPosition,
                              isSubscribed: movie.isSubscribed,
                              // 移动端多选入口挂在长按菜单里，桌面仍在顶栏。
                              onEnterSelection:
                                  widget.useMobileSelectionLayout
                                      ? () {
                                        enterSelection();
                                        toggleSelect(movie.movieNumber);
                                      }
                                      : null,
                            ),
                          );
                        },
                        onMovieSubscriptionTap:
                            (movie) =>
                                _toggleMovieSubscription(movie.movieNumber),
                        isMovieSubscriptionUpdating:
                            (movie) => _moviesController.isSubscriptionUpdating(
                              movie.movieNumber,
                            ),
                        emptyMessage: '暂无影片数据',
                        selectionMode: selectionMode,
                        isMovieSelected:
                            (movie) => isSelected(movie.movieNumber),
                        onMovieSelectedChanged:
                            (movie, _) => toggleSelect(movie.movieNumber),
                      ),
                      if (footer != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: context.appSpacing.md,
                            ),
                            child: footer,
                          ),
                        ),
                    ],
                  );
                },
              ),
              widget.enableRefresh ? _handleRefresh : null,
            );
          },
        ),
      ),
    );

    if (!widget.useMobileSelectionLayout) {
      return body;
    }
    // 底部批量条贴在列表下方常驻，不随列表滚动（对齐 MovieListContent）。
    return Column(
      children: [
        Expanded(child: body),
        if (selectionMode)
          AnimatedBuilder(
            animation: _moviesController,
            builder: (context, _) => buildMobileBatchSelectionBottomBar(),
          ),
      ],
    );
  }
}
