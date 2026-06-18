import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

/// 切片关键帧缩略图（后端 `MediaClipThumbnailResource`，`GET /media-clips/{id}/thumbnails`）。
///
/// [offsetSeconds] 是**切片自身时间轴**的相对秒数（= 源缩略图 offset − 切片 start_offset），
/// 与切片从 0 起播的播放进度同基准，可直接用于进度定位 / 高亮。
class MediaClipThumbnailDto {
  const MediaClipThumbnailDto({
    required this.clipId,
    required this.thumbnailId,
    required this.offsetSeconds,
    required this.image,
  });

  final int clipId;
  final int thumbnailId;
  final int offsetSeconds;
  final MovieImageDto image;

  factory MediaClipThumbnailDto.fromJson(Map<String, dynamic> json) {
    return MediaClipThumbnailDto(
      clipId: json['clip_id'] as int? ?? 0,
      thumbnailId: json['thumbnail_id'] as int? ?? 0,
      offsetSeconds: json['offset_seconds'] as int? ?? 0,
      image: MovieImageDto.fromJson(asMap(json['image'])),
    );
  }
}
