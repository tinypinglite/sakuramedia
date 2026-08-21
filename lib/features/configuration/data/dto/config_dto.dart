import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';

/// `GET /config` 返回的整包配置快照。
class ConfigResourceDto {
  const ConfigResourceDto({
    required this.media,
    required this.metadata,
    required this.scheduler,
    required this.downloads,
    required this.logging,
  });

  final AdvancedMediaConfigDto media;
  final AdvancedMetadataConfigDto metadata;
  final AdvancedSchedulerConfigDto scheduler;
  final AdvancedDownloadsConfigDto downloads;
  final AdvancedLoggingConfigDto logging;

  factory ConfigResourceDto.fromJson(Map<String, dynamic> json) {
    final values = _objectAt(json, 'values', '/config response');
    return ConfigResourceDto(
      media: AdvancedMediaConfigDto.fromJson(
        _objectAt(values, 'media', '/config values'),
      ),
      metadata: AdvancedMetadataConfigDto.fromJson(
        _objectAt(values, 'metadata', '/config values'),
      ),
      scheduler: AdvancedSchedulerConfigDto.fromJson(
        _objectAt(values, 'scheduler', '/config values'),
      ),
      downloads: AdvancedDownloadsConfigDto.fromJson(
        _objectAt(values, 'downloads', '/config values'),
      ),
      logging: AdvancedLoggingConfigDto.fromJson(
        _objectAt(values, 'logging', '/config values'),
      ),
    );
  }
}

class ConfigUpdateResultDto {
  const ConfigUpdateResultDto({
    required this.values,
    required this.restartRequired,
  });

  final ConfigResourceDto values;
  final List<String> restartRequired;

  factory ConfigUpdateResultDto.fromJson(Map<String, dynamic> json) {
    return ConfigUpdateResultDto(
      values: ConfigResourceDto.fromJson(json),
      restartRequired: List<String>.unmodifiable(
        asStringList(json['restart_required']),
      ),
    );
  }
}

class AdvancedMediaConfigDto {
  const AdvancedMediaConfigDto({
    required this.othersNumberFeatures,
    required this.innerSubTags,
    required this.bluerayTags,
    required this.uncensoredTags,
    required this.uncensoredPrefix,
    required this.allowedMinVideoFileSize,
  });

  final List<String> othersNumberFeatures;
  final List<String> innerSubTags;
  final List<String> bluerayTags;
  final List<String> uncensoredTags;
  final List<String> uncensoredPrefix;
  final int allowedMinVideoFileSize;

  factory AdvancedMediaConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedMediaConfigDto(
      othersNumberFeatures: List<String>.unmodifiable(
        asStringList(json['others_number_features']),
      ),
      innerSubTags: List<String>.unmodifiable(
        asStringList(json['inner_sub_tags']),
      ),
      bluerayTags: List<String>.unmodifiable(
        asStringList(json['blueray_tags']),
      ),
      uncensoredTags: List<String>.unmodifiable(
        asStringList(json['uncensored_tags']),
      ),
      uncensoredPrefix: List<String>.unmodifiable(
        asStringList(json['uncensored_prefix']),
      ),
      allowedMinVideoFileSize: _intAt(json, 'allowed_min_video_file_size'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'others_number_features': othersNumberFeatures,
      'inner_sub_tags': innerSubTags,
      'blueray_tags': bluerayTags,
      'uncensored_tags': uncensoredTags,
      'uncensored_prefix': uncensoredPrefix,
      'allowed_min_video_file_size': allowedMinVideoFileSize,
    };
  }
}

class AdvancedMetadataConfigDto {
  const AdvancedMetadataConfigDto({
    required this.javdbHost,
  });

  final String javdbHost;

  factory AdvancedMetadataConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedMetadataConfigDto(
      javdbHost: _stringAt(json, 'javdb_host'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'javdb_host': javdbHost};
  }
}

class AdvancedSchedulerConfigDto {
  const AdvancedSchedulerConfigDto({required this.crons});

  static const List<String> cronKeys = <String>[
    'actor_subscription_sync',
    'subscribed_movie_auto_download',
    'download_task_sync',
    'download_task_auto_import',
    'download_small_file_cleanup',
    'movie_collection_sync',
    'movie_heat',
    'movie_interaction_sync',
    'hot_review_sync',
    'media_file_scan',
    'media_thumbnail',
    'image_search_index',
    'image_search_optimize',
    'movie_similarity_recompute',
    'moment_recommendation_generate',
    'daily_recommendation_generate',
    'activity_cleanup',
  ];

  final Map<String, String> crons;

  factory AdvancedSchedulerConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedSchedulerConfigDto(
      crons: Map<String, String>.unmodifiable(
        cronKeys.fold<Map<String, String>>(<String, String>{}, (result, key) {
          final cron = asStringOrNull(json['${key}_cron']);
          // 后端删/改某个 cron 时跳过该项，UI 侧 `crons[key] ?? ''` 已能兜住。
          if (cron == null) {
            return result;
          }
          result[key] = cron;
          return result;
        }),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      for (final entry in crons.entries) '${entry.key}_cron': entry.value,
    };
  }
}

class AdvancedDownloadsConfigDto {
  const AdvancedDownloadsConfigDto({
    required this.smallFileCleanupThresholdMb,
    required this.preferredClientKinds,
  });

  final int smallFileCleanupThresholdMb;
  final List<DownloadClientKind> preferredClientKinds;

  factory AdvancedDownloadsConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedDownloadsConfigDto(
      smallFileCleanupThresholdMb: _intAt(
        json,
        'small_file_cleanup_threshold_mb',
      ),
      preferredClientKinds: _preferredClientKinds(json),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'small_file_cleanup_threshold_mb': smallFileCleanupThresholdMb,
      'preferred_client_kinds': preferredClientKinds
          .map((kind) => kind.wireValue)
          .toList(growable: false),
    };
  }
}

List<DownloadClientKind> _preferredClientKinds(Map<String, dynamic> json) {
  const fallback = <DownloadClientKind>[
    DownloadClientKind.qbittorrent,
    DownloadClientKind.cloud115,
  ];
  final value = json['preferred_client_kinds'];
  if (value is! List) {
    return fallback;
  }

  final parsed = <DownloadClientKind>[];
  for (final item in value) {
    final kind = switch (item) {
      'qbittorrent' => DownloadClientKind.qbittorrent,
      'cloud115' => DownloadClientKind.cloud115,
      _ => null,
    };
    if (kind != null && !parsed.contains(kind)) {
      parsed.add(kind);
    }
  }
  for (final kind in fallback) {
    if (!parsed.contains(kind)) {
      parsed.add(kind);
    }
  }
  return List<DownloadClientKind>.unmodifiable(parsed);
}

class AdvancedLoggingConfigDto {
  const AdvancedLoggingConfigDto({required this.level});

  final String level;

  factory AdvancedLoggingConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedLoggingConfigDto(
      level: _stringAt(json, 'level', fallback: 'INFO'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'level': level};
  }
}

Map<String, dynamic> _objectAt(
  Map<String, dynamic> json,
  String key, [
  String path = 'object',
]) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('$path missing "$key" object');
  }
  return Map<String, dynamic>.from(value);
}

String _stringAt(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) {
  return asStringOrNull(json[key]) ?? fallback;
}

int _intAt(Map<String, dynamic> json, String key, {int fallback = 0}) {
  return asInt(json[key], fallback: fallback);
}
