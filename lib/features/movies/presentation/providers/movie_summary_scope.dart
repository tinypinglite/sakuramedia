import 'package:flutter/foundation.dart';

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
  blacklisted,
  actor,
  playlist,
  series,
}

@immutable
class MovieSummaryScope {
  const MovieSummaryScope._({
    required this.source,
    required this.pageSize,
    required this.initialLoadErrorText,
    this.resourceId,
    this.instanceKey,
    this.cacheKey,
  });

  const MovieSummaryScope.latest({int pageSize = 24})
    : this._(
        source: MovieSummarySource.latest,
        pageSize: pageSize,
        initialLoadErrorText: '最新入库影片加载失败，请稍后重试',
      );

  /// 普通影片库列表；与概览的 latest endpoint 独立，支持完整 [MovieFilterState]
  /// 筛选。带 [cacheKey] 时由页面通过 RiverpodPageCache 保活。
  const MovieSummaryScope.movies({required String cacheKey, int pageSize = 24})
    : this._(
        source: MovieSummarySource.movies,
        cacheKey: cacheKey,
        pageSize: pageSize,
        initialLoadErrorText: '影片列表加载失败，请稍后重试',
      );

  const MovieSummaryScope.subscribedActorsLatest({
    int pageSize = 24,
    String initialLoadErrorText = '关注影片加载失败，请稍后重试',
  }) : this._(
         source: MovieSummarySource.subscribedActorsLatest,
         pageSize: pageSize,
         initialLoadErrorText: initialLoadErrorText,
       );

  const MovieSummaryScope.blacklisted({int pageSize = 24})
    : this._(
        source: MovieSummarySource.blacklisted,
        pageSize: pageSize,
        initialLoadErrorText: '屏蔽影片加载失败，请稍后重试',
      );

  /// 所选标签下的影片列表。首次没有标签时 provider 只返回空分页状态、不请求；
  /// 页面在标签选择发生后通过 `applyTagFilter` 显式发起首拉。
  const MovieSummaryScope.tags({
    required String instanceKey,
    String? cacheKey,
    int pageSize = 24,
  }) : this._(
         source: MovieSummarySource.tags,
         instanceKey: instanceKey,
         cacheKey: cacheKey,
         pageSize: pageSize,
         initialLoadErrorText: '标签影片加载失败，请稍后重试',
       );

  const MovieSummaryScope.actor({required int actorId, int pageSize = 24})
    : this._(
        source: MovieSummarySource.actor,
        resourceId: actorId,
        pageSize: pageSize,
        initialLoadErrorText: '影片列表加载失败，请稍后重试',
      );

  const MovieSummaryScope.playlist({required int playlistId, int pageSize = 24})
    : this._(
        source: MovieSummarySource.playlist,
        resourceId: playlistId,
        pageSize: pageSize,
        initialLoadErrorText: '影片列表加载失败，请稍后重试',
      );

  const MovieSummaryScope.series({required int seriesId, int pageSize = 24})
    : this._(
        source: MovieSummarySource.series,
        resourceId: seriesId,
        pageSize: pageSize,
        initialLoadErrorText: '系列影片加载失败，请稍后重试',
      );

  final MovieSummarySource source;
  final int? resourceId;
  final String? instanceKey;
  final int pageSize;
  final String initialLoadErrorText;
  final String? cacheKey;

  @override
  bool operator ==(Object other) {
    return other is MovieSummaryScope &&
        other.source == source &&
        other.resourceId == resourceId &&
        other.instanceKey == instanceKey &&
        other.pageSize == pageSize &&
        other.initialLoadErrorText == initialLoadErrorText &&
        other.cacheKey == cacheKey;
  }

  @override
  int get hashCode => Object.hash(
    source,
    resourceId,
    instanceKey,
    pageSize,
    initialLoadErrorText,
    cacheKey,
  );
}
