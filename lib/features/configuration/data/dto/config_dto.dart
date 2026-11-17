import 'package:sakuramedia/core/json/json_parse.dart';

/// `GET /config` 返回的整包配置快照。
class ConfigResourceDto {
  const ConfigResourceDto({
    this.optionalServices,
    required this.media,
    required this.scheduler,
    required this.downloads,
    required this.logging,
  });

  final OptionalServicesConfigDto? optionalServices;
  final AdvancedMediaConfigDto media;
  final AdvancedSchedulerConfigDto scheduler;
  final AdvancedDownloadsConfigDto downloads;
  final AdvancedLoggingConfigDto logging;

  factory ConfigResourceDto.fromJson(Map<String, dynamic> json) {
    final values = _objectAt(json, 'values', '/config response');
    return ConfigResourceDto(
      optionalServices: OptionalServicesConfigDto.fromJsonOrNull(values),
      media: AdvancedMediaConfigDto.fromJson(
        _objectAt(values, 'media', '/config values'),
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
  const AdvancedMediaConfigDto({required this.allowedMinVideoFileSize});

  final int allowedMinVideoFileSize;

  factory AdvancedMediaConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedMediaConfigDto(
      allowedMinVideoFileSize: _intAt(json, 'allowed_min_video_file_size'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'allowed_min_video_file_size': allowedMinVideoFileSize,
    };
  }
}

class AdvancedSchedulerConfigDto {
  const AdvancedSchedulerConfigDto({
    required this.crons,
    required this.workerDefaultConcurrency,
  });

  static const List<String> cronKeys = <String>[
    'actor_subscription_sync',
    'subscribed_movie_auto_download',
    'download_task_sync',
    'download_task_auto_import',
    'movie_stats_sync',
    'media_file_hash_backfill',
    'media_file_scan',
    'media_thumbnail',
    'image_search_index',
    'movie_similarity_recompute',
    'moment_recommendation_generate',
    'daily_recommendation_generate',
    'activity_cleanup',
    'gfriends_filetree_refresh',
  ];

  final Map<String, String> crons;
  final int workerDefaultConcurrency;

  factory AdvancedSchedulerConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedSchedulerConfigDto(
      crons: Map<String, String>.unmodifiable(<String, String>{
        for (final key in cronKeys) key: json['${key}_cron'] as String,
      }),
      workerDefaultConcurrency: _intAt(
        json,
        'worker_default_concurrency',
        fallback: 4,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'worker_default_concurrency': workerDefaultConcurrency,
      for (final entry in crons.entries) '${entry.key}_cron': entry.value,
    };
  }
}

class AdvancedDownloadsConfigDto {
  const AdvancedDownloadsConfigDto({
    required this.subscriptionSearchFreshDays,
    required this.subscriptionSearchStaleAttemptLimit,
  });

  final int subscriptionSearchFreshDays;
  final int subscriptionSearchStaleAttemptLimit;

  factory AdvancedDownloadsConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedDownloadsConfigDto(
      subscriptionSearchFreshDays: _intAt(
        json,
        'subscription_search_fresh_days',
      ),
      subscriptionSearchStaleAttemptLimit: _intAt(
        json,
        'subscription_search_stale_attempt_limit',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'subscription_search_fresh_days': subscriptionSearchFreshDays,
      'subscription_search_stale_attempt_limit':
          subscriptionSearchStaleAttemptLimit,
    };
  }
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

class OptionalServicesConfigDto {
  const OptionalServicesConfigDto({
    required this.qdrantEnabled,
    required this.imageSearchEnabled,
    required this.qdrantUrl,
    required this.qdrantApiKey,
    required this.inferenceUrl,
    required this.inferenceApiKey,
  });
  final bool qdrantEnabled;
  final bool imageSearchEnabled;
  final String qdrantUrl;
  final String qdrantApiKey;
  final String inferenceUrl;
  final String inferenceApiKey;

  /// 旧版后端不返回这两个 `enabled` 键，此时不展示可选服务配置卡片。
  static OptionalServicesConfigDto? fromJsonOrNull(
    Map<String, dynamic> values,
  ) {
    final qdrant = asMapOrNull(values['qdrant']);
    final image = asMapOrNull(values['image_search']);
    if (qdrant == null ||
        image == null ||
        !qdrant.containsKey('enabled') ||
        !image.containsKey('enabled')) {
      return null;
    }
    return OptionalServicesConfigDto.fromJson(values);
  }

  factory OptionalServicesConfigDto.fromJson(Map<String, dynamic> values) {
    final qdrant = asMap(values['qdrant']);
    final image = asMap(values['image_search']);
    return OptionalServicesConfigDto(
      qdrantEnabled: qdrant['enabled'] as bool,
      imageSearchEnabled: image['enabled'] as bool,
      qdrantUrl: _stringAt(qdrant, 'url'),
      qdrantApiKey: _stringAt(qdrant, 'api_key'),
      inferenceUrl: _stringAt(image, 'inference_base_url'),
      inferenceApiKey: _stringAt(image, 'inference_api_key'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'qdrant': <String, dynamic>{
        'enabled': qdrantEnabled,
        'url': qdrantUrl,
        'api_key': qdrantApiKey,
      },
      'image_search': <String, dynamic>{
        'enabled': imageSearchEnabled,
        'inference_base_url': inferenceUrl,
        'inference_api_key': inferenceApiKey,
      },
    };
  }
}
