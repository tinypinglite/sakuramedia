import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';

/// `GET /media` 归属划分：`jav` 关联影片番号；`video` 关联 videos 域视频。
enum MediaListItemKind { jav, video, unknown }

extension MediaListItemKindX on MediaListItemKind {
  String get wireValue => switch (this) {
        MediaListItemKind.jav => 'jav',
        MediaListItemKind.video => 'video',
        MediaListItemKind.unknown => 'unknown',
      };

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

/// `GET /media` 中每条 item 的最近一次秒传投影。
///
/// 后端 `null` 表示「从未秒传」或「最近一次已成功（本地视角无需提示）」；
/// 其余值用来在列表上告知「是否值得再点秒传」。未识别的字符串归 [unknown]，
/// UI 侧当作 null 处理（不显示 badge）。
enum LastRapidUploadStatus { notHit, failed, cleanupFailed, inProgress, unknown }

extension LastRapidUploadStatusX on LastRapidUploadStatus {
  String get label => switch (this) {
        LastRapidUploadStatus.notHit => '115中无此文件无法秒传',
        LastRapidUploadStatus.failed => '秒传失败',
        LastRapidUploadStatus.cleanupFailed => '云端已传·待清理',
        LastRapidUploadStatus.inProgress => '秒传中',
        LastRapidUploadStatus.unknown => '未知状态',
      };

  /// null 表示线上返回缺失或显式 null；unknown 表示遇到未知字符串（同样按无状态处理）。
  static LastRapidUploadStatus? fromWire(dynamic value) => switch (value) {
        null => null,
        'not_hit' => LastRapidUploadStatus.notHit,
        'failed' => LastRapidUploadStatus.failed,
        'cleanup_failed' => LastRapidUploadStatus.cleanupFailed,
        'in_progress' => LastRapidUploadStatus.inProgress,
        _ => LastRapidUploadStatus.unknown,
      };
}

/// 批量入口（如「全选本页」）能否安全把该状态的媒体拖进新秒传/删除批次。
///
/// 白名单式默认：仅明确已知安全的状态返回 true，`inProgress` 因 `active_media_id`
/// 唯一约束会 422 必拒；`unknown` 是未识别的后端字符串，保守起见一并拒——避免
/// 后端新增"不可批量"语义时，前端只识别为 unknown 静默混入批次。
///
/// 单次 tap 选中不走这里（用户主动操作，允许自由选，后端兜底校验）。
bool isBulkSelectableRapidUploadStatus(LastRapidUploadStatus? status) {
  return switch (status) {
    null => true,
    LastRapidUploadStatus.notHit => true,
    LastRapidUploadStatus.failed => true,
    LastRapidUploadStatus.cleanupFailed => true,
    LastRapidUploadStatus.inProgress => false,
    LastRapidUploadStatus.unknown => false,
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
    required this.path,
    required this.fileSizeBytes,
    required this.durationSeconds,
    this.resolution,
    required this.specialTags,
    required this.valid,
    this.heat,
    this.lastRapidUploadStatus,
    required this.createdAt,
    required this.updatedAt,
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
  final String path;
  final int fileSizeBytes;
  final int durationSeconds;
  final String? resolution;
  final String specialTags;
  final bool valid;
  final int? heat;
  final LastRapidUploadStatus? lastRapidUploadStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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

  /// 展示用副标题：JAV 用影片标题、视频域回退到路径末段。
  String? get displaySubtitle {
    final rawTitle = title?.trim();
    if (rawTitle != null && rawTitle.isNotEmpty) {
      // JAV 主标题已经是番号；副标题给影片名。视频域主标题就是 title，副标题留给路径。
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
      path: json['path'] as String? ?? '',
      fileSizeBytes: asInt(json['file_size_bytes']),
      durationSeconds: asInt(json['duration_seconds']),
      resolution: asStringOrNull(json['resolution'], trim: true),
      specialTags: json['special_tags'] as String? ?? '',
      valid: json['valid'] as bool? ?? false,
      heat: asIntOrNull(json['heat']),
      lastRapidUploadStatus:
          LastRapidUploadStatusX.fromWire(json['last_rapid_upload_status']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
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
