import 'package:sakuramedia/features/status/data/status_dto.dart';

/// 状态域加载态占位数据：真实 DTO + 中性数值，
/// 供概览 / 系统维护的 `AppSkeletonizer` 渲染与真实卡片同形的静态骨架。
///
/// 数值本身不需要真实，加载态由 `AppSkeletonizer` 灰化；这里只保证：
/// 需要渲染图表 / 长条 / 脚注的字段非空，卡片结构完整、加载前后不跳变。
StatusDto statusSummaryPlaceholder() {
  return const StatusDto(
    backendVersion: '0.0.0',
    actors: ActorStatsDto(femaleTotal: 128, femaleSubscribed: 24),
    movies: MovieStatsDto(total: 1024, subscribed: 256, playable: 896),
    mediaFiles: MediaFileStatsDto(
      total: 2048,
      totalSizeBytes: 2048 * 1024 * 1024,
    ),
    mediaLibraries: MediaLibraryStatsDto(total: 4),
    thumbnails: ThumbnailStatsDto(
      pendingMedia: 16,
      retryWaitMedia: 0,
      terminalFailedMedia: 0,
      total: 2048,
    ),
  );
}

StatusInsightsDto statusInsightsPlaceholder() {
  return StatusInsightsDto(
    downloadTasks: const StatusDownloadTaskSummaryDto(
      downloading: 3,
      importing: 2,
      imported: 64,
      importFailed: 1,
      skipped: 4,
      downloadFailed: 1,
      total: 75,
    ),
    mediaLibraries: mediaLibraryUsagePlaceholders(),
    collections: const CollectionsStatsDto(
      playlists: CollectionSummaryDto(count: 2, itemCount: 64),
      videoCollections: CollectionSummaryDto(count: 2, itemCount: 48),
      clipCollections: CollectionSummaryDto(count: 2, itemCount: 96),
      momentCollections: CollectionSummaryDto(count: 2, itemCount: 128),
    ),
  );
}

List<MediaLibraryUsageDto> mediaLibraryUsagePlaceholders({int count = 4}) {
  return List<MediaLibraryUsageDto>.generate(
    count,
    (index) => MediaLibraryUsageDto(
      libraryId: -1 - index,
      name: 'Library ${index + 1}',
      providerKey: 'provider',
      fileCount: 512,
      totalSizeBytes: 512 * 1024 * 1024,
      spaceTotalBytes: 2 * 1024 * 1024 * 1024,
      spaceUsedBytes: 1024 * 1024 * 1024,
      spaceFreeBytes: 1024 * 1024 * 1024,
    ),
    growable: false,
  );
}

StatusWatchTrendDto statusWatchTrendPlaceholder({
  required WatchTrendRange range,
}) {
  return StatusWatchTrendDto(
    range: range,
    granularity: range == WatchTrendRange.all ? 'month' : 'day',
    watchedMovieCount: 28,
    buckets: List<WatchTrendBucketDto>.generate(
      12,
      (index) => WatchTrendBucketDto(period: '2026-01', count: 2 + index % 5),
      growable: false,
    ),
  );
}

StatusImageSearchDto imageSearchStatusPlaceholder() {
  return const StatusImageSearchDto(
    healthy: true,
    embeddingService: ImageSearchEmbeddingServiceStatsDto(
      healthy: true,
      endpoint: 'http://embedding.example.com',
      dimension: 512,
    ),
    indexing: ImageSearchIndexingStatsDto(
      pendingThumbnails: 0,
      failedThumbnails: 0,
    ),
    indexSpace: ImageSearchIndexSpaceStatsDto(
      state: 'ready',
      indexedSpaceId: 'space',
    ),
  );
}
