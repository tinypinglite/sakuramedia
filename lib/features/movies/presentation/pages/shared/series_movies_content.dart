import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/series_import/series_import_dialog.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/providers/stable_set_selection.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';
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

  MovieCardHoverFeatureActions get _hoverFeatureActions =>
      movieCardHoverFeatureActions(
        context,
        onBlacklisted: (movieNumber) => ref
            .read(movieSummaryProvider(_scope).notifier)
            .removeMovies(<String>[movieNumber]),
      );

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
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _displaySeriesName(
    Iterable<MovieListItemDto> movies, {
    required AppLocalizations l10n,
  }) {
    final initialSeriesName = _initialSeriesName;
    if (initialSeriesName != null) {
      return initialSeriesName;
    }
    for (final movie in movies) {
      final seriesName = movie.seriesName.trim();
      if (seriesName.isNotEmpty) {
        return seriesName;
      }
    }
    return l10n.moviePageSeriesFallbackName(widget.seriesId);
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(movieSummaryProvider(_scope).notifier)
        .toggleSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
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
        showToast(
          AppLocalizations.of(context).moviePageRefreshFailed,
          tone: AppToastTone.error,
        );
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
    final view = ref.watch(
      movieSummaryProvider(
        _scope,
      ).select((async) => pagedViewSnapshot(async, (state) => state.paged)),
    );
    final subscriptionUpdating = ref.watch(
      movieSummaryProvider(_scope).select(
        (async) => StableSetSelection<String>(
          async.value?.subscriptionUpdatingMovieNumbers ?? const <String>{},
        ),
      ),
    );
    if (widget.hoistTitleToSubpageShell) {
      _reportTitleToShell(view.items);
    }
    // AnimatedBuilder 只包住 sliver body——bodyBuilder 产出的
    // CustomScrollView / AppAdaptiveRefreshScrollView 不需要跟着分页 tick 重建。
    final body = AppPageRefreshScope(
      onRefresh: _handleRefresh,
      child: AppFixedHeaderLayout(
        header: Column(
          key: widget.contentKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selectionMode)
              (widget.useMobileSelectionLayout
                  ? buildMobileBatchSelectionHeader()
                  : buildGlassBatchSelectionToolbar())
            else
              _buildHeader(context, view.items, view.total),
            SizedBox(height: widget.sectionSpacing),
          ],
        ),
        child: AppPagedLoadMoreScope(
          canLoadMore: () =>
              ref
                  .read(movieSummaryProvider(_scope))
                  .value
                  ?.paged
                  .canAutoLoadMore ??
              false,
          onLoadMore: () =>
              ref.read(movieSummaryProvider(_scope).notifier).loadMore(),
          child: widget.bodyBuilder(
            context,
            _scrollController,
            SliverMainAxisGroup(
              slivers: [
                _buildMoviesArea(
                  context,
                  view,
                  subscriptionUpdatingMovieNumbers: subscriptionUpdating,
                ),
                // loadMore 页脚独立订阅：翻页 loading / 失败只重建页脚。
                PagedLoadMoreFooterSliver(
                  watchFooter: (ref) => ref.watch(
                    movieSummaryProvider(_scope).select(
                      (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
                    ),
                  ),
                  onLoadMore: (ref) => unawaited(
                    ref.read(movieSummaryProvider(_scope).notifier).loadMore(),
                  ),
                ),
              ],
            ),
            widget.enableRefresh ? _handleRefresh : null,
          ),
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
  void _reportTitleToShell(Iterable<MovieListItemDto> movies) {
    final name = _displaySeriesName(
      movies,
      l10n: AppLocalizations.of(context),
    ).trim();
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

  /// 列表顶栏：桌面走玻璃控制条，移动端使用紧凑玻璃图标行。
  ///
  /// **本页没有筛选维度**——后端 `/movies/by-series` 只吃 seriesId + 分页，所以
  /// 不接筛选入口，左侧留给信息槽。系列名与总数都是只读信息，「同步系列影片」
  /// 与「选择」是操作。
  Widget _buildHeader(
    BuildContext context,
    Iterable<MovieListItemDto> movies,
    int total,
  ) {
    final l10n = AppLocalizations.of(context);
    final seriesName = _displaySeriesName(movies, l10n: l10n);
    final totalLabel = l10n.moviePageSeriesTotalCount(total);
    if (!widget.useMobileSelectionLayout) {
      return AppGlassListHeader(
        leading: AppGlassHeaderGroup(
          children: <Widget>[
            if (!widget.hoistTitleToSubpageShell)
              AppGlassHeaderText(
                key: const Key('series-movies-title'),
                label: seriesName,
              ),
            AppGlassHeaderText(key: widget.totalKey, label: totalLabel),
          ],
        ),
        trailing: AppGlassHeaderGroup(
          children: <Widget>[
            AppGlassHeaderButton(
              key: const Key('series-movies-import-button'),
              icon: Icons.sync_rounded,
              label: l10n.moviePageSeriesSync,
              onTap: _handleImport,
            ),
            AppGlassHeaderButton(
              key: const Key('series-movies-enter-selection-button'),
              icon: Icons.check_circle_outline,
              label: l10n.baseSelect,
              enabled: batchSelectableNumbers.isNotEmpty,
              onTap: batchSelectableNumbers.isEmpty ? () {} : enterSelection,
            ),
          ],
        ),
      );
    }
    return AppMobileListHeader(
      leading: AppMobileHeaderText(
        key: widget.totalKey,
        title: widget.hoistTitleToSubpageShell ? null : seriesName,
        countLabel: totalLabel,
      ),
      actions: <Widget>[
        AppGlassIconButton(
          key: const Key('series-movies-import-button'),
          tooltip: l10n.moviePageSeriesSync,
          icon: Icons.sync_rounded,
          onPressed: _handleImport,
        ),
      ],
    );
  }

  Widget _buildMoviesArea(
    BuildContext context,
    PagedViewSnapshot<MovieListItemDto> view, {
    required StableSetSelection<String> subscriptionUpdatingMovieNumbers,
  }) {
    if (view.initialError != null) {
      return SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppEmptyState(
              message: _scope.errorText(AppLocalizations.of(context)),
            ),
            SizedBox(height: context.appSpacing.md),
            Center(
              child: TextButton(
                onPressed: () =>
                    ref.read(movieSummaryProvider(_scope).notifier).reload(),
                child: Text(AppLocalizations.of(context).commonRetry),
              ),
            ),
          ],
        ),
      );
    }

    final isInitialLoading = view.isInitialLoading;
    return AppSkeletonizer.sliver(
      enabled: isInitialLoading,
      child: MovieSummarySliver(
        items: isInitialLoading
            ? movieListItemPlaceholders(count: 24)
            : view.items,
        onMovieTap: (movie) => selectionAwareTap(
          movie.movieNumber,
          () => widget.onMovieTap(context, movie.movieNumber),
        )(),
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
                  ? () => enterSelection(initial: movie.movieNumber)
                  : null,
            ),
          );
        },
        onMovieSubscriptionTap: (movie) =>
            _toggleMovieSubscription(movie.movieNumber),
        onMovieToggleCollectionType: _hoverFeatureActions.toggleCollectionType,
        onMovieBlacklist: _hoverFeatureActions.blacklist,
        isMovieSubscriptionUpdating: (movie) =>
            subscriptionUpdatingMovieNumbers.contains(movie.movieNumber),
        emptyMessage: AppLocalizations.of(context).moviePageSeriesEmpty,
        selectionMode: selectionMode,
        isMovieSelected: (movie) => isSelected(movie.movieNumber),
        onMovieSelectedChanged: (movie, _) =>
            handleSelectTap(movie.movieNumber),
      ),
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
