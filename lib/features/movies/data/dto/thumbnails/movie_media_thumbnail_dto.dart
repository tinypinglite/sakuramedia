import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';

class MovieMediaThumbnailDto {
  const MovieMediaThumbnailDto({
    required this.thumbnailId,
    required this.mediaId,
    required this.offsetSeconds,
    required this.image,
    this.width,
    this.height,
  });

  final int thumbnailId;
  final int mediaId;
  final int offsetSeconds;
  final MovieImageDto image;

  /// 缩略图像素尺寸 = 所属媒体分辨率（同一 media 的所有帧一致；媒体未探测出分辨率时为 null）。
  /// 瀑布流面板据此预算 tile 高度；为 null 时按 16:9 占位。
  final int? width;
  final int? height;

  factory MovieMediaThumbnailDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaThumbnailDto(
      thumbnailId: json['thumbnail_id'] as int? ?? 0,
      mediaId: json['media_id'] as int? ?? 0,
      offsetSeconds: json['offset_seconds'] as int? ?? 0,
      image: MovieImageDto.fromJson(asMap(json['image'])),
      width: asIntOrNull(json['width']),
      height: asIntOrNull(json['height']),
    );
  }
}
