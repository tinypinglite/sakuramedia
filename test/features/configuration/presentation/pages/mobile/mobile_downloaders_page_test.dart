import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_downloaders_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = await _buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('renders provider-neutral tabs and empty state', (tester) async {
    _enqueueData(bundle, clients: const [], libraries: const []);
    await _pumpPage(tester, bundle);

    expect(
      find.byKey(const Key('mobile-settings-downloaders')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-downloaders-tab-downloaders')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-downloaders-tab-guide')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-downloaders-empty-state')),
      findsOneWidget,
    );
    expect(find.text('还没有下载器配置'), findsOneWidget);
  });

  testWidgets('shows provider and media library summaries', (tester) async {
    _enqueueData(bundle, clients: [_clientJson()], libraries: [_libraryJson()]);
    await _pumpPage(tester, bundle);

    expect(find.text('Downloader A'), findsOneWidget);
    expect(find.byKey(const Key('mobile-downloader-card-1')), findsOneWidget);
  });

  testWidgets(
    'editing a downloader keeps its library when the provider catalog is unavailable',
    (tester) async {
      final client = _clientJson(
        providerConfig: const <String, dynamic>{'endpoint': 'http://old'},
      );
      final library = _libraryJson(providerKey: 'missing-provider');
      _enqueueData(
        bundle,
        clients: [client],
        libraries: [library],
        providerCatalogError: true,
      );
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/download-clients/1',
        body: _clientJson(
          providerConfig: const <String, dynamic>{'endpoint': 'http://old'},
        ),
      );

      await _pumpPage(tester, bundle);
      expect(
        find.byKey(const Key('mobile-downloaders-provider-catalog-error')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('mobile-downloader-card-body-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('download-client-media-library-field')),
        findsOneWidget,
      );
      expect(find.text('Main Library'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('download-client-name-field')),
        'Renamed downloader',
      );
      await tester.tap(
        find.byKey(const Key('mobile-downloader-submit-button')),
      );
      await tester.pumpAndSettle();

      final patchRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'PATCH' && request.path == '/download-clients/1',
      );
      expect(patchRequest.body, <String, dynamic>{
        'name': 'Renamed downloader',
        'library_id': 1,
      });
      await tester.pump(const Duration(seconds: 3));
    },
  );
}

Future<void> _pumpPage(WidgetTester tester, TestApiBundle bundle) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: MobileDownloadersPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _enqueueData(
  TestApiBundle bundle, {
  required List<Map<String, dynamic>> clients,
  required List<Map<String, dynamic>> libraries,
  List<Map<String, dynamic>>? providers,
  bool providerCatalogError = false,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    body: clients,
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: libraries,
  );
  if (providerCatalogError) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries/providers',
      statusCode: 500,
      body: const <String, dynamic>{'message': 'Provider catalog unavailable'},
    );
  } else {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries/providers',
      body:
          providers ??
          [
            {
              'provider_key': 'demo',
              'display_name': 'Provider A',
              'library_config_fields': const [],
              'download_config_fields': const [],
            },
          ],
    );
  }
}

Map<String, dynamic> _clientJson({
  Map<String, dynamic> providerConfig = const {'endpoint': 'http://demo'},
}) => {
  'id': 1,
  'name': 'Downloader A',
  'library_id': 1,
  'provider_config': providerConfig,
  'created_at': '2026-03-08T09:30:00Z',
  'updated_at': '2026-03-08T10:30:00Z',
};

Map<String, dynamic> _libraryJson({String providerKey = 'demo'}) => {
  'id': 1,
  'name': 'Main Library',
  'provider_key': providerKey,
  'provider_config': {'root': '/media'},
  'created_at': '2026-03-08T09:30:00Z',
  'updated_at': '2026-03-08T10:30:00Z',
};

Future<SessionStore> _buildLoggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'mobile-access-token',
    refreshToken: 'mobile-refresh-token',
    expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
  );
  return store;
}
