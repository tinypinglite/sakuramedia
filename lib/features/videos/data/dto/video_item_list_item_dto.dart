import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';
import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';

part 'video_item_list_item_dto.g.dart';

/// 视频归属合集的精简引用（后端 `VideoCollectionRef`）：仅承载 [id]/[name]
/// 用于列表/详情侧显式展示"所属合集"，避免复用 [VideoCollectionDto] 时把
/// item_count / cover_image 等无关字段带过来（后端也不下发这些）。
@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class VideoCollectionRef {
  const VideoCollectionRef({required this.id, required this.name});

  final int id;
  final String name;

  factory VideoCollectionRef.fromJson(Map<String, dynamic> json) =>
      _$VideoCollectionRefFromJson(json);
}

/// 解析后端 `collections` 字段：非 List / 空列表 → `const []`；元素非 Map 或 id ≤ 0 时跳过。
List<VideoCollectionRef> videoCollectionRefsFromJson(dynamic value) {
  if (value is! List || value.isEmpty) {
    return const <VideoCollectionRef>[];
  }
  final result = <VideoCollectionRef>[];
  for (final entry in value) {
    final map = asMapOrNull(entry);
    if (map == null) {
      continue;
    }
    final ref = VideoCollectionRef.fromJson(map);
    if (ref.id <= 0) {
      continue;
    }
    result.add(ref);
  }
  return result;
}

/// 非 JAV 视频条目的列表项资源（`VideoItemListItemResource`）。
///
/// 与 [MovieListItemDto] 平行，但裁掉番号/订阅等 JAV 专属概念，主键为 [id]。
/// 封面复用影片图片结构 [MovieImageDto]。
@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
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
    this.collections = const <VideoCollectionRef>[],
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String summary;

  @JsonKey(fromJson: videoImageFromJson)
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

  /// 该视频归属的全部合集（0..N），后端按合集名升序返回。列表/详情共享。
  @JsonKey(fromJson: videoCollectionRefsFromJson)
  final List<VideoCollectionRef> collections;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 列表项标题：只做 trim。空标题的兜底文案在展示层用语言包补
  /// （见 `videoDisplayTitle`），数据层不持有用户可见文案。
  String get preferredTitle => title.trim();

  factory VideoItemListItemDto.fromJson(Map<String, dynamic> json) =>
      _$VideoItemListItemDtoFromJson(json);
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
