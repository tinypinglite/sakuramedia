import 'package:sakuramedia/core/json/json_parse.dart';

enum PluginTestCapability {
  metadata,
  stats,
  reviews;

  String get wireValue => switch (this) {
    PluginTestCapability.metadata => 'metadata',
    PluginTestCapability.stats => 'stats',
    PluginTestCapability.reviews => 'reviews',
  };

  static PluginTestCapability? tryParse(String value) {
    return switch (value) {
      'metadata' => PluginTestCapability.metadata,
      'stats' => PluginTestCapability.stats,
      'reviews' => PluginTestCapability.reviews,
      _ => null,
    };
  }
}

enum PluginTestStatus {
  ok,
  empty,
  failed;

  static PluginTestStatus fromWire(String? value) {
    return switch (value) {
      'ok' => PluginTestStatus.ok,
      'empty' => PluginTestStatus.empty,
      _ => PluginTestStatus.failed,
    };
  }
}

/// `GET /system/plugins` 列表项。
class PluginSummaryDto {
  const PluginSummaryDto({
    required this.pluginId,
    required this.displayName,
    required this.version,
    required this.hostApiVersion,
    required this.enabled,
    required this.loadStatus,
    this.loadError,
    this.releaseApiUrl,
    this.testCapabilities = const <PluginTestCapability>[],
    this.testMovieNumber,
  });

  final String pluginId;
  final String displayName;
  final String version;
  final int hostApiVersion;
  final bool enabled;
  final String loadStatus;
  final String? loadError;
  final String? releaseApiUrl;
  final List<PluginTestCapability> testCapabilities;
  final String? testMovieNumber;

  factory PluginSummaryDto.fromJson(Map<String, dynamic> json) {
    return PluginSummaryDto(
      pluginId: asStringOrNull(json['plugin_id']) ?? '',
      displayName: asStringOrNull(json['display_name']) ?? '',
      version: asStringOrNull(json['version']) ?? '',
      hostApiVersion: asInt(json['host_api_version']),
      enabled: json['enabled'] == true,
      loadStatus: asStringOrNull(json['load_status']) ?? 'ok',
      loadError: asStringOrNull(json['load_error']),
      releaseApiUrl: asStringOrNull(json['release_api_url'], trim: true),
      testCapabilities: <PluginTestCapability>[
        for (final value in asStringList(json['test_capabilities']))
          ?PluginTestCapability.tryParse(value),
      ],
      testMovieNumber: asStringOrNull(json['test_movie_number'], trim: true),
    );
  }

  PluginSummaryDto copyWith({String? version}) {
    return PluginSummaryDto(
      pluginId: pluginId,
      displayName: displayName,
      version: version ?? this.version,
      hostApiVersion: hostApiVersion,
      enabled: enabled,
      loadStatus: loadStatus,
      loadError: loadError,
      releaseApiUrl: releaseApiUrl,
      testCapabilities: testCapabilities,
      testMovieNumber: testMovieNumber,
    );
  }
}

/// GitHub Release 中可供安装的插件更新。
class PluginReleaseUpdate {
  const PluginReleaseUpdate({
    required this.version,
    required this.notes,
    required this.assetUrl,
    required this.assetFileName,
    this.sha256,
  });

  final String version;
  final String notes;
  final String assetUrl;
  final String assetFileName;
  final String? sha256;
}

/// 插件私有配置接口的响应（`plugins.settings.<plugin_id>`）。
class PluginSettingsDto {
  const PluginSettingsDto({
    required this.settings,
    this.schema,
    this.defaults = const {},
  });

  final Map<String, dynamic> settings;
  final Map<String, dynamic>? schema;
  final Map<String, dynamic> defaults;

  factory PluginSettingsDto.fromJson(Map<String, dynamic> json) {
    return PluginSettingsDto(
      settings: asMap(json['settings']),
      schema: asMapOrNull(json['schema']),
      defaults: asMap(json['defaults']),
    );
  }
}

class PluginTestMetadataSummaryDto {
  const PluginTestMetadataSummaryDto({
    required this.movieNumber,
    required this.title,
    required this.releaseDate,
    required this.durationMinutes,
    required this.actorCount,
    required this.tagCount,
    required this.imageCount,
    this.sourceUrl,
  });

  final String movieNumber;
  final String title;
  final DateTime? releaseDate;
  final int durationMinutes;
  final int actorCount;
  final int tagCount;
  final int imageCount;
  final String? sourceUrl;

  factory PluginTestMetadataSummaryDto.fromJson(Map<String, dynamic> json) {
    return PluginTestMetadataSummaryDto(
      movieNumber: asStringOrNull(json['movie_number']) ?? '',
      title: asStringOrNull(json['title']) ?? '',
      releaseDate: DateTime.tryParse(
        asStringOrNull(json['release_date'], trim: true) ?? '',
      ),
      durationMinutes: asIntOrNull(json['duration_minutes']) ?? 0,
      actorCount: asIntOrNull(json['actor_count']) ?? 0,
      tagCount: asIntOrNull(json['tag_count']) ?? 0,
      imageCount: asIntOrNull(json['image_count']) ?? 0,
      sourceUrl: asStringOrNull(json['source_url'], trim: true),
    );
  }
}

class PluginTestStatsSummaryDto {
  const PluginTestStatsSummaryDto({
    required this.heat,
    required this.fieldCount,
    required this.values,
  });

  final int heat;
  final int fieldCount;
  final Map<String, dynamic> values;

  factory PluginTestStatsSummaryDto.fromJson(Map<String, dynamic> json) {
    return PluginTestStatsSummaryDto(
      heat: asIntOrNull(json['heat']) ?? 0,
      fieldCount: asIntOrNull(json['field_count']) ?? 0,
      values: asMap(json['values']),
    );
  }
}

class PluginTestReviewsSummaryDto {
  const PluginTestReviewsSummaryDto({
    required this.itemCount,
    this.firstUsername,
    this.firstExcerpt,
  });

  final int itemCount;
  final String? firstUsername;
  final String? firstExcerpt;

  factory PluginTestReviewsSummaryDto.fromJson(Map<String, dynamic> json) {
    return PluginTestReviewsSummaryDto(
      itemCount: asIntOrNull(json['item_count']) ?? 0,
      firstUsername: asStringOrNull(json['first_username'], trim: true),
      firstExcerpt: asStringOrNull(json['first_excerpt'], trim: true),
    );
  }
}

class PluginTestResultDto {
  const PluginTestResultDto({
    required this.capability,
    required this.status,
    required this.movieNumber,
    required this.durationMs,
    this.metadata,
    this.stats,
    this.reviews,
    this.errorType,
    this.errorMessage,
  });

  final PluginTestCapability capability;
  final PluginTestStatus status;
  final String movieNumber;
  final int durationMs;
  final PluginTestMetadataSummaryDto? metadata;
  final PluginTestStatsSummaryDto? stats;
  final PluginTestReviewsSummaryDto? reviews;
  final String? errorType;
  final String? errorMessage;

  factory PluginTestResultDto.fromJson(Map<String, dynamic> json) {
    final capability =
        PluginTestCapability.tryParse(
          asStringOrNull(json['capability'], trim: true) ?? '',
        ) ??
        PluginTestCapability.metadata;
    return PluginTestResultDto(
      capability: capability,
      status: PluginTestStatus.fromWire(
        asStringOrNull(json['status'], trim: true),
      ),
      movieNumber: asStringOrNull(json['movie_number']) ?? '',
      durationMs: asIntOrNull(json['duration_ms']) ?? 0,
      metadata: switch (asMapOrNull(json['metadata'])) {
        final data? => PluginTestMetadataSummaryDto.fromJson(data),
        null => null,
      },
      stats: switch (asMapOrNull(json['stats'])) {
        final data? => PluginTestStatsSummaryDto.fromJson(data),
        null => null,
      },
      reviews: switch (asMapOrNull(json['reviews'])) {
        final data? => PluginTestReviewsSummaryDto.fromJson(data),
        null => null,
      },
      errorType: asStringOrNull(json['error_type'], trim: true),
      errorMessage: asStringOrNull(json['error_message'], trim: true),
    );
  }
}
