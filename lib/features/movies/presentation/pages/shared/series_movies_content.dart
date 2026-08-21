import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
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

class SeriesMoviesContent extends ConsumerStatefulWidget {
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
  /// 桌面端保持 `false`——批量动作在顶栏内联。语义对齐 `MovieSummaryListContent`。
  final bool useMobileSelectionLayout;

  /// 把系列名报给外层移动子页壳的返回栏（见 [AppMobileSubpageTitle]），信息槽里
  /// 就不再放它。移动端窄屏塞不下完整系列名，放返回栏才不会被压成省略号；桌面
  /// 顶栏是静态配置，仍走信息槽。
  final bool hoistTitleToSubpageShell;

  @override
  ConsumerState<SeriesMoviesContent> createState() =>
      _SeriesMoviesContentState();
}

class _SeriesMoviesContentState extends ConsumerState<SeriesMoviesContent>
    with
        MultiSelectStateMixin<SeriesMoviesContent, String>,
        MovieBatchSelectionMixin<SeriesMoviesContent> {
  late final String? _initialSeriesName;
  late final ScrollController _scrollController;

  MovieSummaryScope get _scope =>
      MovieSummaryScope.series(seriesId: widget.seriesId);

  @override
  String get batchKeyPrefix => 'series-movies';

  @override
  MovieBatchToggleExecutor get batchSubscriptionExecutor =>
      ref.read(movieSummaryProvider(_scope).notifier).batchToggleSubscription;

  @override
  MovieBlacklistBatchExecutor get batchBlacklistExecutor =>
      ref.read(movieSummaryProvider(_scope).notifier).blacklistMovies;

  @override
  List<String> get batchSelectableNumbers =>
      ref
          .read(movieSummaryProvider(_scope))
          .value
          ?.paged
          .items
          .map((movie) => movie.movieNumber)
          .toList(growable: false) ??
      const <String>[];

  @override
  void initState() {
    super.initState();
    _initialSeriesName = _normalizeSeriesName(widget.initialSeriesName);
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

  String _displaySeriesName(MovieSummaryState? summary) {
    final initialSeriesName = _initialSeriesName;
    if (initialSeriesName != null) {
      return initialSeriesName;
    }
    for (final movie in summary?.paged.items ?? const []) {
      final seriesName = movie.seriesName.trim();
      if (seriesName.isNotEmpty) {
        return seriesName;
      }
    }
    return '系列 #${widget.seriesId}';
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

  Future<void> _handleRefresh() async {
    try {
      final error = await ref
          .read(movieSummaryProvider(_scope).notifier)
          .refresh();
      if (error != null) {
        throw Exception(error);
      }
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
      await ref.read(movieSummaryProvider(_scope).notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(movieSummaryProvider(_scope));
    final summary = moviesAsync.value;
    final paged = summary?.paged;
    if (widget.hoistTitleToSubpageShell) {
      _reportTitleToShell(summary);
    }
    // AnimatedBuilder 只包住 sliver body——bodyBuilder 产出的
    // CustomScrollView / AppAdaptiveRefreshScrollView 不需要跟着分页 tick 重建。
    final body = AppPageRefreshScope(
      onRefresh: _handleRefresh,
      child: ColoredBox(
        color: widget.surfaceColor,
        child: widget.bodyBuilder(
          context,
          _scrollController,
          SliverMainAxisGroup(
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
                      _buildHeader(context, summary),
                    SizedBox(height: widget.sectionSpacing),
                  ],
                ),
              ),
              _buildMoviesArea(context, moviesAsync),
              if (paged != null &&
                  paged.items.isNotEmpty &&
                  (paged.isLoadingMore || paged.loadMoreErrorMessage != null))
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
          widget.enableRefresh ? _handleRefresh : null,
        ),
      ),
    );

    if (!widget.useMobileSelectionLayout) {
      return body;
    }
    // 底部批量条贴在列表下方常驻，不随列表滚动（对齐 MovieSummaryListContent）。
    return Column(
      children: [
        Expanded(child: body),
        if (selectionMode) buildMobileBatchSelectionBottomBar(),
      ],
    );
  }

  /// 把系列名报给外层返回栏。数据是异步来的，所以用 post-frame 回调写——直接在
  /// build 里改 notifier 会触发 build-during-build。
  void _reportTitleToShell(MovieSummaryState? summary) {
    final name = _displaySeriesName(summary).trim();
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
  Widget _buildHeader(BuildContext context, MovieSummaryState? summary) {
    return AppListHeader(
      informationSlots: [
        // 系列名报到返回栏时信息槽就不再放它，免得同一个名字出现两次。
        if (!widget.hoistTitleToSubpageShell)
          AppListHeaderInfo(
            key: const Key('series-movies-title'),
            label: _displaySeriesName(summary),
          ),
        AppListHeaderInfo(
          key: widget.totalKey,
          label: '共 ${summary?.paged.total ?? 0} 部',
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

  Widget _buildMoviesArea(
    BuildContext context,
    AsyncValue<MovieSummaryState> moviesAsync,
  ) {
    final summary = moviesAsync.value;
    if (moviesAsync.hasError && summary == null) {
      return SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppEmptyState(message: _scope.initialLoadErrorText),
            SizedBox(height: context.appSpacing.md),
            Center(
              child: TextButton(
                onPressed: () =>
                    ref.read(movieSummaryProvider(_scope).notifier).reload(),
                child: const Text('重试'),
              ),
            ),
          ],
        ),
      );
    }

    return MovieSummarySliver(
      items: summary?.paged.items ?? const [],
      isLoading: moviesAsync.isLoading && summary == null,
      onMovieTap: (movie) => widget.onMovieTap(context, movie.movieNumber),
      onMovieMenuRequest: (movie, globalPosition) {
        unawaited(
          showMovieCollectionFeatureActionMenu(
            context: context,
            movieNumber: movie.movieNumber,
            globalPosition: globalPosition,
            isSubscribed: movie.isSubscribed,
            onBlacklisted: () => ref
                .read(movieSummaryProvider(_scope).notifier)
                .removeMovies(<String>[movie.movieNumber]),
            // 移动端多选入口挂在长按菜单里，桌面仍在顶栏。
            onEnterSelection: widget.useMobileSelectionLayout
                ? () {
                    enterSelection();
                    toggleSelect(movie.movieNumber);
                  }
                : null,
          ),
        );
      },
      onMovieSubscriptionTap: (movie) =>
          _toggleMovieSubscription(movie.movieNumber),
      isMovieSubscriptionUpdating: (movie) =>
          summary?.isSubscriptionUpdating(movie.movieNumber) ?? false,
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
