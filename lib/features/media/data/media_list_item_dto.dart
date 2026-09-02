import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';

/// `GET /media` 归属划分：`jav` 关联影片番号；`video` 关联 videos 域视频。
enum MediaListItemKind { jav, video, unknown }

extension MediaListItemKindX on MediaListItemKind {
  String get label => switch (this) {
    MediaListItemKind.jav => 'JAV 影片',
    MediaListItemKind.video => 'PornBox',
    MediaListItemKind.unknown => '未知归属',
  };

  static MediaListItemKind fromWire(dynamic value) => switch (value) {
    'jav' => MediaListItemKind.jav,
    'video' => MediaListItemKind.video,
    _ => MediaListItemKind.unknown,
  };
}

enum MediaThumbnailGenerationState {
  pending,
  retryWait,
  terminal,
  succeeded,
  unknown,
}

extension MediaThumbnailGenerationStateX on MediaThumbnailGenerationState {
  static MediaThumbnailGenerationState fromWire(dynamic value) =>
      switch (value) {
        'pending' => MediaThumbnailGenerationState.pending,
        'retry_wait' => MediaThumbnailGenerationState.retryWait,
        'terminal' => MediaThumbnailGenerationState.terminal,
        'succeeded' => MediaThumbnailGenerationState.succeeded,
        _ => MediaThumbnailGenerationState.unknown,
      };
}

class MediaListItemDto {
  const MediaListItemDto({
    required this.id,
    required this.kind,
    this.movieNumber,
    this.videoItemId,
    this.title,
    this.coverImage,
    this.thinCoverImage,
    this.libraryId,
    this.libraryName,
    required this.fileName,
    required this.fileSizeBytes,
    required this.durationSeconds,
    this.resolution,
    required this.valid,
    this.heat,
    required this.createdAt,
    required this.updatedAt,
    this.thumbnailGenerationState = MediaThumbnailGenerationState.unknown,
    this.thumbnailLastErrorCode,
    this.collections = const <VideoCollectionRef>[],
  });

  final int id;
  final MediaListItemKind kind;
  final String? movieNumber;
  final int? videoItemId;
  final String? title;
  final MovieImageDto? coverImage;
  final MovieImageDto? thinCoverImage;
  final int? libraryId;
  final String? libraryName;
  final String fileName;
  final int fileSizeBytes;
  final int durationSeconds;
  final String? resolution;
  final bool valid;
  final int? heat;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final MediaThumbnailGenerationState thumbnailGenerationState;
  final String? thumbnailLastErrorCode;
  final List<VideoCollectionRef> collections;

  bool get isJav => kind == MediaListItemKind.jav;
  bool get isVideo => kind == MediaListItemKind.video;

  /// 展示用主标题：优先番号（JAV），否则视频原始标题，最后兜底为「未命名媒体」。
  String get displayHeading {
    final number = movieNumber?.trim();
    if (number != null && number.isNotEmpty) {
      return number;
    }
    final rawTitle = title?.trim();
    if (rawTitle != null && rawTitle.isNotEmpty) {
      return rawTitle;
    }
    return '未命名媒体';
  }

  /// 展示用副标题：JAV 用影片标题，视频域不额外显示副标题。
  String? get displaySubtitle {
    final rawTitle = title?.trim();
    if (rawTitle != null && rawTitle.isNotEmpty) {
      // JAV 主标题已经是番号；副标题给影片名。视频域主标题就是 title。
      if (isJav) {
        return rawTitle;
      }
    }
    return null;
  }

  String? get preferredCoverUrl {
    final thinUrl = thinCoverImage?.bestAvailableUrl.trim();
    if (thinUrl != null && thinUrl.isNotEmpty) {
      return thinUrl;
    }
    final coverUrl = coverImage?.bestAvailableUrl.trim();
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return coverUrl;
    }
    return null;
  }

  bool get usesThinCover {
    final thinUrl = thinCoverImage?.bestAvailableUrl.trim();
    return thinUrl != null && thinUrl.isNotEmpty;
  }

  factory MediaListItemDto.fromJson(Map<String, dynamic> json) {
    return MediaListItemDto(
      id: asInt(json['id']),
      kind: MediaListItemKindX.fromWire(json['kind']),
      movieNumber: asStringOrNull(json['movie_number'], trim: true),
      videoItemId: asIntOrNull(json['video_item_id']),
      title: asStringOrNull(json['title'], trim: true),
      coverImage: _movieImageFromJson(json['cover_image']),
      thinCoverImage: _movieImageFromJson(json['thin_cover_image']),
      libraryId: asIntOrNull(json['library_id']),
      libraryName: asStringOrNull(json['library_name'], trim: true),
      fileName: json['file_name'] as String? ?? '',
      fileSizeBytes: asInt(json['file_size_bytes']),
      durationSeconds: asInt(json['duration_seconds']),
      resolution: asStringOrNull(json['resolution'], trim: true),
      valid: json['valid'] as bool? ?? false,
      heat: asIntOrNull(json['heat']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      thumbnailGenerationState: MediaThumbnailGenerationStateX.fromWire(
        json['thumbnail_generation_state'],
      ),
      thumbnailLastErrorCode: asStringOrNull(
        json['thumbnail_last_error_code'],
        trim: true,
      ),
      collections: videoCollectionRefsFromJson(json['collections']),
    );
  }

  static MovieImageDto? _movieImageFromJson(dynamic value) {
    final map = asMapOrNull(value);
    if (map == null) {
      return null;
    }
    return MovieImageDto.fromJson(map);
  }
}
