import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';
import 'package:sakuramedia/core/json/json_parse.dart'
    show asBool, asObject, asObjectList, asObjectOrNull, asStringList;

part 'status_dto.g.dart';

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class ActorStatsDto {
  const ActorStatsDto({
    required this.femaleTotal,
    required this.femaleSubscribed,
  });

  final int femaleTotal;
  final int femaleSubscribed;

  factory ActorStatsDto.fromJson(Map<String, dynamic> json) =>
      _$ActorStatsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ActorStatsDtoToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class MovieStatsDto {
  const MovieStatsDto({
    required this.total,
    required this.subscribed,
    required this.playable,
  });

  final int total;
  final int subscribed;
  final int playable;

  factory MovieStatsDto.fromJson(Map<String, dynamic> json) =>
      _$MovieStatsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$MovieStatsDtoToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class MediaFileStatsDto {
  const MediaFileStatsDto({required this.total, required this.totalSizeBytes});

  final int total;
  final int totalSizeBytes;

  factory MediaFileStatsDto.fromJson(Map<String, dynamic> json) =>
      _$MediaFileStatsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$MediaFileStatsDtoToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class MediaLibraryStatsDto {
  const MediaLibraryStatsDto({required this.total});

  final int total;

  factory MediaLibraryStatsDto.fromJson(Map<String, dynamic> json) =>
      _$MediaLibraryStatsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$MediaLibraryStatsDtoToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class ThumbnailStatsDto {
  const ThumbnailStatsDto({
    required this.pendingMedia,
    required this.retryWaitMedia,
    required this.terminalFailedMedia,
    required this.total,
  });

  final int pendingMedia;
  final int retryWaitMedia;
  final int terminalFailedMedia;
  final int total;

  factory ThumbnailStatsDto.fromJson(Map<String, dynamic> json) =>
      _$ThumbnailStatsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ThumbnailStatsDtoToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class ImageSearchEmbeddingServiceStatsDto {
  const ImageSearchEmbeddingServiceStatsDto({
    required this.healthy,
    this.endpoint,
    this.spaceId,
    this.dimension,
    this.modalities = const <String>[],
    this.error,
  });

  @JsonKey(fromJson: asBool)
  final bool healthy;
  final String? endpoint;
  final String? spaceId;
  final int? dimension;

  @JsonKey(fromJson: _trimmedStringList)
  final List<String> modalities;

  /// 探测失败原因；healthy 为 true 时后端不返回。诊断页要用它给出可定位的文案。
  final String? error;

  factory ImageSearchEmbeddingServiceStatsDto.fromJson(
    Map<String, dynamic> json,
  ) => _$ImageSearchEmbeddingServiceStatsDtoFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ImageSearchEmbeddingServiceStatsDtoToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class ImageSearchIndexSpaceStatsDto {
  const ImageSearchIndexSpaceStatsDto({
    required this.state,
    this.indexedSpaceId,
    this.currentSpaceId,
    this.isRebuilding = false,
  });

  @JsonKey(defaultValue: 'unknown')
  final String state;
  final String? indexedSpaceId;
  final String? currentSpaceId;

  @JsonKey(fromJson: asBool)
  final bool isRebuilding;

  bool get requiresRebuild => state == 'rebuild_required';

  factory ImageSearchIndexSpaceStatsDto.fromJson(Map<String, dynamic> json) =>
      _$ImageSearchIndexSpaceStatsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ImageSearchIndexSpaceStatsDtoToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class ImageSearchIndexingStatsDto {
  const ImageSearchIndexingStatsDto({
    required this.pendingThumbnails,
    required this.failedThumbnails,
  });

  final int pendingThumbnails;
  final int failedThumbnails;

  factory ImageSearchIndexingStatsDto.fromJson(Map<String, dynamic> json) =>
      _$ImageSearchIndexingStatsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ImageSearchIndexingStatsDtoToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class StatusImageSearchDto {
  const StatusImageSearchDto({
    this.enabled = true,
    required this.healthy,
    required this.embeddingService,
    required this.indexing,
    required this.indexSpace,
  });

  @JsonKey(defaultValue: true)
  final bool enabled;

  /// 后端口径是嵌入服务与向量库（Qdrant）的 AND。向量库不单独做诊断项，
  /// 所以这里只透出聚合值，不解析 `image_search_vector_store` 节。
  @JsonKey(fromJson: asBool)
  final bool healthy;

  @JsonKey(fromJson: _embeddingServiceFromJson)
  final ImageSearchEmbeddingServiceStatsDto embeddingService;

  @JsonKey(fromJson: _indexingStatsFromJson)
  final ImageSearchIndexingStatsDto indexing;

  @JsonKey(fromJson: _indexSpaceStatsFromJson)
  final ImageSearchIndexSpaceStatsDto indexSpace;

  factory StatusImageSearchDto.fromJson(Map<String, dynamic> json) =>
      _$StatusImageSearchDtoFromJson(json);

  Map<String, dynamic> toJson() => _$StatusImageSearchDtoToJson(this);
}

/// 元数据源探测失败详情。
///
/// [type] 是后端 `StatusService.test_metadata_provider` 定义的**封闭枚举**，
/// 只有三种取值（见 [MetadataProviderErrorType]）；诊断文案必须按它分派，
/// 不要去猜 [message] 里的关键字——JavDB 的 message 是英文异常串，关键字匹配不可靠。
@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class StatusMetadataProviderTestErrorDto {
  const StatusMetadataProviderTestErrorDto({
    required this.type,
    required this.message,
    this.method,
    this.url,
    this.resource,
    this.lookupValue,
  });

  final String type;
  final String message;

  /// 仅 `metadata_request_error` 带：失败请求的方法与 URL。
  final String? method;
  final String? url;

  /// 仅 `metadata_not_found` 带：找不到的资源类型（javdb=`movie`）与查询值（探测番号）。
  final String? resource;
  final String? lookupValue;

  factory StatusMetadataProviderTestErrorDto.fromJson(
    Map<String, dynamic> json,
  ) => _$StatusMetadataProviderTestErrorDtoFromJson(json);

  Map<String, dynamic> toJson() =>
      _$StatusMetadataProviderTestErrorDtoToJson(this);
}

/// 后端 `StatusMetadataProviderTestError.type` 的全部取值。
abstract final class MetadataProviderErrorType {
  /// 站点可访问，但按探测番号搜不到 / 解析不出目标内容。
  static const String notFound = 'metadata_not_found';

  /// HTTP 层失败（重试耗尽）：不可达、超时、非 2xx。
  static const String requestError = 'metadata_request_error';

  /// 其它未归类异常，含 JavDB 登录失败（后端未单独 catch `JavdbAuthError`）。
  static const String unexpected = 'unexpected_error';
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class StatusMetadataProviderTestDto {
  const StatusMetadataProviderTestDto({
    required this.healthy,
    required this.provider,
    required this.movieNumber,
    required this.elapsedMs,
    this.checkedAt,
    this.error,
  });

  @JsonKey(fromJson: asBool)
  final bool healthy;
  final String provider;

  /// 后端写死的探测番号（`StatusService.METADATA_PROVIDER_TEST_MOVIE_NUMBER`），
  /// 失败文案里要带上它，用户才知道"搜不到"说的是哪个番号。
  final String movieNumber;
  final int elapsedMs;
  final DateTime? checkedAt;

  @JsonKey(fromJson: _metadataErrorFromJson)
  final StatusMetadataProviderTestErrorDto? error;

  factory StatusMetadataProviderTestDto.fromJson(Map<String, dynamic> json) =>
      _$StatusMetadataProviderTestDtoFromJson(json);

  Map<String, dynamic> toJson() => _$StatusMetadataProviderTestDtoToJson(this);
}

/// 单个媒体库的用量；各库 [fileCount] 之和恒等于全局媒体文件总数。
@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class MediaLibraryUsageDto {
  const MediaLibraryUsageDto({
    required this.libraryId,
    required this.name,
    required this.providerKey,
    required this.fileCount,
    required this.totalSizeBytes,
    this.spaceTotalBytes,
    this.spaceUsedBytes,
    this.spaceFreeBytes,
  });

  final int libraryId;
  final String name;
  final String providerKey;
  final int fileCount;

  /// 本库 SakuraMedia 媒体文件合计大小；含失效媒体。
  final int totalSizeBytes;

  /// provider 上报的存储端容量；null 表示提供方不支持或查询失败。
  final int? spaceTotalBytes;
  final int? spaceUsedBytes;
  final int? spaceFreeBytes;

  factory MediaLibraryUsageDto.fromJson(Map<String, dynamic> json) =>
      _$MediaLibraryUsageDtoFromJson(json);

  Map<String, dynamic> toJson() => _$MediaLibraryUsageDtoToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class CollectionSummaryDto {
  const CollectionSummaryDto({this.count = 0, this.itemCount = 0});

  final int count;
  final int itemCount;

  factory CollectionSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$CollectionSummaryDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CollectionSummaryDtoToJson(this);
}

/// 用户创建的合集资产统计；`playlists` 不含系统「最近播放」列表。
@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class CollectionsStatsDto {
  const CollectionsStatsDto({
    this.playlists = const CollectionSummaryDto(),
    this.videoCollections = const CollectionSummaryDto(),
    this.clipCollections = const CollectionSummaryDto(),
    this.momentCollections = const CollectionSummaryDto(),
  });

  @JsonKey(fromJson: _collectionSummaryFromJson)
  final CollectionSummaryDto playlists;

  @JsonKey(fromJson: _collectionSummaryFromJson)
  final CollectionSummaryDto videoCollections;

  @JsonKey(fromJson: _collectionSummaryFromJson)
  final CollectionSummaryDto clipCollections;

  @JsonKey(fromJson: _collectionSummaryFromJson)
  final CollectionSummaryDto momentCollections;

  bool get isEmpty =>
      playlists.count == 0 &&
      videoCollections.count == 0 &&
      clipCollections.count == 0 &&
      momentCollections.count == 0;

  factory CollectionsStatsDto.fromJson(Map<String, dynamic> json) =>
      _$CollectionsStatsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CollectionsStatsDtoToJson(this);
}

/// 下载任务状态分布（当前任务快照，非历史累计）。
///
/// 六类互斥，合计恒等于 [total]；概览工作台只消费进行中与已导入的数量。
@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class StatusDownloadTaskSummaryDto {
  const StatusDownloadTaskSummaryDto({
    this.downloading = 0,
    this.importing = 0,
    this.imported = 0,
    this.importFailed = 0,
    this.skipped = 0,
    this.downloadFailed = 0,
    this.total = 0,
  });

  final int downloading;
  final int importing;
  final int imported;
  final int importFailed;
  final int skipped;
  final int downloadFailed;
  final int total;

  factory StatusDownloadTaskSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$StatusDownloadTaskSummaryDtoFromJson(json);

  Map<String, dynamic> toJson() => _$StatusDownloadTaskSummaryDtoToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class StatusInsightsDto {
  const StatusInsightsDto({
    this.downloadTasks = const StatusDownloadTaskSummaryDto(),
    this.mediaLibraries = const <MediaLibraryUsageDto>[],
    this.collections = const CollectionsStatsDto(),
  });

  @JsonKey(fromJson: _downloadTaskSummaryFromJson)
  final StatusDownloadTaskSummaryDto downloadTasks;

  @JsonKey(fromJson: _mediaLibrariesFromJson)
  final List<MediaLibraryUsageDto> mediaLibraries;

  @JsonKey(fromJson: _collectionsStatsFromJson)
  final CollectionsStatsDto collections;

  factory StatusInsightsDto.fromJson(Map<String, dynamic> json) =>
      _$StatusInsightsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$StatusInsightsDtoToJson(this);
}

/// 观看趋势时间窗口；粒度由后端随窗口推导（7d/30d/90d 按天，1y/all 按月）。
enum WatchTrendRange {
  @JsonValue('7d')
  last7Days('7d'),
  @JsonValue('30d')
  last30Days('30d'),
  @JsonValue('90d')
  last90Days('90d'),
  @JsonValue('1y')
  lastYear('1y'),
  @JsonValue('all')
  all('all');

  const WatchTrendRange(this.apiValue);

  final String apiValue;
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class WatchTrendBucketDto {
  const WatchTrendBucketDto({required this.period, required this.count});

  /// 天粒度 `YYYY-MM-DD`；月粒度 `YYYY-MM`。
  final String period;
  final int count;

  factory WatchTrendBucketDto.fromJson(Map<String, dynamic> json) =>
      _$WatchTrendBucketDtoFromJson(json);

  Map<String, dynamic> toJson() => _$WatchTrendBucketDtoToJson(this);
}

/// 观看趋势。
///
/// 数据源是「每个媒体最后一次观看时间」的分布，不是完整观看历史——
/// 更早的记录已被覆盖，文案不要写成「观看历史」。
@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class StatusWatchTrendDto {
  const StatusWatchTrendDto({
    required this.range,
    required this.granularity,
    this.watchedMovieCount = 0,
    this.buckets = const <WatchTrendBucketDto>[],
  });

  @JsonKey(unknownEnumValue: WatchTrendRange.last30Days)
  final WatchTrendRange range;

  /// `day` 或 `month`。
  @JsonKey(defaultValue: 'day')
  final String granularity;
  final int watchedMovieCount;

  @JsonKey(fromJson: _bucketsFromJson)
  final List<WatchTrendBucketDto> buckets;

  factory StatusWatchTrendDto.fromJson(Map<String, dynamic> json) =>
      _$StatusWatchTrendDtoFromJson(json);

  Map<String, dynamic> toJson() => _$StatusWatchTrendDtoToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class StatusDto {
  const StatusDto({
    required this.backendVersion,
    required this.actors,
    required this.movies,
    required this.mediaFiles,
    required this.mediaLibraries,
    required this.thumbnails,
  });

  final String backendVersion;

  @JsonKey(fromJson: _actorStatsFromJson)
  final ActorStatsDto actors;

  @JsonKey(fromJson: _movieStatsFromJson)
  final MovieStatsDto movies;

  @JsonKey(fromJson: _mediaFileStatsFromJson)
  final MediaFileStatsDto mediaFiles;

  @JsonKey(fromJson: _mediaLibraryStatsFromJson)
  final MediaLibraryStatsDto mediaLibraries;

  @JsonKey(fromJson: _thumbnailStatsFromJson)
  final ThumbnailStatsDto thumbnails;

  factory StatusDto.fromJson(Map<String, dynamic> json) =>
      _$StatusDtoFromJson(json);

  Map<String, dynamic> toJson() => _$StatusDtoToJson(this);
}

List<String> _trimmedStringList(Object? value) =>
    asStringList(value, trim: true);

ImageSearchEmbeddingServiceStatsDto _embeddingServiceFromJson(Object? value) =>
    asObject(value, ImageSearchEmbeddingServiceStatsDto.fromJson);

ImageSearchIndexingStatsDto _indexingStatsFromJson(Object? value) =>
    asObject(value, ImageSearchIndexingStatsDto.fromJson);

ImageSearchIndexSpaceStatsDto _indexSpaceStatsFromJson(Object? value) =>
    asObject(value, ImageSearchIndexSpaceStatsDto.fromJson);

StatusMetadataProviderTestErrorDto? _metadataErrorFromJson(Object? value) =>
    asObjectOrNull(value, StatusMetadataProviderTestErrorDto.fromJson);

CollectionSummaryDto _collectionSummaryFromJson(Object? value) =>
    asObject(value, CollectionSummaryDto.fromJson);

StatusDownloadTaskSummaryDto _downloadTaskSummaryFromJson(Object? value) =>
    asObject(value, StatusDownloadTaskSummaryDto.fromJson);

List<MediaLibraryUsageDto> _mediaLibrariesFromJson(Object? value) =>
    asObjectList(value, MediaLibraryUsageDto.fromJson);

CollectionsStatsDto _collectionsStatsFromJson(Object? value) =>
    asObject(value, CollectionsStatsDto.fromJson);

List<WatchTrendBucketDto> _bucketsFromJson(Object? value) =>
    asObjectList(value, WatchTrendBucketDto.fromJson);

ActorStatsDto _actorStatsFromJson(Object? value) =>
    asObject(value, ActorStatsDto.fromJson);

MovieStatsDto _movieStatsFromJson(Object? value) =>
    asObject(value, MovieStatsDto.fromJson);

MediaFileStatsDto _mediaFileStatsFromJson(Object? value) =>
    asObject(value, MediaFileStatsDto.fromJson);

MediaLibraryStatsDto _mediaLibraryStatsFromJson(Object? value) =>
    asObject(value, MediaLibraryStatsDto.fromJson);

ThumbnailStatsDto _thumbnailStatsFromJson(Object? value) =>
    asObject(value, ThumbnailStatsDto.fromJson);
