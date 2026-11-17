import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/announcements/data/announcement_dto.dart';

void main() {
  test('parses localized text and filters by active version range', () {
    final announcement = AnnouncementDto.tryFromJson(<String, dynamic>{
      'id': 'security-1',
      'level': 'critical',
      'title_i18n': <String, dynamic>{'zh-CN': '请升级', 'en': 'Please upgrade'},
      'body_i18n': <String, dynamic>{
        'zh-CN': '旧版本存在安全问题',
        'en': 'Older versions are affected',
      },
      'published_at': '2026-11-12T08:00:00Z',
      'component': 'backend',
      'affected_from_version': '0.10.0',
      'resolved_in_version': '0.15.0',
      'link': 'https://example.test/advisory',
    });

    expect(announcement, isNotNull);
    expect(announcement!.level, AnnouncementLevel.critical);
    expect(announcement.titleFor(const Locale('zh', 'CN')), '请升级');
    expect(announcement.titleFor(const Locale('en')), 'Please upgrade');
    expect(
      announcement.targetsVersions(
        frontendVersion: '0.15.0',
        backendVersion: '0.14.2',
      ),
      isTrue,
    );
    expect(
      announcement.targetsVersions(
        frontendVersion: '0.15.0',
        backendVersion: '0.15.0',
      ),
      isFalse,
    );
    expect(
      announcement.targetsVersions(
        frontendVersion: '0.15.0',
        backendVersion: 'dev-local',
      ),
      isTrue,
    );
  });

  test('rejects missing required fields and unsafe links', () {
    final announcement = AnnouncementDto.tryFromJson(<String, dynamic>{
      'id': 'notice-1',
      'level': 'info',
      'title_i18n': <String, dynamic>{'zh-CN': '标题', 'en': 'Title'},
      'body_i18n': <String, dynamic>{'zh-CN': '正文', 'en': 'Body'},
      'published_at': '2026-11-12T08:00:00Z',
      'link': 'http://example.test/notice',
    });

    expect(announcement, isNotNull);
    expect(announcement!.link, isNull);
    expect(
      AnnouncementDto.tryFromJson(<String, dynamic>{
        'id': 'missing-body',
        'title_i18n': <String, dynamic>{'zh-CN': '标题'},
        'published_at': '2026-11-12T08:00:00Z',
      }),
      isNull,
    );
  });

  test('checks publication and expiration windows', () {
    final now = DateTime.utc(2026, 11, 12, 8);
    final announcement = AnnouncementDto(
      id: 'notice-1',
      level: AnnouncementLevel.info,
      titleI18n: const <String, String>{'zh-CN': '标题', 'en': 'Title'},
      bodyI18n: const <String, String>{'zh-CN': '正文', 'en': 'Body'},
      publishedAt: now.subtract(const Duration(minutes: 1)),
      expiresAt: now.add(const Duration(minutes: 1)),
    );

    expect(announcement.isActiveAt(now), isTrue);
    expect(
      announcement.isActiveAt(now.subtract(const Duration(minutes: 2))),
      isFalse,
    );
    expect(
      announcement.isActiveAt(now.add(const Duration(minutes: 2))),
      isFalse,
    );
  });
}
