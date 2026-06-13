import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

/// 视频切片资源（后端 `MediaClipResource`）。
///
/// 切片是用户在某个媒体上圈选缩略图区间后切出的独立 mp4：
/// - `mediaId`：来源媒体；来源被删除后为 `null`，切片仍可播放。
/// - `streamUrl`：内联签名串流地址（相对路径），播放前用 `resolveMediaUrl` 拼 baseUrl。
class MediaClipDto {
  const MediaClipDto({
    required this.clipId,
    required this.mediaId,
    required this.movieNumber,
    required this.startOffsetSeconds,
    required this.endOffsetSeconds,
    required this.title,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.coverImage,
    required this.streamUrl,
    required this.createdAt,
    this.previewFrames = const <MovieImageDto>[],
    this.collections = const <ClipCollectionSummaryDto>[],
  });

  final int clipId;
  final int? mediaId;
  final String? movieNumber;
  final int startOffsetSeconds;
  final int endOffsetSeconds;
  final String title;
  final int durationSeconds;
  final int fileSizeBytes;
  final MovieImageDto? coverImage;
  final String streamUrl;
  final DateTime? createdAt;

  /// 区间内的逐帧缩略图，仅切片详情接口返回，用于悬停轮播预览；列表接口为空。
  final List<MovieImageDto> previewFrames;

  /// 该切片所属的合集摘要，仅切片详情接口返回；列表接口为空。
  final List<ClipCollectionSummaryDto> collections;

  factory MediaClipDto.fromJson(Map<String, dynamic> json) {
    return MediaClipDto(
      clipId: json['clip_id'] as int? ?? 0,
      mediaId: _intFromJson(json['media_id']),
      movieNumber: _stringOrNull(json['movie_number']),
      startOffsetSeconds: json['start_offset_seconds'] as int? ?? 0,
      endOffsetSeconds: json['end_offset_seconds'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      coverImage: _movieImageFromJson(json['cover_image']),
      streamUrl: json['stream_url'] as String? ?? '',
      createdAt: _dateTimeFromJson(json['created_at']),
      previewFrames: _imageListFromJson(json['preview_frames']),
      collections: _collectionsFromJson(json['collections']),
    );
  }

  static int? _intFromJson(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String? _stringOrNull(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static MovieImageDto? _movieImageFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return MovieImageDto.fromJson(value);
    }
    if (value is Map) {
      return MovieImageDto.fromJson(
        value.map(
          (dynamic key, dynamic data) => MapEntry(key.toString(), data),
        ),
      );
    }
    return null;
  }

  static List<MovieImageDto> _imageListFromJson(dynamic value) {
    if (value is! List) {
      return const <MovieImageDto>[];
    }
    return value
        .map(_movieImageFromJson)
        .whereType<MovieImageDto>()
        .toList(growable: false);
  }

  static List<ClipCollectionSummaryDto> _collectionsFromJson(dynamic value) {
    if (value is! List) {
      return const <ClipCollectionSummaryDto>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => ClipCollectionSummaryDto.fromJson(
            item.map(
              (dynamic key, dynamic data) => MapEntry(key.toString(), data),
            ),
          ),
        )
        .toList(growable: false);
  }
}

/// 切片所属合集的轻量摘要（后端 `ClipCollectionSummary`），用于「加入合集」选择器回显。
class ClipCollectionSummaryDto {
  const ClipCollectionSummaryDto({required this.id, required this.name});

  final int id;
  final String name;

  factory ClipCollectionSummaryDto.fromJson(Map<String, dynamic> json) {
    return ClipCollectionSummaryDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}
