import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selection_controller.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selector_panel.dart';
import 'package:sakuramedia/features/tags/presentation/tags_page_state.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

class DesktopTagsPage extends StatefulWidget {
  const DesktopTagsPage({super.key, this.initialTagId});

  /// 从影片详情页跳入时携带的预选标签；为空表示一级导航入口。
  final int? initialTagId;

  @override
  State<DesktopTagsPage> createState() => _DesktopTagsPageState();
}

class _DesktopTagsPageState extends State<DesktopTagsPage> {
  // 一级导航入口走缓存；带预选标签的子路由入口走独立非缓存状态，
  // 避免与缓存实例共用 scrollController 冲突。
  CachedPageStateHandle<TagsPageStateEntry>? _pageStateHandle;
  late final TagsPageStateEntry _pageState;

  TagSelectionController get _selection => _pageState.selection;

  @override
  void initState() {
    super.initState();
    if (widget.initialTagId == null) {
      // 一级导航入口：走缓存状态，侧边栏来回切换保留已选标签/滚动位置。
      final handle = obtainCachedPageState<TagsPageStateEntry>(
        context,
        key: desktopTagsPageStateKey(),
        create: _createPageState,
      );
      _pageStateHandle = handle;
      _pageState = handle.value;
    } else {
      // 详情页跳入的子路由：独立非缓存状态，自持 scrollController。
      _pageState = _createPageState(
        initialSelectedTagIds: <int>[widget.initialTagId!],
      );
    }
  }

  TagsPageStateEntry _createPageState({
    List<int> initialSelectedTagIds = const <int>[],
  }) {
    return TagsPageStateEntry(
      tagsApi: context.read<TagsApi>(),
      moviesApi: context.read<MoviesApi>(),
      subscriptionChangeNotifier:
          context.read<MovieSubscriptionChangeNotifier>(),
      initialSelectedTagIds: initialSelectedTagIds,
      popularLimit: 15,
    );
  }

  @override
  void dispose() {
    final handle = _pageStateHandle;
    if (handle != null) {
      handle.dispose();
    } else {
      _pageState.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _selection,
      builder: (context, _) {
        if (!_selection.hasSelection) {
          return ColoredBox(
            color: context.appColors.surfaceElevated,
            child: SingleChildScrollView(
              key: const Key('tags-page'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSelectorPanel(),
                  SizedBox(height: context.appSpacing.lg),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: context.appSpacing.xxl,
                    ),
                    child: const AppEmptyState(message: '请选择标签查看影片'),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildMoviesArea(context);
      },
    );
  }

  Widget _buildMoviesArea(BuildContext context) {
    return AppPageRefreshScope(
      onRefresh: _pageState.controller.refresh,
      child: MovieListContent(
      key: const Key('tags-page'),
      pageState: _pageState,
      surfaceColor: context.appColors.surfaceElevated,
      contentKey: const Key('tags-page-movies'),
      totalKey: const Key('tags-page-total'),
      sectionSpacing: context.appSpacing.lg,
      emptyMessage: '该标签下暂无影片',
      onMovieTap:
          (context, movieNumber) => context.pushDesktopMovieDetail(
            movieNumber: movieNumber,
            fallbackPath: desktopTagsPath,
          ),
      bodyBuilder:
          (context, scrollController, sliver, onRefresh) => CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildSelectorPanel()),
              SliverToBoxAdapter(
                child: SizedBox(height: context.appSpacing.lg),
              ),
              sliver,
            ],
          ),
      ),
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
