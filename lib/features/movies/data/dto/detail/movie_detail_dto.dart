import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';
import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

part 'movie_detail_dto.g.dart';

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieDetailDto with MovieCoverSelection {
  const MovieDetailDto({
    this.id = 0,
    this.metadataSourceName,
    required this.movieNumber,
    required this.title,
    this.seriesId,
    required this.seriesName,
    required this.makerName,
    required this.directorName,
    required this.coverImage,
    required this.releaseDate,
    required this.durationMinutes,
    this.interactionStats,
    this.statsSource,
    this.statsUpdatedAt,
    required this.heat,
    required this.isCollection,
    required this.isSubscribed,
    this.isBlacklisted = false,
    required this.canPlay,
    required this.summary,
    required this.thinCoverImage,
    required this.plotImages,
    required this.actors,
    this.isActorsManuallyManaged = false,
    required this.tags,
    required this.mediaItems,
    this.mergePlaybackCandidates = const <MovieMergePlaybackCandidateDto>[],
    required this.playlists,
    this.favoritePlaylistId,
    this.rankings = const <MovieRankingDto>[],
  });

  /// 后端返回的影片整数主键，可用于与订阅等域数据关联。
  final int id;

  @JsonKey(name: 'metadata_source', fromJson: _metadataSourceNameFromJson)
  final String? metadataSourceName;

  final String movieNumber;
  final String title;
  final int? seriesId;
  final String seriesName;
  final String makerName;
  final String directorName;

  @override
  @JsonKey(fromJson: movieImageFromJson)
  final MovieImageDto? coverImage;

  final DateTime? releaseDate;
  final int durationMinutes;

  /// 插件声明的互动数快照；字段文案由绑定接口的 `stats_fields` 提供。
  @JsonKey(fromJson: _interactionStatsFromJson)
  final Map<String, num>? interactionStats;

  /// 互动数来源：插件 ID 或 `legacy:host`。
  final String? statsSource;
  final DateTime? statsUpdatedAt;
  final int heat;
  final bool isCollection;
  final bool isSubscribed;
  final bool isBlacklisted;
  final bool canPlay;
  final String summary;

  @override
  @JsonKey(fromJson: movieImageFromJson)
  final MovieImageDto? thinCoverImage;

  @JsonKey(fromJson: _plotImagesFromJson)
  final List<MovieImageDto> plotImages;

  @JsonKey(fromJson: _actorsFromJson)
  final List<MovieActorDto> actors;

  /// 演员表被人工编辑后为 true：元数据刷新不会再覆盖演员关联。
  final bool isActorsManuallyManaged;

  @JsonKey(fromJson: _movieTagsFromJson)
  final List<MovieTagDto> tags;

  @JsonKey(fromJson: _mediaItemsFromJson)
  final List<MovieMediaItemDto> mediaItems;

  @JsonKey(fromJson: _mergePlaybackCandidatesFromJson)
  final List<MovieMergePlaybackCandidateDto> mergePlaybackCandidates;

  @JsonKey(fromJson: _playlistsFromJson)
  final List<MoviePlaylistSummaryDto> playlists;

  /// 系统「收藏」播放列表 ID；后端未初始化收藏列表时为 null。
  final int? favoritePlaylistId;

  /// 影片当前在外部榜单上的上榜记录；没有上榜时为空。
  @JsonKey(fromJson: _rankingsFromJson)
  final List<MovieRankingDto> rankings;

  /// DMM 简介与翻译链路已下线，desc/desc_zh 随 API 移除（存量收拢进 [summary]），
  /// 这里保留 getter 只做 trim。
  String get preferredDescription => summary.trim();

  /// DMM 中文标题已收拢进 [title]，保留 getter 只做 trim。
  String get preferredTitle => title.trim();

  factory MovieDetailDto.fromJson(Map<String, dynamic> json) =>
      _$MovieDetailDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieMergePlaybackCandidateDto {
  const MovieMergePlaybackCandidateDto({
    required this.libraryId,
    required this.libraryName,
    required this.providerKey,
    required this.segmentCount,
  });

  final int libraryId;
  final String libraryName;
  final String providerKey;
  final int segmentCount;

  factory MovieMergePlaybackCandidateDto.fromJson(Map<String, dynamic> json) =>
      _$MovieMergePlaybackCandidateDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieMergedPlaybackDto {
  const MovieMergedPlaybackDto({required this.playUrl});

  final String playUrl;

  factory MovieMergedPlaybackDto.fromJson(Map<String, dynamic> json) =>
      _$MovieMergedPlaybackDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MoviePlaylistSummaryDto {
  const MoviePlaylistSummaryDto({
    required this.id,
    required this.name,
    required this.kind,
    required this.isSystem,
  });

  final int id;
  final String name;

  @JsonKey(defaultValue: 'custom')
  final String kind;
  final bool isSystem;

  factory MoviePlaylistSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$MoviePlaylistSummaryDtoFromJson(json);
}

/// 影片的一条上榜记录：来源 · 榜单 · 周期（日/周/月榜、TOP250 子榜或年份）。
@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieRankingDto {
  const MovieRankingDto({
    required this.sourceKey,
    required this.sourceName,
    required this.boardKey,
    required this.boardName,
    required this.period,
    required this.rank,
  });

  final String sourceKey;
  final String sourceName;
  final String boardKey;
  final String boardName;
  final String period;
  final int rank;

  /// 榜单周期文案，按当前语言渲染。
  String periodLabel(AppLocalizations l10n) => rankingPeriodLabel(period, l10n);

  factory MovieRankingDto.fromJson(Map<String, dynamic> json) =>
      _$MovieRankingDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieActorDto {
  const MovieActorDto({
    required this.id,
    required this.name,
    required this.aliasName,
    required this.gender,
    required this.isSubscribed,
    required this.profileImage,
    this.apiDisplayName,
  });

  static const int femaleGender = 1;

  final int id;
  final String name;
  final String aliasName;
  final int gender;
  final bool isSubscribed;

  @JsonKey(fromJson: movieImageFromJson)
  final MovieImageDto? profileImage;

  @JsonKey(name: 'display_name')
  final String? apiDisplayName;
  String get displayName {
    final normalized = apiDisplayName?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    return aliasName.isEmpty ? name : aliasName;
  }

  bool get isFemale => gender == femaleGender;

  factory MovieActorDto.fromJson(Map<String, dynamic> json) =>
      _$MovieActorDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieTagDto {
  const MovieTagDto({required this.tagId, required this.name});

  final int tagId;
  final String name;

  factory MovieTagDto.fromJson(Map<String, dynamic> json) =>
      _$MovieTagDtoFromJson(json);
}

@CopyWith()
class MovieMediaItemDto {
  const MovieMediaItemDto({
    required this.mediaId,
    required this.libraryId,
    required this.providerKey,
    required this.playUrl,
    required this.resolution,
    required this.fileName,
    required this.fileSizeBytes,
    required this.durationSeconds,
    required this.valid,
    required this.progress,
    required this.points,
    this.videoInfo,
    this.tags = const <MediaTagRefDto>[],
    this.isMediaTagsManuallyManaged = false,
  });

  final int mediaId;
  final int? libraryId;
  final String? providerKey;
  final String playUrl;
  final String fileName;
  final String? resolution;
  final int fileSizeBytes;
  final int durationSeconds;
  final bool valid;
  final MovieMediaProgressDto? progress;
  final List<MovieMediaPointDto> points;
  final MovieMediaVideoInfoDto? videoInfo;
  final List<MediaTagRefDto> tags;
  final bool isMediaTagsManuallyManaged;

  bool get hasPlayableUrl => playUrl.trim().isNotEmpty;

  factory MovieMediaItemDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaItemDto(
      mediaId: asInt(json['media_id'] ?? json['id']),
      libraryId: asIntOrNull(json['library_id']),
      providerKey: json['provider_key'] as String?,
      playUrl: json['play_url'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      resolution: json['resolution'] as String?,
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      valid: json['valid'] as bool? ?? true,
      progress: asObjectOrNull(
        json['progress'],
        MovieMediaProgressDto.fromJson,
      ),
      points: asObjectList(json['points'], MovieMediaPointDto.fromJson),
      videoInfo: asObjectOrNull(
        json['video_info'],
        MovieMediaVideoInfoDto.fromJson,
      ),
      tags: mediaTagRefsFromJson(json['tags']),
      isMediaTagsManuallyManaged:
          json['is_media_tags_manually_managed'] as bool? ?? false,
    );
  }

  _$MovieMediaItemDtoCWProxy get copyWith =>
      _$MovieMediaItemDtoCWProxyImpl(this);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieMediaVideoInfoDto {
  const MovieMediaVideoInfoDto({
    required this.container,
    required this.video,
    required this.audio,
    required this.subtitles,
  });

  @JsonKey(fromJson: _containerInfoFromJson)
  final MovieMediaContainerInfoDto? container;

  @JsonKey(fromJson: _videoStreamInfoFromJson)
  final MovieMediaVideoStreamInfoDto? video;

  @JsonKey(fromJson: _audioStreamInfoFromJson)
  final MovieMediaAudioStreamInfoDto? audio;

  @JsonKey(fromJson: _subtitlesFromJson)
  final List<MovieMediaSubtitleInfoDto> subtitles;

  factory MovieMediaVideoInfoDto.fromJson(Map<String, dynamic> json) =>
      _$MovieMediaVideoInfoDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieMediaContainerInfoDto {
  const MovieMediaContainerInfoDto({
    required this.formatName,
    required this.durationSeconds,
    required this.bitRate,
    required this.sizeBytes,
  });

  final String formatName;
  final int? durationSeconds;
  final int? bitRate;
  final int? sizeBytes;

  factory MovieMediaContainerInfoDto.fromJson(Map<String, dynamic> json) =>
      _$MovieMediaContainerInfoDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieMediaVideoStreamInfoDto {
  const MovieMediaVideoStreamInfoDto({
    required this.codecName,
    required this.codecLongName,
    required this.profile,
    required this.bitRate,
    required this.width,
    required this.height,
    required this.frameRate,
    required this.pixelFormat,
  });

  final String codecName;
  final String codecLongName;
  final String? profile;
  final int? bitRate;
  final int? width;
  final int? height;
  final double? frameRate;
  final String pixelFormat;

  factory MovieMediaVideoStreamInfoDto.fromJson(Map<String, dynamic> json) =>
      _$MovieMediaVideoStreamInfoDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieMediaAudioStreamInfoDto {
  const MovieMediaAudioStreamInfoDto({
    required this.codecName,
    required this.codecLongName,
    required this.profile,
    required this.bitRate,
    required this.sampleRate,
    required this.channels,
    required this.channelLayout,
  });

  final String codecName;
  final String codecLongName;
  final String? profile;
  final int? bitRate;
  final int? sampleRate;
  final int? channels;
  final String channelLayout;

  factory MovieMediaAudioStreamInfoDto.fromJson(Map<String, dynamic> json) =>
      _$MovieMediaAudioStreamInfoDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieMediaSubtitleInfoDto {
  const MovieMediaSubtitleInfoDto({
    required this.codecName,
    required this.codecLongName,
    required this.language,
    required this.title,
  });

  final String codecName;
  final String codecLongName;
  final String language;
  final String title;

  factory MovieMediaSubtitleInfoDto.fromJson(Map<String, dynamic> json) =>
      _$MovieMediaSubtitleInfoDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieMediaProgressDto {
  const MovieMediaProgressDto({
    required this.lastPositionSeconds,
    required this.lastWatchedAt,
  });

  final int lastPositionSeconds;
  final DateTime? lastWatchedAt;

  factory MovieMediaProgressDto.fromJson(Map<String, dynamic> json) =>
      _$MovieMediaProgressDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class MovieMediaPointDto {
  const MovieMediaPointDto({
    required this.pointId,
    required this.thumbnailId,
    required this.offsetSeconds,
    required this.image,
  });

  final int pointId;
  final int thumbnailId;
  final int offsetSeconds;

  @JsonKey(fromJson: movieImageFromJson)
  final MovieImageDto? image;

  factory MovieMediaPointDto.fromJson(Map<String, dynamic> json) =>
      _$MovieMediaPointDtoFromJson(json);
}

String? _metadataSourceNameFromJson(Object? value) =>
    asMapOrNull(value)?['display_name'] as String?;

Map<String, num>? _interactionStatsFromJson(Object? value) {
  final map = asMapOrNull(value);
  if (map == null) {
    return null;
  }
  final result = <String, num>{};
  map.forEach((key, data) {
    if (data is num) {
      result[key.toString()] = data;
    }
  });
  return result.isEmpty ? null : Map<String, num>.unmodifiable(result);
}

List<MovieImageDto> _plotImagesFromJson(Object? value) =>
    asObjectList(value, MovieImageDto.fromJson);

List<MovieActorDto> _actorsFromJson(Object? value) =>
    asObjectList(value, MovieActorDto.fromJson);

List<MovieTagDto> _movieTagsFromJson(Object? value) =>
    asObjectList(value, MovieTagDto.fromJson);

List<MovieMediaItemDto> _mediaItemsFromJson(Object? value) =>
    asObjectList(value, MovieMediaItemDto.fromJson);

List<MovieMergePlaybackCandidateDto> _mergePlaybackCandidatesFromJson(
  Object? value,
) => asObjectList(value, MovieMergePlaybackCandidateDto.fromJson);

List<MoviePlaylistSummaryDto> _playlistsFromJson(Object? value) =>
    asObjectList(value, MoviePlaylistSummaryDto.fromJson);

List<MovieRankingDto> _rankingsFromJson(Object? value) =>
    asObjectList(value, MovieRankingDto.fromJson);

MovieMediaContainerInfoDto? _containerInfoFromJson(Object? value) =>
    asObjectOrNull(value, MovieMediaContainerInfoDto.fromJson);

MovieMediaVideoStreamInfoDto? _videoStreamInfoFromJson(Object? value) =>
    asObjectOrNull(value, MovieMediaVideoStreamInfoDto.fromJson);

MovieMediaAudioStreamInfoDto? _audioStreamInfoFromJson(Object? value) =>
    asObjectOrNull(value, MovieMediaAudioStreamInfoDto.fromJson);

List<MovieMediaSubtitleInfoDto> _subtitlesFromJson(Object? value) =>
    asObjectList(value, MovieMediaSubtitleInfoDto.fromJson);
