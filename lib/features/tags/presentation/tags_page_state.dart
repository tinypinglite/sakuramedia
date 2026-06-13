import 'dart:async';

import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/movie_list_filterable_page_state.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selection_controller.dart';

/// 标签页的缓存状态：组合标签选择区与「所选标签影片」分页列表。
///
/// 复用 [MovieListSubscriptionSyncMixin] 的订阅同步接线，并实现
/// [MovieListFilterablePageState] 以便影片区直接复用 `MovieListContent`。
class TagsPageStateEntry
    with MovieListSubscriptionSyncMixin
    implements AppPageStateEntry, MovieListFilterablePageState {
  TagsPageStateEntry({
    required TagsApi tagsApi,
    required MoviesApi moviesApi,
    required this.subscriptionChangeNotifier,
    List<int> initialSelectedTagIds = const <int>[],
    int popularLimit = 60,
  }) : _moviesApi = moviesApi,
       selection = TagSelectionController(
         tagsApi: tagsApi,
         initialSelectedTagIds: initialSelectedTagIds,
         popularLimit: popularLimit,
       ) {
    controller = PagedMovieSummaryController(
      fetchPage: (page, pageSize) => _moviesApi.getMovies(
        page: page,
        pageSize: pageSize,
        tagIds: selection.selectedTagIds,
        tagMatch: selection.matchMode,
        status: filterState.status,
        collectionType: filterState.collectionType,
        numberSource: filterState.numberSource,
        sort: filterState.sortExpression,
      ),
      subscribeMovie: _moviesApi.subscribeMovie,
      unsubscribeMovie: _moviesApi.unsubscribeMovie,
      onSubscriptionChanged: reportSubscriptionChange,
      pageSize: 24,
      loadMoreTriggerOffset: 300,
      initialLoadErrorText: '标签影片加载失败，请稍后重试',
      loadMoreErrorText: '加载更多失败，请点击重试',
    );
    controller.attachScrollListener();
    selection.addListener(_onSelectionChanged);
    bindSubscriptionSync();
    unawaited(selection.load());
    // 带初始预选标签（从详情页跳入）时，种子选择发生在 listener 之前，
    // 需在此手动触发首拉影片。
    if (selection.hasSelection) {
      _lastFetchedSignature =
          _signatureFor(selection.selectedTagIds, selection.matchMode);
      unawaited(controller.initialize());
    }
  }

  final MoviesApi _moviesApi;

  @override
  final MovieSubscriptionChangeNotifier subscriptionChangeNotifier;

  final TagSelectionController selection;
  @override
  late final PagedMovieSummaryController controller;
  @override
  MovieFilterState filterState = MovieFilterState.initial;

  /// 上次实际拉取影片所用的标签签名，用来避免搜索/展开等无关变更触发重复请求。
  String? _lastFetchedSignature;

  String _signatureFor(List<int> tagIds, TagMatchMode matchMode) {
    final sorted = List<int>.from(tagIds)..sort();
    return '${matchMode.apiValue}|${sorted.join(',')}';
  }

  void _onSelectionChanged() {
    final tagIds = selection.selectedTagIds;
    if (tagIds.isEmpty) {
      // 无选择时不发请求，由页面展示引导空态。
      _lastFetchedSignature = null;
      return;
    }
    final signature = _signatureFor(tagIds, selection.matchMode);
    if (signature == _lastFetchedSignature) {
      return;
    }
    _lastFetchedSignature = signature;
    if (controller.scrollController.hasClients) {
      controller.scrollController.jumpTo(0);
    }
    unawaited(controller.reload());
  }

  @override
  void dispose() {
    selection.removeListener(_onSelectionChanged);
    unbindSubscriptionSync();
    selection.dispose();
    controller.dispose();
  }
}
