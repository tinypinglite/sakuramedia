import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/downloaders_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('desktop page lists clients and opens the shared editor', (
    tester,
  ) async {
    _enqueueDownloaders(bundle);

    await pumpPreviewApp(
      tester,
      home: const DownloadersPage(mobile: false),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('download-client-card-1')), findsOneWidget);
    expect(find.text('qB'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('configuration-download-client-create-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('download-client-name-field')), findsOneWidget);
    expect(
      find.byKey(const Key('download-client-test-button')),
      findsOneWidget,
    );
    expect(bundle.adapter.hitCount('GET', '/download-clients'), 1);
    expect(bundle.adapter.hitCount('GET', '/media-libraries'), 1);
    expect(bundle.adapter.hitCount('GET', '/media-libraries/providers'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile page lists clients, switches guide tab and opens editor',
    (tester) async {
      _enqueueDownloaders(bundle);

      await pumpPreviewApp(
        tester,
        home: const DownloadersPage(mobile: true),
        size: const Size(390, 844),
        theme: buildSakuraMobileThemeData(),
        platform: TargetPlatform.android,
        appPlatform: AppPlatform.mobile,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mobile-settings-downloaders')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mobile-downloader-card-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mobile-downloaders-tab-guide')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('mobile-downloaders-guide-step-libraries')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('mobile-downloaders-create-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('download-client-name-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mobile-downloader-submit-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mobile-downloader-test-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inactive desktop page does not load any source', (tester) async {
    _enqueueDownloaders(bundle);

    await pumpPreviewApp(
      tester,
      home: const DownloadersPage(mobile: false, active: false),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pump();

    expect(bundle.adapter.hitCount('GET', '/download-clients'), 0);
    expect(bundle.adapter.hitCount('GET', '/media-libraries'), 0);
    expect(bundle.adapter.hitCount('GET', '/media-libraries/providers'), 0);
  });

  testWidgets('desktop page exposes retry after a failed client load', (
    tester,
  ) async {
    _enqueueDownloaders(bundle, clientStatusCode: 500);

    await pumpPreviewApp(
      tester,
      home: const DownloadersPage(mobile: false),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('downloaders-error-state')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _enqueueDownloaders(TestApiBundle bundle, {int clientStatusCode = 200}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    statusCode: clientStatusCode,
    body: clientStatusCode == 200
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'name': 'qB',
              'library_id': 1,
              'provider_config': <String, dynamic>{'endpoint': 'http://qb'},
              'created_at': '2026-03-08T09:30:00Z',
              'updated_at': '2026-03-08T10:30:00Z',
            },
          ]
        : <String, dynamic>{'detail': 'failed'},
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': 'Main library',
        'provider_key': 'demo',
        'provider_config': <String, dynamic>{'root': '/media/main'},
        'created_at': '2026-03-08T09:30:00Z',
        'updated_at': '2026-03-08T10:30:00Z',
      },
    ],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries/providers',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'provider_key': 'demo',
        'display_name': 'Demo provider',
        'library_config_fields': <dynamic>[],
        'download_config_fields': <dynamic>[],
      },
    ],
  );
}
