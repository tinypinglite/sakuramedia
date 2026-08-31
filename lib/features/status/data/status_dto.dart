import 'package:sakuramedia/core/json/json_parse.dart'
    show asDateTime, asInt, asMap, asMapOrNull, asStringList;

class ActorStatsDto {
  const ActorStatsDto({
    required this.femaleTotal,
    required this.femaleSubscribed,
  });

  final int femaleTotal;
  final int femaleSubscribed;

  factory ActorStatsDto.fromJson(Map<String, dynamic> json) {
    return ActorStatsDto(
      femaleTotal: json['female_total'] as int? ?? 0,
      femaleSubscribed: json['female_subscribed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'female_total': femaleTotal,
      'female_subscribed': femaleSubscribed,
    };
  }
}

class MovieStatsDto {
  const MovieStatsDto({
    required this.total,
    required this.subscribed,
    required this.playable,
  });

  final int total;
  final int subscribed;
  final int playable;

  factory MovieStatsDto.fromJson(Map<String, dynamic> json) {
    return MovieStatsDto(
      total: json['total'] as int? ?? 0,
      subscribed: json['subscribed'] as int? ?? 0,
      playable: json['playable'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'total': total,
      'subscribed': subscribed,
      'playable': playable,
    };
  }
}

class MediaFileStatsDto {
  const MediaFileStatsDto({required this.total, required this.totalSizeBytes});

  final int total;
  final int totalSizeBytes;

  factory MediaFileStatsDto.fromJson(Map<String, dynamic> json) {
    return MediaFileStatsDto(
      total: json['total'] as int? ?? 0,
      totalSizeBytes: json['total_size_bytes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'total': total,
      'total_size_bytes': totalSizeBytes,
    };
  }
}

class MediaLibraryStatsDto {
  const MediaLibraryStatsDto({required this.total});

  final int total;

  factory MediaLibraryStatsDto.fromJson(Map<String, dynamic> json) {
    return MediaLibraryStatsDto(total: json['total'] as int? ?? 0);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'total': total};
  }
}

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

  factory ThumbnailStatsDto.fromJson(Map<String, dynamic> json) {
    return ThumbnailStatsDto(
      pendingMedia: json['pending_media'] as int? ?? 0,
      retryWaitMedia: json['retry_wait_media'] as int? ?? 0,
      terminalFailedMedia: json['terminal_failed_media'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pending_media': pendingMedia,
      'retry_wait_media': retryWaitMedia,
      'terminal_failed_media': terminalFailedMedia,
      'total': total,
    };
  }
}

class ImageSearchEmbeddingServiceStatsDto {
  const ImageSearchEmbeddingServiceStatsDto({
    required this.healthy,
    this.endpoint,
    this.spaceId,
    this.dimension,
    this.modalities = const <String>[],
    this.error,
  });

  final bool healthy;
  final String? endpoint;
  final String? spaceId;
  final int? dimension;
  final List<String> modalities;

  /// 探测失败原因；healthy 为 true 时后端不返回。诊断页要用它给出可定位的文案。
  final String? error;

  factory ImageSearchEmbeddingServiceStatsDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return ImageSearchEmbeddingServiceStatsDto(
      healthy: _asBool(json['healthy']),
      endpoint: json['endpoint'] as String?,
      spaceId: json['space_id'] as String?,
      dimension: (json['dimension'] as num?)?.toInt(),
      modalities: asStringList(json['modalities'], trim: true),
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'healthy': healthy,
      'endpoint': endpoint,
      'space_id': spaceId,
      'dimension': dimension,
      'modalities': modalities,
      'error': error,
    };
  }
}

class ImageSearchIndexSpaceStatsDto {
  const ImageSearchIndexSpaceStatsDto({
    required this.state,
    this.indexedSpaceId,
    this.currentSpaceId,
    this.isRebuilding = false,
  });

  final String state;
  final String? indexedSpaceId;
  final String? currentSpaceId;
  final bool isRebuilding;

  bool get requiresRebuild => state == 'rebuild_required';

  factory ImageSearchIndexSpaceStatsDto.fromJson(Map<String, dynamic> json) {
    return ImageSearchIndexSpaceStatsDto(
      state: json['state'] as String? ?? 'unknown',
      indexedSpaceId: json['indexed_space_id'] as String?,
      currentSpaceId: json['current_space_id'] as String?,
      isRebuilding: _asBool(json['is_rebuilding']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'state': state,
      'indexed_space_id': indexedSpaceId,
      'current_space_id': currentSpaceId,
      'is_rebuilding': isRebuilding,
    };
  }
}

class ImageSearchIndexingStatsDto {
  const ImageSearchIndexingStatsDto({
    required this.pendingThumbnails,
    required this.failedThumbnails,
  });

  final int pendingThumbnails;
  final int failedThumbnails;

  factory ImageSearchIndexingStatsDto.fromJson(Map<String, dynamic> json) {
    return ImageSearchIndexingStatsDto(
      pendingThumbnails: asInt(json['pending_thumbnails']),
      failedThumbnails: asInt(json['failed_thumbnails']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pending_thumbnails': pendingThumbnails,
      'failed_thumbnails': failedThumbnails,
    };
  }
}

class StatusImageSearchDto {
  const StatusImageSearchDto({
    required this.healthy,
    required this.embeddingService,
    required this.indexing,
    required this.indexSpace,
  });

  /// 后端口径是嵌入服务与向量库（Qdrant）的 AND。向量库不单独做诊断项，
  /// 所以这里只透出聚合值，不解析 `image_search_vector_store` 节。
  final bool healthy;
  final ImageSearchEmbeddingServiceStatsDto embeddingService;
  final ImageSearchIndexingStatsDto indexing;
  final ImageSearchIndexSpaceStatsDto indexSpace;

  factory StatusImageSearchDto.fromJson(Map<String, dynamic> json) {
    return StatusImageSearchDto(
      healthy: _asBool(json['healthy']),
      embeddingService: ImageSearchEmbeddingServiceStatsDto.fromJson(
        asMap(json['embedding_service']),
      ),
      indexing: ImageSearchIndexingStatsDto.fromJson(asMap(json['indexing'])),
      indexSpace: ImageSearchIndexSpaceStatsDto.fromJson(
        asMap(json['index_space']),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'healthy': healthy,
      'embedding_service': embeddingService.toJson(),
      'indexing': indexing.toJson(),
      'index_space': indexSpace.toJson(),
    };
  }
}

/// 元数据源探测失败详情。
///
/// [type] 是后端 `StatusService.test_metadata_provider` 定义的**封闭枚举**，
/// 只有三种取值（见 [MetadataProviderErrorType]）；诊断文案必须按它分派，
/// 不要去猜 [message] 里的关键字——JavDB 的 message 是英文异常串，关键字匹配不可靠。
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
  ) {
    return StatusMetadataProviderTestErrorDto(
      type: json['type'] as String? ?? '',
      message: json['message'] as String? ?? '',
      method: json['method'] as String?,
      url: json['url'] as String?,
      resource: json['resource'] as String?,
      lookupValue: json['lookup_value'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'message': message,
      'method': method,
      'url': url,
      'resource': resource,
      'lookup_value': lookupValue,
    };
  }
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

class StatusMetadataProviderTestDto {
  const StatusMetadataProviderTestDto({
    required this.healthy,
    required this.provider,
    required this.movieNumber,
    required this.elapsedMs,
    this.checkedAt,
    this.error,
  });

  final bool healthy;
  final String provider;

  /// 后端写死的探测番号（`StatusService.METADATA_PROVIDER_TEST_MOVIE_NUMBER`），
  /// 失败文案里要带上它，用户才知道"搜不到"说的是哪个番号。
  final String movieNumber;
  final int elapsedMs;
  final DateTime? checkedAt;
  final StatusMetadataProviderTestErrorDto? error;

  factory StatusMetadataProviderTestDto.fromJson(Map<String, dynamic> json) {
    final errorJson = asMapOrNull(json['error']);
    return StatusMetadataProviderTestDto(
      healthy: _asBool(json['healthy']),
      provider: json['provider'] as String? ?? '',
      movieNumber: json['movie_number'] as String? ?? '',
      elapsedMs: asInt(json['elapsed_ms']),
      checkedAt: asDateTime(json['checked_at']),
      error: errorJson == null
          ? null
          : StatusMetadataProviderTestErrorDto.fromJson(errorJson),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'healthy': healthy,
      'provider': provider,
      'movie_number': movieNumber,
      'elapsed_ms': elapsedMs,
      'checked_at': checkedAt?.toIso8601String(),
      'error': error?.toJson(),
    };
  }
}

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
  final ActorStatsDto actors;
  final MovieStatsDto movies;
  final MediaFileStatsDto mediaFiles;
  final MediaLibraryStatsDto mediaLibraries;
  final ThumbnailStatsDto thumbnails;

  factory StatusDto.fromJson(Map<String, dynamic> json) {
    return StatusDto(
      backendVersion: json['backend_version'] as String? ?? '',
      actors: ActorStatsDto.fromJson(asMap(json['actors'])),
      movies: MovieStatsDto.fromJson(asMap(json['movies'])),
      mediaFiles: MediaFileStatsDto.fromJson(asMap(json['media_files'])),
      mediaLibraries: MediaLibraryStatsDto.fromJson(
        asMap(json['media_libraries']),
      ),
      thumbnails: ThumbnailStatsDto.fromJson(asMap(json['thumbnails'])),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'backend_version': backendVersion,
      'actors': actors.toJson(),
      'movies': movies.toJson(),
      'media_files': mediaFiles.toJson(),
      'media_libraries': mediaLibraries.toJson(),
      'thumbnails': thumbnails.toJson(),
    };
  }
}

bool _asBool(dynamic value) {
  return value is bool ? value : false;
}
