import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/app/language/localized_text.dart';
import 'package:sakuramedia/core/json/json_parse.dart';

/// 插件市场索引（`index.json`）整体结构。
class PluginMarketCatalogDto {
  const PluginMarketCatalogDto({
    required this.schemaVersion,
    this.updatedAt,
    required this.plugins,
  });

  final int schemaVersion;
  final DateTime? updatedAt;
  final List<PluginMarketItemDto> plugins;

  factory PluginMarketCatalogDto.fromJson(Map<String, dynamic> json) {
    final rawPlugins = json['plugins'];
    return PluginMarketCatalogDto(
      schemaVersion: asInt(json['schema_version']),
      updatedAt: asDateTime(json['updated_at']),
      plugins: <PluginMarketItemDto>[
        if (rawPlugins is List)
          for (final item in rawPlugins)
            if (asMapOrNull(item) case final map?)
              PluginMarketItemDto.fromJson(map),
      ],
    );
  }
}

/// 插件市场索引中的单个插件条目。
class PluginMarketItemDto {
  const PluginMarketItemDto({
    required this.pluginId,
    required this.displayName,
    required this.description,
    required this.author,
    required this.repo,
    this.homepage,
    this.iconUrl,
    this.categories = const <String>[],
    this.official = false,
    this.latest,
    this.displayNameI18n = const <String, String>{},
    this.descriptionI18n = const <String, String>{},
  });

  final String pluginId;
  final String displayName;
  final String description;
  final String author;
  final String repo;
  final String? homepage;
  final String? iconUrl;
  final List<String> categories;
  final bool official;
  final PluginMarketReleaseDto? latest;

  /// 展示名的多语言翻译（键为语言标签）；缺失时回退 [displayName]。
  final Map<String, String> displayNameI18n;

  /// 简介的多语言翻译（键为语言标签）；缺失时回退 [description]。
  final Map<String, String> descriptionI18n;

  /// 项目主页地址：`homepage` 合法时优先，否则回退 GitHub 仓库地址。
  ///
  /// 两者都不可用时返回 `null`，调用方据此隐藏入口。
  String? get homepageUrl {
    final home = homepage;
    if (home != null && _isHttpUrl(home)) {
      return home;
    }
    if (repo.isEmpty) {
      return null;
    }
    return 'https://github.com/$repo';
  }

  factory PluginMarketItemDto.fromJson(Map<String, dynamic> json) {
    return PluginMarketItemDto(
      pluginId: asStringOrNull(json['plugin_id'], trim: true) ?? '',
      displayName: asStringOrNull(json['display_name'], trim: true) ?? '',
      description: asStringOrNull(json['description'], trim: true) ?? '',
      author: asStringOrNull(json['author'], trim: true) ?? '',
      repo: asStringOrNull(json['repo'], trim: true) ?? '',
      homepage: asStringOrNull(json['homepage'], trim: true),
      iconUrl: asStringOrNull(json['icon'], trim: true),
      categories: asStringList(json['categories'], trim: true),
      official: json['official'] == true,
      displayNameI18n: asStringMap(json['display_name_i18n'], trim: true),
      descriptionI18n: asStringMap(json['description_i18n'], trim: true),
      latest: switch (asMapOrNull(json['latest'])) {
        final map? => PluginMarketReleaseDto.fromJson(map),
        null => null,
      },
    );
  }
}

/// 市场条目的展示文案：按当前语言解析名称与简介，缺失时回退索引里的原文。
extension PluginMarketItemDisplay on PluginMarketItemDto {
  /// 当前语言下的插件名。
  String localizedDisplayName(AppLanguage language) => resolveLocalizedText(
    translations: displayNameI18n,
    fallback: displayName,
    language: language,
  );

  /// 当前语言下的插件简介。
  String localizedDescription(AppLanguage language) => resolveLocalizedText(
    translations: descriptionI18n,
    fallback: description,
    language: language,
  );

  /// 搜索可命中的全部文案变体：各语言的名称与简介。
  ///
  /// 关键词过滤不依赖当前语言，切换界面语言后无需重新拉取索引也能搜到。
  Iterable<String> get searchTexts => <String>[
    displayName,
    description,
    ...displayNameI18n.values,
    ...descriptionI18n.values,
  ];
}

/// 市场索引中插件的最新 Release 信息（由索引仓库自动同步）。
class PluginMarketReleaseDto {
  const PluginMarketReleaseDto({
    required this.version,
    required this.hostApiVersion,
    required this.downloadUrl,
    this.sha256,
    this.publishedAt,
  });

  final String version;
  final int hostApiVersion;
  final String downloadUrl;
  final String? sha256;
  final DateTime? publishedAt;

  factory PluginMarketReleaseDto.fromJson(Map<String, dynamic> json) {
    return PluginMarketReleaseDto(
      version: asStringOrNull(json['version'], trim: true) ?? '',
      hostApiVersion: asInt(json['host_api_version']),
      downloadUrl: asStringOrNull(json['download_url'], trim: true) ?? '',
      sha256: asStringOrNull(json['sha256'], trim: true),
      publishedAt: asDateTime(json['published_at']),
    );
  }
}

bool _isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}
