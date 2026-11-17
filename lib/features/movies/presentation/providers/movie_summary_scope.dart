import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 影片摘要分页列表的来源与实例边界。
///
/// 波 A 的每个非缓存入口都持有独立 scope：即使请求同一个端点，不同页大小或
/// 错误文案也不共享分页进度，保持迁移前「每个页面 State 各有一个 controller」
/// 的生命周期语义。缓存页会在批次 5 波 B 另行通过 [RiverpodPageCache] 保活。
enum MovieSummarySource {
  latest,
  movies,
  tags,
  subscribedActorsLatest,
  recentlySubscribed,
  blacklisted,
  actor,
  playlist,
  series,
  rated,
}

@immutable
class MovieSummaryScope {
  const MovieSummaryScope._({
    required this.source,
    required this.pageSize,
    this.initialLoadErrorTextOverride,
    this.resourceId,
    this.instanceKey,
    this.cacheKey,
    this.initialTagIds = const <int>[],
    this.initialTagMatch = TagMatchMode.or,
    this.initialMovieFilter,
  });

  const MovieSummaryScope.latest({int pageSize = 24})
    : this._(source: MovieSummarySource.latest, pageSize: pageSize);

  /// 普通影片库列表；与概览的 latest endpoint 独立，支持完整 [MovieFilterState]
  /// 筛选。带 [cacheKey] 时由页面通过 RiverpodPageCache 保活。
  const MovieSummaryScope.movies({required String cacheKey, int pageSize = 24})
    : this._(
        source: MovieSummarySource.movies,
        cacheKey: cacheKey,
        pageSize: pageSize,
      );

  const MovieSummaryScope.subscribedActorsLatest({
    int pageSize = 24,
    String? initialLoadErrorTextOverride,
  }) : this._(
         source: MovieSummarySource.subscribedActorsLatest,
         pageSize: pageSize,
         initialLoadErrorTextOverride: initialLoadErrorTextOverride,
       );

  /// 最近订阅影片：当前仍已订阅的影片，按订阅时间倒序。
  /// 供概览 /「我的」tab 的「最近订阅」区块与其「更多」页共用。
  const MovieSummaryScope.recentlySubscribed({int pageSize = 24})
    : this._(source: MovieSummarySource.recentlySubscribed, pageSize: pageSize);

  const MovieSummaryScope.blacklisted({int pageSize = 24})
    : this._(source: MovieSummarySource.blacklisted, pageSize: pageSize);

  /// 所选标签下的影片列表。
  ///
  /// 一级导航入口没有预选标签：provider 首建只返回空分页状态、不请求，等页面
  /// 选择标签后由 `applyTagFilter` 发起首拉。从影片详情跳入的入口把已知的
  /// [initialTagIds] / [initialTagMatch] 交给 scope，首拉直接带上标签条件，
  /// 不必先渲染一次「没有影片」再纠正。
  const MovieSummaryScope.tags({
    required String instanceKey,
    String? cacheKey,
    int pageSize = 24,
    List<int> initialTagIds = const <int>[],
    TagMatchMode initialTagMatch = TagMatchMode.or,
  }) : this._(
         source: MovieSummarySource.tags,
         instanceKey: instanceKey,
         cacheKey: cacheKey,
         pageSize: pageSize,
         initialTagIds: initialTagIds,
         initialTagMatch: initialTagMatch,
       );

  const MovieSummaryScope.actor({required int actorId, int pageSize = 24})
    : this._(
        source: MovieSummarySource.actor,
        resourceId: actorId,
        pageSize: pageSize,
      );

  const MovieSummaryScope.playlist({required int playlistId, int pageSize = 24})
    : this._(
        source: MovieSummarySource.playlist,
        resourceId: playlistId,
        pageSize: pageSize,
      );

  const MovieSummaryScope.series({required int seriesId, int pageSize = 24})
    : this._(
        source: MovieSummarySource.series,
        resourceId: seriesId,
        pageSize: pageSize,
      );

  /// 已评分影片：只列个人评分记录，默认按总分倒序、包含合集。
  const MovieSummaryScope.rated({String? cacheKey, int pageSize = 24})
    : this._(
        source: MovieSummarySource.rated,
        cacheKey: cacheKey,
        pageSize: pageSize,
        initialMovieFilter: const MovieFilterState(
          collectionType: MovieCollectionTypeFilter.all,
          sortField: MovieSortField.myScore,
        ),
      );

  /// 桌面 / 移动「我的评分」页共用的实例；评分写入后按同一 scope 精确失效。
  ///
  /// 不设 cacheKey：页面在 shell 分支里本身不会随切页销毁，无需自行保活；
  /// 登出或页面销毁后仍能按 autoDispose 释放，避免残留上一账号的列表。
  static const MovieSummaryScope ratedList = MovieSummaryScope.rated();

  final MovieSummarySource source;
  final int? resourceId;
  final String? instanceKey;
  final int pageSize;

  /// 显式覆盖首屏失败文案；为 `null` 时由 [MovieSummaryScopeX.errorText]
  /// 按当前语言与 [source] 取默认文案。
  final String? initialLoadErrorTextOverride;
  final String? cacheKey;

  /// 首拉就带上的标签条件；空表示先建 provider、由页面 `applyTagFilter` 首拉。
  final List<int> initialTagIds;
  final TagMatchMode initialTagMatch;

  /// 首拉的影片筛选；为 `null` 时使用 [MovieFilterState.initial]。
  final MovieFilterState? initialMovieFilter;

  @override
  bool operator ==(Object other) {
    return other is MovieSummaryScope &&
        other.source == source &&
        other.resourceId == resourceId &&
        other.instanceKey == instanceKey &&
        other.pageSize == pageSize &&
        other.initialLoadErrorTextOverride == initialLoadErrorTextOverride &&
        other.cacheKey == cacheKey &&
        listEquals(other.initialTagIds, initialTagIds) &&
        other.initialTagMatch == initialTagMatch &&
        (other.initialMovieFilter == null) == (initialMovieFilter == null) &&
        (other.initialMovieFilter == null ||
            other.initialMovieFilter!.matches(initialMovieFilter!));
  }

  @override
  int get hashCode => Object.hash(
    source,
    resourceId,
    instanceKey,
    pageSize,
    initialLoadErrorTextOverride,
    cacheKey,
    Object.hashAll(initialTagIds),
    initialTagMatch,
    initialMovieFilter?.sortExpression,
  );
}

/// 首屏失败文案的取值入口：显式覆盖优先，否则按 [MovieSummaryScope.source]
/// 取当前语言的默认文案。
extension MovieSummaryScopeX on MovieSummaryScope {
  String errorText(AppLocalizations l10n) {
    final override = initialLoadErrorTextOverride;
    if (override != null) {
      return override;
    }
    return switch (source) {
      MovieSummarySource.latest => l10n.errorLatestMovieListLoadFailed,
      MovieSummarySource.movies ||
      MovieSummarySource.actor ||
      MovieSummarySource.playlist => l10n.errorMovieListLoadFailed,
      MovieSummarySource.tags => l10n.errorTagMovieListLoadFailed,
      MovieSummarySource.subscribedActorsLatest =>
        l10n.errorFollowedMovieListLoadFailed,
      MovieSummarySource.recentlySubscribed =>
        l10n.errorRecentlySubscribedMovieListLoadFailed,
      MovieSummarySource.blacklisted =>
        l10n.errorBlacklistedMovieListLoadFailed,
      MovieSummarySource.series => l10n.errorSeriesMovieListLoadFailed,
      MovieSummarySource.rated => l10n.errorMyRatingMovieListLoadFailed,
    };
  }
}
