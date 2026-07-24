import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';

/// `GET /config` 的整包快照。**解析容错分两档**：
///
/// - **节级严格**：`values` 与 `media`/`metadata`/`scheduler`/`downloads`/`logging`
///   五节缺失或不是对象 → 抛 [FormatException]。整节没了是真·契约破裂，该炸得响。
/// - **字段级容错**：节内单个字段缺失/类型漂移 → 走 `core/json/json_parse.dart`
///   取默认值，不抛。
///
/// 之所以这么分：本 DTO 被「下载偏好」和「高级设置」两页共用，各自只关心其中一节。
/// 早先字段级也抛异常，结果后端删掉 `media.collection_duration_threshold_minutes`
/// 之后，只读 `downloads` 一节的下载偏好页也被 media 节拖成「加载失败」，而
/// [apiErrorMessage] 对非 [ApiException] 只会吐兜底文案，页面上看不到任何线索。
///
/// 代价：后端再删字段时，该字段会静默显示默认值，且该卡片的 PATCH 会因为提交了
/// 后端已拒绝的 key 而 422——但其余卡片和另一整页仍然可用，比两页全砖强得多。
/// 契约漂移最终仍要靠前后端同步修，这里只保证漂移不会连坐。
class ConfigResourceDto {
  const ConfigResourceDto({
    required this.media,
    required this.metadata,
    required this.scheduler,
    required this.downloads,
    required this.logging,
    required this.effects,
  });

  final AdvancedMediaConfigDto media;
  final AdvancedMetadataConfigDto metadata;
  final AdvancedSchedulerConfigDto scheduler;
  final AdvancedDownloadsConfigDto downloads;
  final AdvancedLoggingConfigDto logging;
  final Map<String, String> effects;

  factory ConfigResourceDto.fromJson(Map<String, dynamic> json) {
    final values = _objectAt(json, 'values', '/config response');
    final effects = _optionalObjectAt(json, 'effects', '/config response');
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
      effects: Map<String, String>.unmodifiable(
        _targetSectionKeys.fold<Map<String, String>>(<String, String>{}, (
          result,
          key,
        ) {
          final value = asStringOrNull(effects[key]);
          if (value == null) {
            return result;
          }
          result[key] = value;
          return result;
        }),
      ),
    );
  }
}

class ConfigUpdateResultDto {
  const ConfigUpdateResultDto({
    required this.values,
    required this.applied,
    required this.pendingRestart,
  });

  final ConfigResourceDto values;
  final List<String> applied;
  final List<PendingRestartFieldDto> pendingRestart;

  factory ConfigUpdateResultDto.fromJson(Map<String, dynamic> json) {
    return ConfigUpdateResultDto(
      values: ConfigResourceDto.fromJson(json),
      applied: List<String>.unmodifiable(_stringList(json, 'applied')),
      pendingRestart: List<PendingRestartFieldDto>.unmodifiable(
        _objectList(
          json,
          'pending_restart',
        ).map(PendingRestartFieldDto.fromJson),
      ),
    );
  }
}

class PendingRestartFieldDto {
  const PendingRestartFieldDto({required this.field, required this.restart});

  final String field;
  final String restart;

  factory PendingRestartFieldDto.fromJson(Map<String, dynamic> json) {
    return PendingRestartFieldDto(
      field: _stringAt(json, 'field'),
      restart: _stringAt(json, 'restart'),
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
        _stringList(json, 'others_number_features'),
      ),
      innerSubTags: List<String>.unmodifiable(
        _stringList(json, 'inner_sub_tags'),
      ),
      bluerayTags: List<String>.unmodifiable(_stringList(json, 'blueray_tags')),
      uncensoredTags: List<String>.unmodifiable(
        _stringList(json, 'uncensored_tags'),
      ),
      uncensoredPrefix: List<String>.unmodifiable(
        _stringList(json, 'uncensored_prefix'),
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
    required this.javdbUsername,
    required this.javdbPassword,
    required this.proxy,
  });

  final String javdbHost;
  final String javdbUsername;
  final String javdbPassword;
  final String proxy;

  factory AdvancedMetadataConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedMetadataConfigDto(
      javdbHost: _stringAt(json, 'javdb_host'),
      javdbUsername: _stringAt(json, 'javdb_username'),
      javdbPassword: _stringAt(json, 'javdb_password'),
      proxy: _stringAt(json, 'proxy'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'javdb_host': javdbHost,
      'javdb_username': javdbUsername,
      'javdb_password': javdbPassword,
      'proxy': proxy,
    };
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
    'ranking_sync',
    'hot_review_sync',
    'media_file_scan',
    'movie_desc_sync',
    'movie_desc_translation',
    'movie_title_translation',
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

const List<String> _targetSectionKeys = <String>[
  'media',
  'metadata',
  'scheduler',
  'downloads',
  'logging',
];

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

Map<String, dynamic> _optionalObjectAt(
  Map<String, dynamic> json,
  String key, [
  String path = 'object',
]) {
  final value = json[key];
  if (value == null) {
    return const <String, dynamic>{};
  }
  if (value is! Map) {
    throw FormatException('$path "$key" must be an object');
  }
  return Map<String, dynamic>.from(value);
}

/// 列表项里非对象的条目直接跳过（后端加了新形态的元素时不该整包解析失败）。
List<Map<String, dynamic>> _objectList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return <Map<String, dynamic>>[
    for (final item in value)
      if (asMapOrNull(item) case final map?) map,
  ];
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

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    return const <String>[];
  }
  return <String>[
    for (final item in value)
      if (asStringOrNull(item) case final text?) text,
  ];
}
