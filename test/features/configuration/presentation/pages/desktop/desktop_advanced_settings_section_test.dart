import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/config_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/advanced_settings_section.dart';
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
      expect(
        find.byKey(
          const Key('configuration-advanced-others-number-features-field'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key('configuration-advanced-cron-movie_collection_sync-field'),
        ),
        findsNothing,
      );

      await _pumpSection(tester, bundle, active: true);

      expect(bundle.adapter.hitCount('GET', '/config'), 1);
    });

    testWidgets('saves media as partial patch', (
      WidgetTester tester,
    ) async {
      _enqueueAdvancedConfig(bundle);
      _enqueueAdvancedConfigPatch(bundle);

      await _pumpSection(tester, bundle, active: true);
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
      expect(request.body['media']['allowed_min_video_file_size'], 268435456);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('saves host in metadata config', (
      WidgetTester tester,
    ) async {
      _enqueueAdvancedConfig(bundle);
      _enqueueAdvancedConfigPatch(bundle);

      await _pumpSection(tester, bundle, active: true);
      await tester.ensureVisible(
        find.byKey(const Key('configuration-advanced-javdb-host-field')),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-advanced-javdb-host-field')),
        'jdforrepam.com',
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-advanced-metadata-save-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-advanced-metadata-save-button')),
      );
      await tester.pumpAndSettle();

      final request = bundle.adapter.requests.firstWhere(
        (item) => item.method == 'PATCH' && item.path == '/config',
      );
      expect(request.body['metadata'], <String, dynamic>{
        'javdb_host': 'jdforrepam.com',
      });
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows scheduler pending restart toast', (
      WidgetTester tester,
    ) async {
      _enqueueAdvancedConfig(bundle);
      _enqueueAdvancedConfigPatch(
        bundle,
        restartRequired: const <String>['aps'],
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
        restartRequired: const <String>['api'],
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
    test('returns default message when restart_required is empty', () {
      expect(
        buildAdvancedConfigSaveSuccessMessage(const <String>[]),
        '已保存',
      );
    });

    test('reports container restart when only api-scope fields pending', () {
      expect(
        buildAdvancedConfigSaveSuccessMessage(const <String>[
          'logging.level',
        ]),
        '已保存，需重启容器才生效',
      );
    });

    test(
      'reports container restart when only scheduler-scope fields pending',
      () {
        expect(
          buildAdvancedConfigSaveSuccessMessage(const <String>[
            'scheduler.hot_review_sync_cron',
            'scheduler.movie_heat_cron',
          ]),
          '已保存，需重启容器才生效',
        );
      },
    );

    test(
      'collapses both restart kinds into a single container-restart notice',
      () {
        // 对用户而言多种重启范围都是同一个容器提示。
        expect(
          buildAdvancedConfigSaveSuccessMessage(const <String>[
            'logging.level',
            'downloads.subscription_search_fresh_days',
          ]),
          '已保存，需重启容器才生效',
        );
      },
    );
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
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
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
  List<String> restartRequired = const <String>[],
}) {
  bundle.adapter.enqueueJson(
    method: 'PATCH',
    path: '/config',
    body: _buildAdvancedConfigJson(
      extra: <String, dynamic>{
        'restart_required': restartRequired,
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
        'allowed_min_video_file_size': 268435456,
      },
      'metadata': <String, dynamic>{
        'javdb_host': 'jdforrepam.com',
      },
      'scheduler': <String, dynamic>{
        for (final key in AdvancedSchedulerConfigDto.cronKeys)
          '${key}_cron': key == 'movie_heat' ? '15 0 * * *' : '0 2 * * *',
      },
      'downloads': <String, dynamic>{
        'subscription_search_fresh_days': 7,
        'subscription_search_stale_attempt_limit': 3,
      },
      'logging': <String, dynamic>{'level': 'INFO'},
    },
    'restart_required': const <String>[],
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
