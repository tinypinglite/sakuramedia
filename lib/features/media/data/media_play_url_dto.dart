import 'package:sakuramedia/core/json/json_parse.dart';

/// 播放源类型：本地库 / 115 网盘。
enum MoviePlayUrlSource {
  local,
  cloud115;

  String get apiValue => switch (this) {
    MoviePlayUrlSource.local => 'local',
    MoviePlayUrlSource.cloud115 => 'cloud115',
  };
}

/// 播放模式：单个媒体播放 / 多分段合并播放。
enum MoviePlayUrlMode {
  single,
  merged;

  String get apiValue => switch (this) {
    MoviePlayUrlMode.single => 'single',
    MoviePlayUrlMode.merged => 'merged',
  };
}

/// 后端解析出的播放形态，前端据此判断是否可播及占位情况。
enum MoviePlayUrlKind {
  mergedLocal,
  singleLocal,
  singleCloud115,
  cloud115Merged,
  cloud115MergedPending,
  none;

  factory MoviePlayUrlKind.fromApi(String? value) {
    return switch (value?.trim()) {
      'merged_local' => MoviePlayUrlKind.mergedLocal,
      'single_local' => MoviePlayUrlKind.singleLocal,
      'single_cloud115' => MoviePlayUrlKind.singleCloud115,
      'cloud115_merged' => MoviePlayUrlKind.cloud115Merged,
      'cloud115_merged_pending' => MoviePlayUrlKind.cloud115MergedPending,
      _ => MoviePlayUrlKind.none,
    };
  }
}

class MoviePlayUrlSegmentDto {
  const MoviePlayUrlSegmentDto({
    required this.mediaId,
    required this.durationSeconds,
  });

  final int mediaId;
  final int durationSeconds;

  factory MoviePlayUrlSegmentDto.fromJson(Map<String, dynamic> json) {
    return MoviePlayUrlSegmentDto(
      mediaId: asInt(json['media_id']),
      durationSeconds: asInt(json['duration_seconds']),
    );
  }
}

class MoviePlayUrlDto {
  const MoviePlayUrlDto({
    required this.playUrl,
    required this.kind,
    required this.segmentCount,
    required this.segments,
  });

  /// 相对路径的签名播放地址；占位或无媒体时为 `null`。
  final String? playUrl;
  final MoviePlayUrlKind kind;
  final int segmentCount;
  final List<MoviePlayUrlSegmentDto> segments;

  bool get hasPlayableUrl => playUrl?.trim().isNotEmpty ?? false;

  factory MoviePlayUrlDto.fromJson(Map<String, dynamic> json) {
    return MoviePlayUrlDto(
      playUrl: asStringOrNull(json['play_url'], trim: true),
      kind: MoviePlayUrlKind.fromApi(asStringOrNull(json['kind'])),
      segmentCount: asInt(json['segment_count']),
      segments: (json['segments'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(MoviePlayUrlSegmentDto.fromJson)
          .toList(growable: false),
    );
  }
}
