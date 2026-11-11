import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/app_version_info_state.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/announcements/data/announcement_dto.dart';
import 'package:sakuramedia/features/announcements/data/announcements_api.dart';
import 'package:sakuramedia/features/announcements/presentation/announcement_state_store.dart';
import 'package:sakuramedia/features/announcements/presentation/providers/announcement_feed_provider.dart';
import 'package:sakuramedia/features/announcements/presentation/providers/announcement_state_store_provider.dart';
import 'package:sakuramedia/features/announcements/presentation/providers/announcements_api_provider.dart';

AnnouncementDto buildAnnouncement(
  String id, {
  AnnouncementLevel level = AnnouncementLevel.info,
  AnnouncementComponent component = AnnouncementComponent.all,
  String? affectedFromVersion,
  String? resolvedInVersion,
  DateTime? publishedAt,
  DateTime? expiresAt,
}) {
  return AnnouncementDto(
    id: id,
    level: level,
    titleI18n: const <String, String>{'zh-CN': '标题', 'en': 'Title'},
    bodyI18n: const <String, String>{'zh-CN': '正文', 'en': 'Body'},
    publishedAt:
        publishedAt ??
        DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    expiresAt: expiresAt,
    component: component,
    affectedFromVersion: affectedFromVersion,
    resolvedInVersion: resolvedInVersion,
  );
}

void main() {
  late SessionStore sessionStore;
  late InMemoryAnnouncementStateStore store;
  late _FakeAnnouncementsApi api;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-11-12T10:00:00Z'),
    );
    store = InMemoryAnnouncementStateStore();
    api = _FakeAnnouncementsApi();
  });

  tearDown(() => sessionStore.dispose());

  ProviderContainer buildContainer({bool unknownBackendVersion = false}) {
    final container = ProviderContainer(
      overrides: <Override>[
        sessionStoreProvider.overrideWithValue(sessionStore),
        announcementsApiProvider.overrideWithValue(api),
        announcementStateStoreProvider.overrideWithValue(store),
        appVersionInfoProvider.overrideWith(
          unknownBackendVersion
              ? _UnknownBackendVersionInfo.new
              : _FixedVersionInfo.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('filters active and version-targeted announcements', () async {
    final now = DateTime.now().toUtc();
    api.items = <AnnouncementDto>[
      buildAnnouncement(
        'info',
        publishedAt: now.subtract(const Duration(minutes: 20)),
      ),
      buildAnnouncement(
        'backend-warning',
        level: AnnouncementLevel.warning,
        component: AnnouncementComponent.backend,
        affectedFromVersion: '0.10.0',
        resolvedInVersion: '0.20.0',
        publishedAt: now.subtract(const Duration(minutes: 10)),
      ),
      buildAnnouncement(
        'hidden-frontend',
        component: AnnouncementComponent.frontend,
        resolvedInVersion: '0.14.0',
        publishedAt: now.subtract(const Duration(minutes: 5)),
      ),
      buildAnnouncement(
        'critical',
        level: AnnouncementLevel.critical,
        component: AnnouncementComponent.backend,
        affectedFromVersion: '0.10.0',
        resolvedInVersion: '0.20.0',
        publishedAt: now.subtract(const Duration(minutes: 1)),
      ),
      buildAnnouncement(
        'expired',
        publishedAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(minutes: 1)),
      ),
      buildAnnouncement(
        'future',
        publishedAt: now.add(const Duration(minutes: 1)),
      ),
    ];

    final container = buildContainer();
    container.listen(announcementFeedProvider, (_, _) {});
    await container.read(announcementFeedProvider.notifier).load();

    final state = container.read(announcementFeedProvider);
    expect(
      state.active.map((item) => item.id),
      containsAll(<String>['info', 'backend-warning', 'critical']),
    );
    expect(
      state.active.map((item) => item.id),
      isNot(contains('hidden-frontend')),
    );
    expect(state.active.map((item) => item.id), isNot(contains('expired')));
    expect(state.active.map((item) => item.id), isNot(contains('future')));
    expect(state.criticalUnacknowledged.single.id, 'critical');
    expect(state.hasUnseen, isTrue);

    await container.read(announcementFeedProvider.notifier).markSeen();
    expect(container.read(announcementFeedProvider).hasUnseen, isFalse);

    await container.read(announcementFeedProvider.notifier).acknowledgeCritical(
      <String>['critical'],
    );
    expect(
      container.read(announcementFeedProvider).criticalUnacknowledged,
      isEmpty,
    );
    expect(
      container.read(announcementFeedProvider).active.map((item) => item.id),
      contains('critical'),
    );
  });

  test('fails open when the installed version is unknown', () async {
    api.items = <AnnouncementDto>[
      buildAnnouncement(
        'backend-only',
        component: AnnouncementComponent.backend,
        affectedFromVersion: '0.99.0',
      ),
    ];

    final container = buildContainer(unknownBackendVersion: true);
    container.listen(announcementFeedProvider, (_, _) {});
    await container.read(announcementFeedProvider.notifier).load();

    expect(
      container.read(announcementFeedProvider).active.single.id,
      'backend-only',
    );
  });

  test(
    'critical announcements do not drive the version-menu red dot',
    () async {
      api.items = <AnnouncementDto>[
        buildAnnouncement('critical-only', level: AnnouncementLevel.critical),
      ];
      final container = buildContainer();
      container.listen(announcementFeedProvider, (_, _) {});
      await container.read(announcementFeedProvider.notifier).load();

      expect(
        container
            .read(announcementFeedProvider)
            .criticalUnacknowledged
            .single
            .id,
        'critical-only',
      );
      expect(container.read(announcementFeedProvider).hasUnseen, isFalse);

      await container
          .read(announcementFeedProvider.notifier)
          .acknowledgeCritical(<String>['critical-only']);

      expect(container.read(announcementFeedProvider).hasUnseen, isFalse);
      expect(
        container.read(announcementFeedProvider).criticalUnacknowledged,
        isEmpty,
      );
    },
  );

  test('keeps the previous state when a refresh fails', () async {
    api.items = <AnnouncementDto>[buildAnnouncement('before')];
    final container = buildContainer();
    container.listen(announcementFeedProvider, (_, _) {});
    await container.read(announcementFeedProvider.notifier).load();

    api.error = StateError('offline');
    await container.read(announcementFeedProvider.notifier).load();

    expect(container.read(announcementFeedProvider).active.single.id, 'before');
  });
}

class _FakeAnnouncementsApi implements AnnouncementsApi {
  List<AnnouncementDto> items = const <AnnouncementDto>[];
  Object? error;

  @override
  Future<List<AnnouncementDto>> getAnnouncements() async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return items;
  }
}

class _FixedVersionInfo extends AppVersionInfo {
  @override
  AppVersionInfoState build() => const AppVersionInfoState(
    frontendVersion: '0.15.0',
    backendVersion: '0.15.0',
  );

  @override
  Future<void> load() async {}
}

class _UnknownBackendVersionInfo extends AppVersionInfo {
  @override
  AppVersionInfoState build() => const AppVersionInfoState(
    frontendVersion: '0.15.0',
    backendVersion: 'dev-local',
  );

  @override
  Future<void> load() async {}
}
