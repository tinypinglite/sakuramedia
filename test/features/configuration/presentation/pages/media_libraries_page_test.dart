import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/media_libraries_page.dart';
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

  testWidgets('desktop page lists libraries and opens the shared editor', (
    tester,
  ) async {
    _enqueueMediaLibraries(bundle);

    await pumpPreviewApp(
      tester,
      home: const MediaLibrariesPage(mobile: false),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-library-card-1')), findsOneWidget);
    expect(find.text('Main library'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('configuration-media-library-create-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-library-name-field')), findsOneWidget);
    expect(find.text('新增媒体库'), findsWidgets);
    expect(bundle.adapter.hitCount('GET', '/media-libraries'), 1);
    expect(bundle.adapter.hitCount('GET', '/media-libraries/providers'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile page lists libraries and opens the shared editor', (
    tester,
  ) async {
    _enqueueMediaLibraries(bundle);

    await pumpPreviewApp(
      tester,
      home: const MediaLibrariesPage(mobile: true),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-settings-media-libraries')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-library-card-1')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('mobile-media-libraries-create-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-library-name-field')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-media-library-submit-button')),
      findsOneWidget,
    );
    expect(bundle.adapter.hitCount('GET', '/media-libraries'), 1);
    expect(bundle.adapter.hitCount('GET', '/media-libraries/providers'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive desktop tab does not load either source', (
    tester,
  ) async {
    _enqueueMediaLibraries(bundle);

    await pumpPreviewApp(
      tester,
      home: const MediaLibrariesPage(mobile: false, active: false),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pump();

    expect(bundle.adapter.hitCount('GET', '/media-libraries'), 0);
    expect(bundle.adapter.hitCount('GET', '/media-libraries/providers'), 0);
  });

  testWidgets('desktop page exposes retry after a failed library load', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );

    await pumpPreviewApp(
      tester,
      home: const MediaLibrariesPage(mobile: false),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-libraries-error-state')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

void _enqueueMediaLibraries(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': 'Main library',
        'provider_key': 'demo',
        'provider_config': <String, dynamic>{'root': '/media/main'},
        'supports_in_place_import': true,
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
        'download_config_fields': null,
      },
    ],
  );
}
