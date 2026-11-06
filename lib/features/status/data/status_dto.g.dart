// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActorStatsDto _$ActorStatsDtoFromJson(Map<String, dynamic> json) =>
    ActorStatsDto(
      femaleTotal: const IntJsonConverter().fromJson(json['female_total']),
      femaleSubscribed: const IntJsonConverter().fromJson(
        json['female_subscribed'],
      ),
    );

Map<String, dynamic> _$ActorStatsDtoToJson(ActorStatsDto instance) =>
    <String, dynamic>{
      'female_total': const IntJsonConverter().toJson(instance.femaleTotal),
      'female_subscribed': const IntJsonConverter().toJson(
        instance.femaleSubscribed,
      ),
    };

MovieStatsDto _$MovieStatsDtoFromJson(Map<String, dynamic> json) =>
    MovieStatsDto(
      total: const IntJsonConverter().fromJson(json['total']),
      subscribed: const IntJsonConverter().fromJson(json['subscribed']),
      playable: const IntJsonConverter().fromJson(json['playable']),
    );

Map<String, dynamic> _$MovieStatsDtoToJson(MovieStatsDto instance) =>
    <String, dynamic>{
      'total': const IntJsonConverter().toJson(instance.total),
      'subscribed': const IntJsonConverter().toJson(instance.subscribed),
      'playable': const IntJsonConverter().toJson(instance.playable),
    };

MediaFileStatsDto _$MediaFileStatsDtoFromJson(Map<String, dynamic> json) =>
    MediaFileStatsDto(
      total: const IntJsonConverter().fromJson(json['total']),
      totalSizeBytes: const IntJsonConverter().fromJson(
        json['total_size_bytes'],
      ),
    );

Map<String, dynamic> _$MediaFileStatsDtoToJson(
  MediaFileStatsDto instance,
) => <String, dynamic>{
  'total': const IntJsonConverter().toJson(instance.total),
  'total_size_bytes': const IntJsonConverter().toJson(instance.totalSizeBytes),
};

MediaLibraryStatsDto _$MediaLibraryStatsDtoFromJson(
  Map<String, dynamic> json,
) => MediaLibraryStatsDto(
  total: const IntJsonConverter().fromJson(json['total']),
);

Map<String, dynamic> _$MediaLibraryStatsDtoToJson(
  MediaLibraryStatsDto instance,
) => <String, dynamic>{
  'total': const IntJsonConverter().toJson(instance.total),
};

ThumbnailStatsDto _$ThumbnailStatsDtoFromJson(Map<String, dynamic> json) =>
    ThumbnailStatsDto(
      pendingMedia: const IntJsonConverter().fromJson(json['pending_media']),
      retryWaitMedia: const IntJsonConverter().fromJson(
        json['retry_wait_media'],
      ),
      terminalFailedMedia: const IntJsonConverter().fromJson(
        json['terminal_failed_media'],
      ),
      total: const IntJsonConverter().fromJson(json['total']),
    );

Map<String, dynamic> _$ThumbnailStatsDtoToJson(
  ThumbnailStatsDto instance,
) => <String, dynamic>{
  'pending_media': const IntJsonConverter().toJson(instance.pendingMedia),
  'retry_wait_media': const IntJsonConverter().toJson(instance.retryWaitMedia),
  'terminal_failed_media': const IntJsonConverter().toJson(
    instance.terminalFailedMedia,
  ),
  'total': const IntJsonConverter().toJson(instance.total),
};

ImageSearchEmbeddingServiceStatsDto
_$ImageSearchEmbeddingServiceStatsDtoFromJson(Map<String, dynamic> json) =>
    ImageSearchEmbeddingServiceStatsDto(
      healthy: asBool(json['healthy']),
      endpoint: const NullableStringJsonConverter().fromJson(json['endpoint']),
      spaceId: const NullableStringJsonConverter().fromJson(json['space_id']),
      dimension: const NullableIntJsonConverter().fromJson(json['dimension']),
      modalities: json['modalities'] == null
          ? const <String>[]
          : _trimmedStringList(json['modalities']),
      error: const NullableStringJsonConverter().fromJson(json['error']),
    );

Map<String, dynamic> _$ImageSearchEmbeddingServiceStatsDtoToJson(
  ImageSearchEmbeddingServiceStatsDto instance,
) => <String, dynamic>{
  'healthy': const BoolJsonConverter().toJson(instance.healthy),
  'endpoint': const NullableStringJsonConverter().toJson(instance.endpoint),
  'space_id': const NullableStringJsonConverter().toJson(instance.spaceId),
  'dimension': const NullableIntJsonConverter().toJson(instance.dimension),
  'modalities': const StringListJsonConverter().toJson(instance.modalities),
  'error': const NullableStringJsonConverter().toJson(instance.error),
};

ImageSearchIndexSpaceStatsDto _$ImageSearchIndexSpaceStatsDtoFromJson(
  Map<String, dynamic> json,
) => ImageSearchIndexSpaceStatsDto(
  state: json['state'] == null
      ? 'unknown'
      : const StringJsonConverter().fromJson(json['state']),
  indexedSpaceId: const NullableStringJsonConverter().fromJson(
    json['indexed_space_id'],
  ),
  currentSpaceId: const NullableStringJsonConverter().fromJson(
    json['current_space_id'],
  ),
  isRebuilding: json['is_rebuilding'] == null
      ? false
      : asBool(json['is_rebuilding']),
);

Map<String, dynamic> _$ImageSearchIndexSpaceStatsDtoToJson(
  ImageSearchIndexSpaceStatsDto instance,
) => <String, dynamic>{
  'state': const StringJsonConverter().toJson(instance.state),
  'indexed_space_id': const NullableStringJsonConverter().toJson(
    instance.indexedSpaceId,
  ),
  'current_space_id': const NullableStringJsonConverter().toJson(
    instance.currentSpaceId,
  ),
  'is_rebuilding': const BoolJsonConverter().toJson(instance.isRebuilding),
};

ImageSearchIndexingStatsDto _$ImageSearchIndexingStatsDtoFromJson(
  Map<String, dynamic> json,
) => ImageSearchIndexingStatsDto(
  pendingThumbnails: const IntJsonConverter().fromJson(
    json['pending_thumbnails'],
  ),
  failedThumbnails: const IntJsonConverter().fromJson(
    json['failed_thumbnails'],
  ),
);

Map<String, dynamic> _$ImageSearchIndexingStatsDtoToJson(
  ImageSearchIndexingStatsDto instance,
) => <String, dynamic>{
  'pending_thumbnails': const IntJsonConverter().toJson(
    instance.pendingThumbnails,
  ),
  'failed_thumbnails': const IntJsonConverter().toJson(
    instance.failedThumbnails,
  ),
};

StatusImageSearchDto _$StatusImageSearchDtoFromJson(
  Map<String, dynamic> json,
) => StatusImageSearchDto(
  enabled: json['enabled'] == null
      ? true
      : const BoolJsonConverter().fromJson(json['enabled']),
  healthy: asBool(json['healthy']),
  embeddingService: _embeddingServiceFromJson(json['embedding_service']),
  indexing: _indexingStatsFromJson(json['indexing']),
  indexSpace: _indexSpaceStatsFromJson(json['index_space']),
);

Map<String, dynamic> _$StatusImageSearchDtoToJson(
  StatusImageSearchDto instance,
) => <String, dynamic>{
  'enabled': const BoolJsonConverter().toJson(instance.enabled),
  'healthy': const BoolJsonConverter().toJson(instance.healthy),
  'embedding_service': instance.embeddingService.toJson(),
  'indexing': instance.indexing.toJson(),
  'index_space': instance.indexSpace.toJson(),
};

StatusMetadataProviderTestErrorDto _$StatusMetadataProviderTestErrorDtoFromJson(
  Map<String, dynamic> json,
) => StatusMetadataProviderTestErrorDto(
  type: const StringJsonConverter().fromJson(json['type']),
  message: const StringJsonConverter().fromJson(json['message']),
  method: const NullableStringJsonConverter().fromJson(json['method']),
  url: const NullableStringJsonConverter().fromJson(json['url']),
  resource: const NullableStringJsonConverter().fromJson(json['resource']),
  lookupValue: const NullableStringJsonConverter().fromJson(
    json['lookup_value'],
  ),
);

Map<String, dynamic> _$StatusMetadataProviderTestErrorDtoToJson(
  StatusMetadataProviderTestErrorDto instance,
) => <String, dynamic>{
  'type': const StringJsonConverter().toJson(instance.type),
  'message': const StringJsonConverter().toJson(instance.message),
  'method': const NullableStringJsonConverter().toJson(instance.method),
  'url': const NullableStringJsonConverter().toJson(instance.url),
  'resource': const NullableStringJsonConverter().toJson(instance.resource),
  'lookup_value': const NullableStringJsonConverter().toJson(
    instance.lookupValue,
  ),
};

StatusMetadataProviderTestDto _$StatusMetadataProviderTestDtoFromJson(
  Map<String, dynamic> json,
) => StatusMetadataProviderTestDto(
  healthy: asBool(json['healthy']),
  provider: const StringJsonConverter().fromJson(json['provider']),
  movieNumber: const StringJsonConverter().fromJson(json['movie_number']),
  elapsedMs: const IntJsonConverter().fromJson(json['elapsed_ms']),
  checkedAt: const DateTimeJsonConverter().fromJson(json['checked_at']),
  error: _metadataErrorFromJson(json['error']),
);

Map<String, dynamic> _$StatusMetadataProviderTestDtoToJson(
  StatusMetadataProviderTestDto instance,
) => <String, dynamic>{
  'healthy': const BoolJsonConverter().toJson(instance.healthy),
  'provider': const StringJsonConverter().toJson(instance.provider),
  'movie_number': const StringJsonConverter().toJson(instance.movieNumber),
  'elapsed_ms': const IntJsonConverter().toJson(instance.elapsedMs),
  'checked_at': const DateTimeJsonConverter().toJson(instance.checkedAt),
  'error': instance.error?.toJson(),
};

MediaLibraryUsageDto _$MediaLibraryUsageDtoFromJson(
  Map<String, dynamic> json,
) => MediaLibraryUsageDto(
  libraryId: const IntJsonConverter().fromJson(json['library_id']),
  name: const StringJsonConverter().fromJson(json['name']),
  providerKey: const StringJsonConverter().fromJson(json['provider_key']),
  fileCount: const IntJsonConverter().fromJson(json['file_count']),
  totalSizeBytes: const IntJsonConverter().fromJson(json['total_size_bytes']),
  spaceTotalBytes: const NullableIntJsonConverter().fromJson(
    json['space_total_bytes'],
  ),
  spaceUsedBytes: const NullableIntJsonConverter().fromJson(
    json['space_used_bytes'],
  ),
  spaceFreeBytes: const NullableIntJsonConverter().fromJson(
    json['space_free_bytes'],
  ),
);

Map<String, dynamic> _$MediaLibraryUsageDtoToJson(
  MediaLibraryUsageDto instance,
) => <String, dynamic>{
  'library_id': const IntJsonConverter().toJson(instance.libraryId),
  'name': const StringJsonConverter().toJson(instance.name),
  'provider_key': const StringJsonConverter().toJson(instance.providerKey),
  'file_count': const IntJsonConverter().toJson(instance.fileCount),
  'total_size_bytes': const IntJsonConverter().toJson(instance.totalSizeBytes),
  'space_total_bytes': const NullableIntJsonConverter().toJson(
    instance.spaceTotalBytes,
  ),
  'space_used_bytes': const NullableIntJsonConverter().toJson(
    instance.spaceUsedBytes,
  ),
  'space_free_bytes': const NullableIntJsonConverter().toJson(
    instance.spaceFreeBytes,
  ),
};

CollectionSummaryDto _$CollectionSummaryDtoFromJson(
  Map<String, dynamic> json,
) => CollectionSummaryDto(
  count: json['count'] == null
      ? 0
      : const IntJsonConverter().fromJson(json['count']),
  itemCount: json['item_count'] == null
      ? 0
      : const IntJsonConverter().fromJson(json['item_count']),
);

Map<String, dynamic> _$CollectionSummaryDtoToJson(
  CollectionSummaryDto instance,
) => <String, dynamic>{
  'count': const IntJsonConverter().toJson(instance.count),
  'item_count': const IntJsonConverter().toJson(instance.itemCount),
};

CollectionsStatsDto _$CollectionsStatsDtoFromJson(Map<String, dynamic> json) =>
    CollectionsStatsDto(
      playlists: json['playlists'] == null
          ? const CollectionSummaryDto()
          : _collectionSummaryFromJson(json['playlists']),
      videoCollections: json['video_collections'] == null
          ? const CollectionSummaryDto()
          : _collectionSummaryFromJson(json['video_collections']),
      clipCollections: json['clip_collections'] == null
          ? const CollectionSummaryDto()
          : _collectionSummaryFromJson(json['clip_collections']),
      momentCollections: json['moment_collections'] == null
          ? const CollectionSummaryDto()
          : _collectionSummaryFromJson(json['moment_collections']),
    );

Map<String, dynamic> _$CollectionsStatsDtoToJson(
  CollectionsStatsDto instance,
) => <String, dynamic>{
  'playlists': instance.playlists.toJson(),
  'video_collections': instance.videoCollections.toJson(),
  'clip_collections': instance.clipCollections.toJson(),
  'moment_collections': instance.momentCollections.toJson(),
};

StatusDownloadTaskSummaryDto _$StatusDownloadTaskSummaryDtoFromJson(
  Map<String, dynamic> json,
) => StatusDownloadTaskSummaryDto(
  downloading: json['downloading'] == null
      ? 0
      : const IntJsonConverter().fromJson(json['downloading']),
  importing: json['importing'] == null
      ? 0
      : const IntJsonConverter().fromJson(json['importing']),
  imported: json['imported'] == null
      ? 0
      : const IntJsonConverter().fromJson(json['imported']),
  importFailed: json['import_failed'] == null
      ? 0
      : const IntJsonConverter().fromJson(json['import_failed']),
  skipped: json['skipped'] == null
      ? 0
      : const IntJsonConverter().fromJson(json['skipped']),
  downloadFailed: json['download_failed'] == null
      ? 0
      : const IntJsonConverter().fromJson(json['download_failed']),
  total: json['total'] == null
      ? 0
      : const IntJsonConverter().fromJson(json['total']),
);

Map<String, dynamic> _$StatusDownloadTaskSummaryDtoToJson(
  StatusDownloadTaskSummaryDto instance,
) => <String, dynamic>{
  'downloading': const IntJsonConverter().toJson(instance.downloading),
  'importing': const IntJsonConverter().toJson(instance.importing),
  'imported': const IntJsonConverter().toJson(instance.imported),
  'import_failed': const IntJsonConverter().toJson(instance.importFailed),
  'skipped': const IntJsonConverter().toJson(instance.skipped),
  'download_failed': const IntJsonConverter().toJson(instance.downloadFailed),
  'total': const IntJsonConverter().toJson(instance.total),
};

StatusInsightsDto _$StatusInsightsDtoFromJson(Map<String, dynamic> json) =>
    StatusInsightsDto(
      downloadTasks: json['download_tasks'] == null
          ? const StatusDownloadTaskSummaryDto()
          : _downloadTaskSummaryFromJson(json['download_tasks']),
      mediaLibraries: json['media_libraries'] == null
          ? const <MediaLibraryUsageDto>[]
          : _mediaLibrariesFromJson(json['media_libraries']),
      collections: json['collections'] == null
          ? const CollectionsStatsDto()
          : _collectionsStatsFromJson(json['collections']),
    );

Map<String, dynamic> _$StatusInsightsDtoToJson(
  StatusInsightsDto instance,
) => <String, dynamic>{
  'download_tasks': instance.downloadTasks.toJson(),
  'media_libraries': instance.mediaLibraries.map((e) => e.toJson()).toList(),
  'collections': instance.collections.toJson(),
};

WatchTrendBucketDto _$WatchTrendBucketDtoFromJson(Map<String, dynamic> json) =>
    WatchTrendBucketDto(
      period: const StringJsonConverter().fromJson(json['period']),
      count: const IntJsonConverter().fromJson(json['count']),
    );

Map<String, dynamic> _$WatchTrendBucketDtoToJson(
  WatchTrendBucketDto instance,
) => <String, dynamic>{
  'period': const StringJsonConverter().toJson(instance.period),
  'count': const IntJsonConverter().toJson(instance.count),
};

StatusWatchTrendDto _$StatusWatchTrendDtoFromJson(Map<String, dynamic> json) =>
    StatusWatchTrendDto(
      range: $enumDecode(
        _$WatchTrendRangeEnumMap,
        json['range'],
        unknownValue: WatchTrendRange.last30Days,
      ),
      granularity: json['granularity'] == null
          ? 'day'
          : const StringJsonConverter().fromJson(json['granularity']),
      watchedMovieCount: json['watched_movie_count'] == null
          ? 0
          : const IntJsonConverter().fromJson(json['watched_movie_count']),
      buckets: json['buckets'] == null
          ? const <WatchTrendBucketDto>[]
          : _bucketsFromJson(json['buckets']),
    );

Map<String, dynamic> _$StatusWatchTrendDtoToJson(
  StatusWatchTrendDto instance,
) => <String, dynamic>{
  'range': _$WatchTrendRangeEnumMap[instance.range]!,
  'granularity': const StringJsonConverter().toJson(instance.granularity),
  'watched_movie_count': const IntJsonConverter().toJson(
    instance.watchedMovieCount,
  ),
  'buckets': instance.buckets.map((e) => e.toJson()).toList(),
};

const _$WatchTrendRangeEnumMap = {
  WatchTrendRange.last7Days: '7d',
  WatchTrendRange.last30Days: '30d',
  WatchTrendRange.last90Days: '90d',
  WatchTrendRange.lastYear: '1y',
  WatchTrendRange.all: 'all',
};

StatusDto _$StatusDtoFromJson(Map<String, dynamic> json) => StatusDto(
  backendVersion: const StringJsonConverter().fromJson(json['backend_version']),
  actors: _actorStatsFromJson(json['actors']),
  movies: _movieStatsFromJson(json['movies']),
  mediaFiles: _mediaFileStatsFromJson(json['media_files']),
  mediaLibraries: _mediaLibraryStatsFromJson(json['media_libraries']),
  thumbnails: _thumbnailStatsFromJson(json['thumbnails']),
);

Map<String, dynamic> _$StatusDtoToJson(StatusDto instance) => <String, dynamic>{
  'backend_version': const StringJsonConverter().toJson(
    instance.backendVersion,
  ),
  'actors': instance.actors.toJson(),
  'movies': instance.movies.toJson(),
  'media_files': instance.mediaFiles.toJson(),
  'media_libraries': instance.mediaLibraries.toJson(),
  'thumbnails': instance.thumbnails.toJson(),
};
