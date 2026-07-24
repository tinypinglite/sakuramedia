import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/series_import/series_import_dialog.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

typedef SeriesMoviesBodyBuilder =
    Widget Function(
      BuildContext context,
      ScrollController scrollController,
      Widget sliver,
      Future<void> Function()? onRefresh,
    );

class SeriesMoviesContent extends StatefulWidget {
  const SeriesMoviesContent({
    super.key,
    required this.seriesId,
    required this.surfaceColor,
    required this.contentKey,
    required this.totalKey,
    required this.sectionSpacing,
    required this.onMovieTap,
    required this.bodyBuilder,
    this.initialSeriesName,
    this.enableRefresh = false,
    this.onRefreshFailure,
    this.useMobileSelectionLayout = false,
    this.hoistTitleToSubpageShell = false,
  });

  final int seriesId;
  final String? initialSeriesName;
  final Color surfaceColor;
  final Key contentKey;
  final Key totalKey;
  final double sectionSpacing;
  final void Function(BuildContext context, String movieNumber) onMovieTap;
  final SeriesMoviesBodyBuilder bodyBuilder;
  final bool enableRefresh;
  final void Function(BuildContext context)? onRefreshFailure;

  /// 移动端多选布局：入口挂到**卡片长按浮层**（顶栏不再常驻「选择」），多选态
  /// 顶栏只留退出/计数/全选，批量动作走贴底的 `AppSelectionBottomBar`。
  /// 桌面端保持 `false`——批量动作在顶栏内联。语义对齐 `MovieListContent`。
  final bool useMobileSelectionLayout;

  /// 把系列名报给外层移动子页壳的返回栏（见 [AppMobileSubpageTitle]），信息槽里
  /// 就不再放它。移动端窄屏塞不下完整系列名，放返回栏才不会被压成省略号；桌面
  /// 顶栏是静态配置，仍走信息槽。
  final bool hoistTitleToSubpageShell;

  @override
  State<SeriesMoviesContent> createState() => _SeriesMoviesContentState();
}

class _SeriesMoviesContentState extends State<SeriesMoviesContent>
    with
        MultiSelectStateMixin<SeriesMoviesContent, String>,
        MovieBatchSelectionMixin<SeriesMoviesContent> {
  late final PagedMovieSummaryController _controller;
  late final MovieSubscriptionChangeNotifier _subscriptionChangeNotifier;
  late final String? _initialSeriesName;

  @override
  String get batchKeyPrefix => 'series-movies';

  @override
  MovieBatchToggleExecutor get batchSubscriptionExecutor =>
      _controller.batchToggleSubscription;

  @override
  List<String> get batchSelectableNumbers => _controller.items
      .map((movie) => movie.movieNumber)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _initialSeriesName = _normalizeSeriesName(widget.initialSeriesName);
    _subscriptionChangeNotifier =
        context.read<MovieSubscriptionChangeNotifier>();
    _subscriptionChangeNotifier.addListener(_onMovieSubscriptionChanged);
    _controller = PagedMovieSummaryController(
      fetchPage:
          (page, pageSize) => context.read<MoviesApi>().getMoviesBySeries(
            seriesId: widget.seriesId,
            page: page,
            pageSize: pageSize,
          ),
      subscribeMovie: context.read<MoviesApi>().subscribeMovie,
      unsubscribeMovie: context.read<MoviesApi>().unsubscribeMovie,
      batchSubscribeMovies: context.read<MoviesApi>().batchSubscribeMovies,
      batchUnsubscribeMovies: context.read<MoviesApi>().batchUnsubscribeMovies,
      onSubscriptionChanged: _reportSubscriptionChange,
      onSubscriptionsBatchChanged: _subscriptionChangeNotifier.reportBatch,
      pageSize: 24,
      loadMoreTriggerOffset: 300,
      initialLoadErrorText: '系列影片加载失败，请稍后重试',
      loadMoreErrorText: '加载更多失败，请点击重试',
    );
    _controller.attachScrollListener();
    _controller.initialize();
  }

  @override
  void dispose() {
    _subscriptionChangeNotifier.removeListener(_onMovieSubscriptionChanged);
    _controller.dispose();
    super.dispose();
  }

  String get _displaySeriesName {
    final initialSeriesName = _initialSeriesName;
    if (initialSeriesName != null) {
      return initialSeriesName;
    }
    for (final movie in _controller.items) {
      final seriesName = movie.seriesName.trim();
      if (seriesName.isNotEmpty) {
        return seriesName;
      }
    }
    return '系列 #${widget.seriesId}';
  }

  void _onMovieSubscriptionChanged() {
    _subscriptionChangeNotifier.consumePendingChanges(
      _controller.applySubscriptionChanges,
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

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await _controller.toggleSubscription(
      movieNumber: movieNumber,
    );
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  Future<void> _handleRefresh() async {
    try {
      await _controller.refresh();
    } catch (_) {
      if (!mounted) {
        return;
      }
      final onRefreshFailure = widget.onRefreshFailure;
      if (onRefreshFailure != null) {
        onRefreshFailure(context);
      } else {
        showToast('刷新失败');
      }
    }
  }

  Future<void> _handleImport() async {
    final hasNewMovies = await showSeriesImportDialog(context, widget.seriesId);
    if (hasNewMovies && mounted) {
      await _controller.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hoistTitleToSubpageShell) {
      _reportTitleToShell();
    }
    // AnimatedBuilder 只包住 sliver body——bodyBuilder 产出的
    // CustomScrollView / AppAdaptiveRefreshScrollView 不需要跟着分页 tick 重建。
    final body = AppPageRefreshScope(
      onRefresh: _handleRefresh,
      child: ColoredBox(
        color: widget.surfaceColor,
        child: widget.bodyBuilder(
          context,
          _controller.scrollController,
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final showFooter =
                  _controller.items.isNotEmpty &&
                  (_controller.isLoadingMore ||
                      _controller.loadMoreErrorMessage != null);
              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      key: widget.contentKey,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (selectionMode)
                          (widget.useMobileSelectionLayout
                              ? buildMobileBatchSelectionHeader()
                              : buildBatchSelectionToolbar())
                        else
                          _buildHeader(context),
                        SizedBox(height: widget.sectionSpacing),
                      ],
                    ),
                  ),
                  _buildMoviesArea(context),
                  if (showFooter)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: context.appSpacing.md),
                        child: AppPagedLoadMoreFooter(
                          isLoading: _controller.isLoadingMore,
                          errorMessage: _controller.loadMoreErrorMessage,
                          onRetry: _controller.loadMore,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          widget.enableRefresh ? _handleRefresh : null,
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
            animation: _controller,
            builder: (context, _) => buildMobileBatchSelectionBottomBar(),
          ),
      ],
    );
  }

  /// 把系列名报给外层返回栏。数据是异步来的，所以用 post-frame 回调写——直接在
  /// build 里改 notifier 会触发 build-during-build。
  void _reportTitleToShell() {
    final name = _displaySeriesName.trim();
    if (name.isEmpty) {
      return;
    }
    final notifier = AppMobileSubpageTitle.read(context);
    if (notifier == null || notifier.value == name) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        notifier.value = name;
      }
    });
  }

  /// 列表顶栏：与其它列表页共用同一条 `AppListHeader`。
  ///
  /// **本页没有筛选维度**——后端 `/movies/by-series` 只吃 seriesId + 分页，所以
  /// 不接筛选入口，左侧留给信息槽。系列名与总数都是只读信息，「同步系列影片」
  /// 与「选择」是操作。
  Widget _buildHeader(BuildContext context) {
    return AppListHeader(
      informationSlots: [
        // 系列名报到返回栏时信息槽就不再放它，免得同一个名字出现两次。
        if (!widget.hoistTitleToSubpageShell)
          AppListHeaderInfo(
            key: const Key('series-movies-title'),
            label: _displaySeriesName,
          ),
        AppListHeaderInfo(
          key: widget.totalKey,
          label: '共 ${_controller.total} 部',
        ),
      ],
      actionSlots: [
        AppTextButton(
          key: const Key('series-movies-import-button'),
          label: '同步系列影片',
          size: AppTextButtonSize.small,
          onPressed: _handleImport,
        ),
        // 移动端多选入口挂在卡片长按菜单里，顶栏不常驻「选择」。
        if (!widget.useMobileSelectionLayout) buildEnterSelectionButton(),
      ],
    );
  }

  Widget _buildMoviesArea(BuildContext context) {
    if (_controller.initialErrorMessage != null &&
        !_controller.isInitialLoading) {
      return SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppEmptyState(message: _controller.initialErrorMessage!),
            SizedBox(height: context.appSpacing.md),
            Center(
              child: TextButton(
                onPressed: _controller.reload,
                child: const Text('重试'),
              ),
            ),
          ],
        ),
      );
    }

    return MovieSummarySliver(
      items: _controller.items,
      isLoading: _controller.isInitialLoading,
      onMovieTap: (movie) => widget.onMovieTap(context, movie.movieNumber),
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
          (movie) => _toggleMovieSubscription(movie.movieNumber),
      isMovieSubscriptionUpdating:
          (movie) => _controller.isSubscriptionUpdating(movie.movieNumber),
      emptyMessage: '该系列暂无影片',
      selectionMode: selectionMode,
      isMovieSelected: (movie) => isSelected(movie.movieNumber),
      onMovieSelectedChanged: (movie, _) => toggleSelect(movie.movieNumber),
    );
  }

  String? _normalizeSeriesName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
