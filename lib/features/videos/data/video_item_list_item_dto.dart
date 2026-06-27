import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

/// 非 JAV 视频条目的列表项资源（`VideoItemListItemResource`）。
///
/// 与 [MovieListItemDto] 平行，但裁掉番号/订阅等 JAV 专属概念，主键为 [id]。
/// 封面复用影片图片结构 [MovieImageDto]。
class VideoItemListItemDto {
  const VideoItemListItemDto({
    required this.id,
    required this.title,
    this.summary = '',
    this.coverImage,
    this.releaseDate,
    this.durationSeconds = 0,
    this.fileSizeBytes = 0,
    this.coverWidth,
    this.coverHeight,
    required this.mediaCount,
    required this.canPlay,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String summary;
  final MovieImageDto? coverImage;
  final DateTime? releaseDate;

  /// 时长（秒）/文件大小（字节）：取条目第一条媒体，无媒体时为 0。供时长/大小排序与展示。
  final int durationSeconds;
  final int fileSizeBytes;

  /// 封面像素宽高（= 第一条媒体探测分辨率）。瀑布流网格按此真实比例排版，
  /// 缺失时回退 16:9 占位。后端探测失败 / 无媒体时为 null。
  final int? coverWidth;
  final int? coverHeight;
  final int mediaCount;
  final bool canPlay;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get preferredTitle {
    final resolved = title.trim();
    if (resolved.isNotEmpty) {
      return resolved;
    }
    return '未命名视频';
  }

  factory VideoItemListItemDto.fromJson(Map<String, dynamic> json) {
    return VideoItemListItemDto(
      id: _intFromJson(json['id']) ?? 0,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      coverImage: videoImageFromJson(json['cover_image']),
      releaseDate: videoDateFromJson(json['release_date']),
      durationSeconds: _intFromJson(json['duration_seconds']) ?? 0,
      fileSizeBytes: _intFromJson(json['file_size_bytes']) ?? 0,
      coverWidth: _intFromJson(json['cover_width']),
      coverHeight: _intFromJson(json['cover_height']),
      mediaCount: _intFromJson(json['media_count']) ?? 0,
      canPlay: json['can_play'] as bool? ?? false,
      createdAt: videoDateFromJson(json['created_at']),
      updatedAt: videoDateFromJson(json['updated_at']),
    );
  }
}

/// 解析复用影片图片结构的封面/头像字段，容忍 `Map`/`Map<String, dynamic>` 两种形态。
MovieImageDto? videoImageFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MovieImageDto.fromJson(value);
  }
  if (value is Map) {
    return MovieImageDto.fromJson(
      value.map((dynamic key, dynamic data) => MapEntry(key.toString(), data)),
    );
  }
  return null;
}

DateTime? videoDateFromJson(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

int? _intFromJson(dynamic value) {
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
