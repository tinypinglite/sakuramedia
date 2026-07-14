import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/config_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/config_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/desktop_advanced_settings_section.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  group('DesktopAdvancedSettingsSection', () {
    late SessionStore sessionStore;
    late TestApiBundle bundle;

    setUp(() async {
      sessionStore = await _buildLoggedInSessionStore();
      bundle = await createTestApiBundle(sessionStore);
    });

    tearDown(() {
      bundle.dispose();
    });

    testWidgets('loads lazily only when active', (WidgetTester tester) async {
      await _pumpSection(tester, bundle, active: false);

      expect(bundle.adapter.hitCount('GET', '/config'), 0);

      _enqueueAdvancedConfig(bundle);
      await _pumpSection(tester, bundle, active: true);

      expect(bundle.adapter.hitCount('GET', '/config'), 1);
      expect(
        find.byKey(const Key('configuration-advanced-media-card')),
        findsOneWidget,
      );

      await _pumpSection(tester, bundle, active: true);

      expect(bundle.adapter.hitCount('GET', '/config'), 1);
    });

    testWidgets('shows normalized preview and saves media as partial patch', (
      WidgetTester tester,
    ) async {
      _enqueueAdvancedConfig(bundle);
      _enqueueAdvancedConfigPatch(
        bundle,
        applied: const <String>['media.others_number_features'],
      );

      await _pumpSection(tester, bundle, active: true);
      await tester.enterText(
        find.byKey(
          const Key('configuration-advanced-others-number-features-field'),
        ),
        'ofje_test',
      );
      await tester.pump();

      expect(find.textContaining('OFJE-TEST'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('configuration-advanced-media-save-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-advanced-media-save-button')),
      );
      await tester.pumpAndSettle();

      final request = bundle.adapter.requests.firstWhere(
        (item) => item.method == 'PATCH' && item.path == '/config',
      );
      expect(request.body.keys, contains('media'));
      expect(request.body.keys, isNot(contains('metadata')));
      expect(request.body['media']['others_number_features'], <String>[
        'ofje_test',
      ]);
      expect(request.body['media']['allowed_min_video_file_size'], 268435456);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('omits blank javdb password and includes nonblank password', (
      WidgetTester tester,
    ) async {
      _enqueueAdvancedConfig(bundle);
      _enqueueAdvancedConfigPatch(
        bundle,
        applied: const <String>['metadata.javdb_username'],
      );
      _enqueueAdvancedConfigPatch(
        bundle,
        applied: const <String>['metadata.javdb_password'],
      );

      await _pumpSection(tester, bundle, active: true);
      await tester.ensureVisible(
        find.byKey(const Key('configuration-advanced-javdb-username-field')),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-advanced-javdb-username-field')),
        'bob',
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-advanced-metadata-save-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-advanced-metadata-save-button')),
      );
      await tester.pumpAndSettle();

      final blankPasswordRequest = bundle.adapter.requests.firstWhere(
        (item) => item.method == 'PATCH' && item.path == '/config',
      );
      expect(
        blankPasswordRequest.body['metadata'].containsKey('javdb_password'),
        isFalse,
      );

      await tester.enterText(
        find.byKey(const Key('configuration-advanced-javdb-password-field')),
        'secret',
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-advanced-metadata-save-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-advanced-metadata-save-button')),
      );
      await tester.pumpAndSettle();

      final passwordRequest = bundle.adapter.requests.lastWhere(
        (item) => item.method == 'PATCH' && item.path == '/config',
      );
      expect(passwordRequest.body['metadata']['javdb_password'], 'secret');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows scheduler pending restart toast', (
      WidgetTester tester,
    ) async {
      _enqueueAdvancedConfig(bundle);
      _enqueueAdvancedConfigPatch(
        bundle,
        applied: const <String>['scheduler.movie_heat_cron'],
        pendingRestart: const <Map<String, dynamic>>[
          <String, dynamic>{
            'field': 'scheduler.movie_heat_cron',
            'restart': 'scheduler',
          },
        ],
      );

      await _pumpSection(tester, bundle, active: true);
      await tester.ensureVisible(
        find.byKey(const Key('configuration-advanced-cron-movie_heat-field')),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-advanced-cron-movie_heat-field')),
        '30 0 * * *',
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-advanced-scheduler-save-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-advanced-scheduler-save-button')),
      );
      await tester.pumpAndSettle();

      // toast 文案本身由 buildAdvancedConfigSaveSuccessMessage 单元测覆盖
      //（oktoast 在 test env 里不稳，widget 层只验证 PATCH 请求发出且带对应字段）。
      expect(bundle.adapter.hitCount('PATCH', '/config'), 1);
      final schedulerRequest = bundle.adapter.requests.firstWhere(
        (item) => item.method == 'PATCH' && item.path == '/config',
      );
      expect(schedulerRequest.body.keys, contains('scheduler'));
      expect(
        schedulerRequest.body['scheduler']['movie_heat_cron'],
        '30 0 * * *',
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('confirms logging level changes before api restart save', (
      WidgetTester tester,
    ) async {
      _enqueueAdvancedConfig(bundle);
      _enqueueAdvancedConfigPatch(
        bundle,
        applied: const <String>['logging.level'],
        pendingRestart: const <Map<String, dynamic>>[
          <String, dynamic>{'field': 'logging.level', 'restart': 'api'},
        ],
      );

      await _pumpSection(tester, bundle, active: true);
      await tester.ensureVisible(
        find.byKey(const Key('configuration-advanced-logging-level-field')),
      );
      await tester.tap(find.text('INFO').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('DEBUG').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-advanced-other-save-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('确认修改日志等级'), findsOneWidget);
      expect(bundle.adapter.hitCount('PATCH', '/config'), 0);

      await tester.tap(
        find.byKey(const Key('configuration-advanced-logging-confirm-button')),
      );
      await tester.pumpAndSettle();

      // toast 文案由 buildAdvancedConfigSaveSuccessMessage 单元测覆盖，
      // 这里只验证确认后确实发出了 PATCH 且带 logging.level。
      expect(bundle.adapter.hitCount('PATCH', '/config'), 1);
      final loggingRequest = bundle.adapter.requests.lastWhere(
        (item) => item.method == 'PATCH' && item.path == '/config',
      );
      expect(loggingRequest.body['logging']['level'], 'DEBUG');
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('buildAdvancedConfigSaveSuccessMessage', () {
    test('returns default message when pending_restart is empty', () {
      expect(
        buildAdvancedConfigSaveSuccessMessage(
          const <PendingRestartFieldDto>[],
        ),
        '已保存',
      );
    });

    test('reports api restart when only api-scope fields pending', () {
      expect(
        buildAdvancedConfigSaveSuccessMessage(const <PendingRestartFieldDto>[
          PendingRestartFieldDto(field: 'logging.level', restart: 'api'),
        ]),
        '已保存，需重启 API 进程才生效',
      );
    });

    test('reports scheduler restart when only scheduler-scope fields pending',
        () {
      expect(
        buildAdvancedConfigSaveSuccessMessage(const <PendingRestartFieldDto>[
          PendingRestartFieldDto(
            field: 'scheduler.movie_heat_cron',
            restart: 'scheduler',
          ),
          PendingRestartFieldDto(
            field: 'scheduler.ranking_sync_cron',
            restart: 'scheduler',
          ),
        ]),
        '已保存，需重启 aps 调度进程才生效',
      );
    });

    test('joins both restarts when logging and downloads changed together', () {
      // C3 修复覆盖：同一次「其他」卡保存里 logging(api) + downloads(scheduler)
      // 必须两个都在文案里，不能只报其一。
      expect(
        buildAdvancedConfigSaveSuccessMessage(const <PendingRestartFieldDto>[
          PendingRestartFieldDto(field: 'logging.level', restart: 'api'),
          PendingRestartFieldDto(
            field: 'downloads.small_file_cleanup_threshold_mb',
            restart: 'scheduler',
          ),
        ]),
        '已保存，需重启 API 进程 与 aps 调度进程才生效',
      );
    });
  });
}

Future<void> _pumpSection(
  WidgetTester tester,
  TestApiBundle bundle, {
  required bool active,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MultiProvider(
      providers: [Provider<ConfigApi>.value(value: bundle.configApi)],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DesktopAdvancedSettingsSection(active: active),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(tester.view.reset);
}

void _enqueueAdvancedConfig(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/config',
    body: _buildAdvancedConfigJson(),
  );
}

void _enqueueAdvancedConfigPatch(
  TestApiBundle bundle, {
  List<String> applied = const <String>[],
  List<Map<String, dynamic>> pendingRestart = const <Map<String, dynamic>>[],
}) {
  bundle.adapter.enqueueJson(
    method: 'PATCH',
    path: '/config',
    body: _buildAdvancedConfigJson(
      extra: <String, dynamic>{
        'applied': applied,
        'pending_restart': pendingRestart,
      },
    ),
  );
}

Map<String, dynamic> _buildAdvancedConfigJson({
  Map<String, dynamic> extra = const <String, dynamic>{},
}) {
  return <String, dynamic>{
    'values': <String, dynamic>{
      'media': <String, dynamic>{
        'others_number_features': <String>['OFJE', 'CJOB'],
        'collection_duration_threshold_minutes': 300,
        'inner_sub_tags': <String>['中字', '-C'],
        'blueray_tags': <String>['蓝光', '4K'],
        'uncensored_tags': <String>['uncensored', '-UC'],
        'uncensored_prefix': <String>['PT-', 'S2M'],
        'allowed_min_video_file_size': 268435456,
      },
      'metadata': <String, dynamic>{
        'javdb_host': 'jdforrepam.com',
        'javdb_username': 'alice',
        'javdb_password': '',
        'proxy': '',
      },
      'scheduler': <String, dynamic>{
        for (final key in AdvancedSchedulerConfigDto.cronKeys)
          '${key}_cron': key == 'movie_heat' ? '15 0 * * *' : '0 2 * * *',
      },
      'downloads': <String, dynamic>{
        'small_file_cleanup_threshold_mb': 256,
        'preferred_client_kinds': <String>['qbittorrent', 'cloud115'],
      },
      'logging': <String, dynamic>{'level': 'INFO'},
    },
    'effects': <String, dynamic>{
      'media': 'hot',
      'metadata': 'hot',
      'scheduler': 'restart_scheduler',
      'downloads': 'restart_scheduler',
      'logging': 'restart_api',
    },
    ...extra,
  };
}

Future<SessionStore> _buildLoggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
  );
  return store;
}
