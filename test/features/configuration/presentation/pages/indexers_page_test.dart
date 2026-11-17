import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/indexers_page.dart';
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

  testWidgets('desktop page lists indexers and opens the shared editor', (
    tester,
  ) async {
    _enqueueIndexers(bundle);

    await pumpPreviewApp(
      tester,
      home: const IndexersPage(mobile: false),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('indexer-entry-card-0')), findsOneWidget);
    expect(
      find.byKey(const Key('configuration-indexer-connection-test-panel')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('configuration-indexer-create-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('indexer-entry-name-field')), findsOneWidget);
    expect(bundle.adapter.hitCount('GET', '/indexer-settings'), 1);
    expect(bundle.adapter.hitCount('GET', '/download-clients'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile page lists indexers, opens detail and create editor', (
    tester,
  ) async {
    _enqueueIndexers(bundle);

    await pumpPreviewApp(
      tester,
      home: const IndexersPage(mobile: true),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-settings-indexers')), findsOneWidget);
    expect(find.byKey(const Key('mobile-indexer-card-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-indexer-card-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-indexer-detail-edit-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-indexer-detail-delete-button')),
      findsOneWidget,
    );

    Navigator.of(
      tester.element(
        find.byKey(const Key('mobile-indexer-detail-edit-button')),
      ),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-indexers-create-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('indexer-entry-name-field')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-indexer-submit-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive desktop page does not load either source', (
    tester,
  ) async {
    _enqueueIndexers(bundle);

    await pumpPreviewApp(
      tester,
      home: const IndexersPage(mobile: false, active: false),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pump();

    expect(bundle.adapter.hitCount('GET', '/indexer-settings'), 0);
    expect(bundle.adapter.hitCount('GET', '/download-clients'), 0);
  });

  testWidgets('desktop page exposes retry after a failed indexer load', (
    tester,
  ) async {
    _enqueueIndexers(bundle, settingsStatusCode: 500);

    await pumpPreviewApp(
      tester,
      home: const IndexersPage(mobile: false),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('indexers-error-state')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop edit saves once and closes the dialog', (tester) async {
    _enqueueIndexers(bundle);

    await pumpPreviewApp(
      tester,
      home: const IndexersPage(mobile: false),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('indexer-entry-edit-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('indexer-entry-name-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('indexer-entry-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('indexer-entry-name-field')), findsNothing);
    expect(bundle.adapter.hitCount('PATCH', '/indexer-settings'), 1);
    await _drainToast(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile editor stays open when save fails', (tester) async {
    _enqueueIndexers(bundle, saveStatusCode: 500);

    await pumpPreviewApp(
      tester,
      home: const IndexersPage(mobile: true),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-indexer-card-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mobile-indexer-detail-edit-button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-indexer-submit-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-indexer-submit-button')),
      findsOneWidget,
    );
    expect(bundle.adapter.hitCount('PATCH', '/indexer-settings'), 1);
    await _drainToast(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile delete keeps confirmation open when save fails', (
    tester,
  ) async {
    _enqueueIndexers(bundle, saveStatusCode: 500);

    await pumpPreviewApp(
      tester,
      home: const IndexersPage(mobile: true),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-indexer-card-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mobile-indexer-detail-delete-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-indexer-delete-confirm-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('mobile-indexer-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-indexer-delete-confirm-button')),
      findsOneWidget,
    );
    expect(bundle.adapter.hitCount('PATCH', '/indexer-settings'), 1);
    await _drainToast(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile delete does not validate unrelated entries', (
    tester,
  ) async {
    final indexers = <Map<String, dynamic>>[
      _indexerJson(id: 1, name: 'MTeam', url: 'https://indexer.example.com'),
      _indexerJson(id: 2, name: 'Broken', url: 'ftp://invalid.example.com'),
    ];
    _enqueueIndexers(
      bundle,
      indexers: indexers,
      savedIndexers: <Map<String, dynamic>>[indexers[1]],
    );

    await pumpPreviewApp(
      tester,
      home: const IndexersPage(mobile: true),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-indexer-card-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mobile-indexer-detail-delete-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mobile-indexer-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('PATCH', '/indexer-settings'), 1);
    expect(find.byKey(const Key('mobile-indexer-card-2')), findsOneWidget);
    await _drainToast(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop delete closes confirmation before a failed save', (
    tester,
  ) async {
    _enqueueIndexers(bundle, saveStatusCode: 500);

    await pumpPreviewApp(
      tester,
      home: const IndexersPage(mobile: false),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('indexer-entry-delete-0')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('configuration-indexer-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('configuration-indexer-delete-confirm-button')),
      findsNothing,
    );
    expect(bundle.adapter.hitCount('PATCH', '/indexer-settings'), 1);
    await _drainToast(tester);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _indexerJson({
  required int id,
  required String name,
  required String url,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'url': url,
    'kind': 'pt',
    'api_key': null,
    'download_clients': <Map<String, dynamic>>[
      <String, dynamic>{'id': 1, 'name': 'qB'},
    ],
  };
}

void _enqueueIndexers(
  TestApiBundle bundle, {
  int settingsStatusCode = 200,
  int saveStatusCode = 200,
  List<Map<String, dynamic>>? indexers,
  List<Map<String, dynamic>>? savedIndexers,
}) {
  final entries =
      indexers ??
      <Map<String, dynamic>>[
        _indexerJson(id: 1, name: 'MTeam', url: 'https://indexer.example.com'),
      ];
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/indexer-settings',
    statusCode: settingsStatusCode,
    body: settingsStatusCode == 200
        ? <String, dynamic>{'indexers': entries}
        : <String, dynamic>{'detail': 'failed'},
  );
  bundle.adapter.enqueueJson(
    method: 'PATCH',
    path: '/indexer-settings',
    statusCode: saveStatusCode,
    body: saveStatusCode == 200
        ? <String, dynamic>{'indexers': savedIndexers ?? entries}
        : <String, dynamic>{'detail': 'failed'},
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': 'qB',
        'library_id': 1,
        'provider_config': <String, dynamic>{'endpoint': 'http://qb'},
        'created_at': '2026-03-08T09:30:00Z',
        'updated_at': '2026-03-08T10:30:00Z',
      },
    ],
  );
}
