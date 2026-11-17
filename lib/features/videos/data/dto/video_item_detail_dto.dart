import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';

part 'video_item_detail_dto.g.dart';

/// 非 JAV 视频条目的详情资源（`VideoItemDetailResource`）。
///
/// 在列表项字段之上追加 [mediaItems]。其中 `media_items` 后端复用「影片媒体资源」
/// 结构，因此直接复用 [MovieMediaItemDto.fromJson] 解析，不再另立平行 DTO。
@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class VideoItemDetailDto {
  const VideoItemDetailDto({
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
    this.mediaItems = const <MovieMediaItemDto>[],
  });

  final int id;

  final String title;

  final String summary;

  @JsonKey(fromJson: videoImageFromJson)
  final MovieImageDto? coverImage;

  final DateTime? releaseDate;

  /// 时长（秒）/文件大小（字节）：取条目第一条媒体，无媒体时为 0。
  final int durationSeconds;

  final int fileSizeBytes;

  /// 封面像素宽高（= 第一条媒体探测分辨率）。后端探测失败 / 无媒体时为 null。
  final int? coverWidth;

  final int? coverHeight;

  final int mediaCount;

  final bool canPlay;

  /// 该视频归属的全部合集（0..N），后端按合集名升序返回。与列表项共享同一字段。
  @JsonKey(fromJson: videoCollectionRefsFromJson)
  final List<VideoCollectionRef> collections;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  @JsonKey(fromJson: _mediaItemsFromJson)
  final List<MovieMediaItemDto> mediaItems;

  /// 详情标题：只做 trim。空标题的兜底文案在展示层用语言包补
  /// （见 `videoDisplayTitle`），数据层不持有用户可见文案。
  String get preferredTitle => title.trim();

  /// 详情转列表项，便于在列表/合集等位置复用已加载的概要信息。
  VideoItemListItemDto toListItem() {
    return VideoItemListItemDto(
      id: id,
      title: title,
      summary: summary,
      coverImage: coverImage,
      releaseDate: releaseDate,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
      coverWidth: coverWidth,
      coverHeight: coverHeight,
      mediaCount: mediaCount,
      canPlay: canPlay,
      collections: collections,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory VideoItemDetailDto.fromJson(Map<String, dynamic> json) =>
      _$VideoItemDetailDtoFromJson(json);
}

List<MovieMediaItemDto> _mediaItemsFromJson(Object? value) {
  return _listFromJson(value, MovieMediaItemDto.fromJson);
}

List<T> _listFromJson<T>(
  dynamic value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is! List) {
    return <T>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => fromJson(
          item.map(
            (dynamic key, dynamic data) => MapEntry(key.toString(), data),
          ),
        ),
      )
      .toList(growable: false);
}
