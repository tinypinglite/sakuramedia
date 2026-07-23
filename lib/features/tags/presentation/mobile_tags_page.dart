import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selection_controller.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selector_panel.dart';
import 'package:sakuramedia/features/tags/presentation/tags_page_state.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

/// 移动端标签页：标签多选区 + 所选标签下的影片列表。
///
/// 与桌面端 `DesktopTagsPage` 共用状态层（[TagsPageStateEntry]）与选择面板
/// （[TagSelectorPanel]）。无论一级抽屉入口还是详情页预选跳入，移动端都以
/// push 的子页面形式呈现，状态随页面自建自销，不接入缓存。
class MobileTagsPage extends StatefulWidget {
  const MobileTagsPage({super.key, this.initialTagId});

  /// 从影片详情页跳入时携带的预选标签；为空表示抽屉一级入口。
  final int? initialTagId;

  @override
  State<MobileTagsPage> createState() => _MobileTagsPageState();
}

class _MobileTagsPageState extends State<MobileTagsPage> {
  late final TagsPageStateEntry _pageState;

  TagSelectionController get _selection => _pageState.selection;

  @override
  void initState() {
    super.initState();
    _pageState = TagsPageStateEntry(
      tagsApi: context.read<TagsApi>(),
      moviesApi: context.read<MoviesApi>(),
      subscriptionChangeNotifier:
          context.read<MovieSubscriptionChangeNotifier>(),
      initialSelectedTagIds:
          widget.initialTagId == null
              ? const <int>[]
              : <int>[widget.initialTagId!],
      popularLimit: 5,
    );
  }

  @override
  void dispose() {
    _pageState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // 仅监听选择区：影片网格的重建由内部 MovieListContent 自行处理。
      animation: _selection,
      builder: (context, _) {
        if (!_selection.hasSelection) {
          return _buildEmptyState(context);
        }
        return _buildMoviesArea(context);
      },
    );
  }

  /// 未选标签：仅展示选择面板 + 引导空态（无需下拉刷新）。
  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('tags-page'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSelectorPanel(),
          SizedBox(height: context.appSpacing.lg),
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.appSpacing.xxl),
            child: const AppEmptyState(message: '请选择标签查看影片'),
          ),
        ],
      ),
    );
  }

  /// 已选标签：复用影片页「筛选条 + 总数 + 网格 + 分页底栏」呈现逻辑，
  /// 选择面板作为列表上方的 sliver 一起滚动，并支持下拉刷新。
  Widget _buildMoviesArea(BuildContext context) {
    return MovieListContent(
      key: const Key('tags-page'),
      pageState: _pageState,
      surfaceColor: context.appColors.surfaceCard,
      contentKey: const Key('tags-page-movies'),
      totalKey: const Key('tags-page-total'),
      sectionSpacing: context.appSpacing.md,
      emptyMessage: '该标签下暂无影片',
      onMovieTap:
          (context, movieNumber) => MobileMovieDetailRouteData(
            movieNumber: movieNumber,
          ).push(context),
      bodyBuilder:
          (context, scrollController, sliver, onRefresh) =>
              AppAdaptiveRefreshScrollView(
                onRefresh: onRefresh!,
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverToBoxAdapter(child: _buildSelectorPanel()),
                  SliverToBoxAdapter(
                    child: SizedBox(height: context.appSpacing.lg),
                  ),
                  sliver,
                ],
              ),
      enableRefresh: true,
      onRefreshFailure: (_) => showToast('刷新失败'),
    );
  }

  Widget _buildSelectorPanel() {
    return TagSelectorPanel(
      selection: _selection,
      onToggleTag: _selection.toggle,
      onRemoveTag: _selection.remove,
      onClear: _selection.clear,
      onQueryChanged: _selection.setQuery,
      onToggleExpanded: _selection.toggleExpanded,
      onMatchModeChanged: _selection.setMatchMode,
      onRetry: () => unawaited(_selection.retry()),
    );
  }
}
