import 'dart:ui' show Locale;

import 'package:sakuramedia/core/format/release_version.dart';
import 'package:sakuramedia/core/json/json_parse.dart';

enum AnnouncementLevel { info, warning, critical }

enum AnnouncementComponent { all, frontend, backend }

class AnnouncementDto {
  const AnnouncementDto({
    required this.id,
    required this.level,
    required this.titleI18n,
    required this.bodyI18n,
    required this.publishedAt,
    this.expiresAt,
    this.component = AnnouncementComponent.all,
    this.affectedFromVersion,
    this.resolvedInVersion,
    this.link,
  });

  final String id;
  final AnnouncementLevel level;
  final Map<String, String> titleI18n;
  final Map<String, String> bodyI18n;
  final DateTime publishedAt;
  final DateTime? expiresAt;
  final AnnouncementComponent component;
  final String? affectedFromVersion;
  final String? resolvedInVersion;
  final String? link;

  static AnnouncementDto? tryFromJson(Map<String, dynamic> json) {
    final id = asStringOrNull(json['id'], trim: true);
    final publishedAt = asDateTime(json['published_at']);
    final titleI18n = asStringMap(json['title_i18n'], trim: true);
    final bodyI18n = asStringMap(json['body_i18n'], trim: true);
    if (id == null ||
        publishedAt == null ||
        titleI18n.isEmpty ||
        bodyI18n.isEmpty) {
      return null;
    }

    final link = asStringOrNull(json['link'], trim: true);
    return AnnouncementDto(
      id: id,
      level: _parseLevel(json['level']),
      titleI18n: titleI18n,
      bodyI18n: bodyI18n,
      publishedAt: publishedAt,
      expiresAt: asDateTime(json['expires_at']),
      component: _parseComponent(json['component']),
      affectedFromVersion: asStringOrNull(
        json['affected_from_version'],
        trim: true,
      ),
      resolvedInVersion: asStringOrNull(
        json['resolved_in_version'],
        trim: true,
      ),
      link: link != null && link.startsWith('https://') ? link : null,
    );
  }

  bool isActiveAt(DateTime now) {
    if (publishedAt.isAfter(now)) {
      return false;
    }
    final expiresAt = this.expiresAt;
    return expiresAt == null || expiresAt.isAfter(now);
  }

  bool targetsVersions({
    required String frontendVersion,
    required String backendVersion,
  }) {
    if (component == AnnouncementComponent.all) {
      return true;
    }
    final currentVersion = component == AnnouncementComponent.frontend
        ? frontendVersion
        : backendVersion;
    final current = ReleaseVersion.tryParse(currentVersion);
    if (current == null) {
      // 版本未知时宁可多显示，也不能漏掉严重公告。
      return true;
    }

    final affectedFrom = _parseVersionBound(affectedFromVersion);
    if (affectedFrom != null && current.compareTo(affectedFrom) < 0) {
      return false;
    }
    final resolvedIn = _parseVersionBound(resolvedInVersion);
    if (resolvedIn != null && current.compareTo(resolvedIn) >= 0) {
      return false;
    }
    return true;
  }

  String titleFor(Locale locale) => _localized(titleI18n, locale);

  String bodyFor(Locale locale) => _localized(bodyI18n, locale);

  static ReleaseVersion? _parseVersionBound(String? value) {
    if (value == null) {
      return null;
    }
    return ReleaseVersion.tryParse(value);
  }

  static String _localized(Map<String, String> values, Locale locale) {
    final preferred = locale.languageCode == 'zh' ? 'zh-CN' : 'en';
    return values[preferred] ?? values['zh-CN'] ?? values['en'] ?? '';
  }

  static AnnouncementLevel _parseLevel(dynamic value) {
    return switch (value) {
      'critical' => AnnouncementLevel.critical,
      'warning' => AnnouncementLevel.warning,
      _ => AnnouncementLevel.info,
    };
  }

  static AnnouncementComponent _parseComponent(dynamic value) {
    return switch (value) {
      'frontend' => AnnouncementComponent.frontend,
      'backend' => AnnouncementComponent.backend,
      _ => AnnouncementComponent.all,
    };
  }
}
