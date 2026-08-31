import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_media_libraries_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

late SessionStore _sessionStore;
late TestApiBundle _bundle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _sessionStore = await _buildLoggedInSessionStore();
    _bundle = await createTestApiBundle(_sessionStore);
  });

  tearDown(() {
    _bundle.dispose();
    _sessionStore.dispose();
  });

  testWidgets('renders generic notice, provider catalog and empty state', (
    tester,
  ) async {
    _enqueueCatalog(
      _bundle,
      providers: const <Map<String, dynamic>>[_demoProvider],
    );
    _enqueueMediaLibraries(_bundle, libraries: const <Map<String, dynamic>>[]);

    await _pumpPage(tester);

    expect(find.text('媒体库存储'), findsOneWidget);
    expect(find.text('还没有媒体库'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-media-libraries-create-button')),
      findsOneWidget,
    );
  });

  testWidgets('guides the user when provider catalog is empty', (tester) async {
    _enqueueCatalog(_bundle, providers: const <Map<String, dynamic>>[]);
    _enqueueMediaLibraries(_bundle, libraries: const <Map<String, dynamic>>[]);

    await _pumpPage(tester);

    expect(find.textContaining('暂无可用 Provider'), findsOneWidget);
  });

  testWidgets('creates a library with provider key and dynamic config', (
    tester,
  ) async {
    _enqueueCatalog(
      _bundle,
      providers: const <Map<String, dynamic>>[_demoProvider],
    );
    _enqueueMediaLibraries(_bundle, libraries: const <Map<String, dynamic>>[]);
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/media-libraries',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 2,
        'name': 'Archive',
        'provider_key': 'demo',
        'provider_config': <String, dynamic>{'root': '/media/archive'},
        'created_at': '2026-03-09T09:30:00Z',
        'updated_at': '2026-03-09T09:30:00Z',
      },
    );

    await _pumpPage(tester);
    await tester.tap(
      find.byKey(const Key('mobile-media-libraries-create-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('media-library-name-field')),
      'Archive',
    );
    await tester.enterText(
      find.byKey(const Key('provider-config-field-root')),
      '/media/archive',
    );
    await tester.tap(
      find.byKey(const Key('mobile-media-library-submit-button')),
    );
    await tester.pumpAndSettle();

    final post = _bundle.adapter.requests.singleWhere(
      (request) =>
          request.method == 'POST' && request.path == '/media-libraries',
    );
    expect(post.body, <String, dynamic>{
      'name': 'Archive',
      'provider_key': 'demo',
      'provider_config': <String, dynamic>{'root': '/media/archive'},
    });
    expect(find.text('Demo Provider'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('editing omits an empty secret and keeps provider locked', (
    tester,
  ) async {
    _enqueueCatalog(
      _bundle,
      providers: const <Map<String, dynamic>>[_secretProvider],
    );
    _enqueueMediaLibraries(
      _bundle,
      libraries: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'Main',
          'provider_key': 'demo-secret',
          'provider_config': <String, dynamic>{'url': 'https://example.com'},
          'created_at': '2026-03-08T09:30:00Z',
          'updated_at': '2026-03-08T10:30:00Z',
        },
      ],
    );
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/media-libraries/1',
      body: <String, dynamic>{
        'id': 1,
        'name': 'Main Updated',
        'provider_key': 'demo-secret',
        'provider_config': <String, dynamic>{'url': 'https://new.example.com'},
        'created_at': '2026-03-08T09:30:00Z',
        'updated_at': '2026-03-10T10:30:00Z',
      },
    );

    await _pumpPage(tester);
    await tester.tap(find.byKey(const Key('mobile-media-library-card-body-1')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('provider-config-field-url')),
          )
          .controller
          ?.text,
      'https://example.com',
    );
    final tokenField = find.byKey(const Key('provider-config-field-token'));
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: tokenField,
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const Key('media-library-name-field')),
      'Main Updated',
    );
    await tester.enterText(
      find.byKey(const Key('provider-config-field-url')),
      'https://new.example.com',
    );
    await tester.ensureVisible(
      find.byKey(const Key('mobile-media-library-submit-button')),
    );
    await tester.tap(
      find.byKey(const Key('mobile-media-library-submit-button')),
    );
    await tester.pumpAndSettle();

    final patch = _bundle.adapter.requests.singleWhere(
      (request) =>
          request.method == 'PATCH' && request.path == '/media-libraries/1',
    );
    expect(patch.body, <String, dynamic>{
      'name': 'Main Updated',
      'provider_config': <String, dynamic>{'url': 'https://new.example.com'},
    });
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shows a restrained unavailable provider state', (tester) async {
    _enqueueCatalog(
      _bundle,
      providers: const <Map<String, dynamic>>[_demoProvider],
    );
    _enqueueMediaLibraries(
      _bundle,
      libraries: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 9,
          'name': 'Missing',
          'provider_key': 'missing',
          'provider_config': <String, dynamic>{},
          'created_at': '2026-03-08T09:30:00Z',
          'updated_at': '2026-03-08T10:30:00Z',
        },
      ],
    );

    await _pumpPage(tester);

    expect(find.text('Provider 不可用 · missing'), findsOneWidget);
    expect(find.text('Demo Provider'), findsNothing);
  });
}

Future<void> _pumpPage(WidgetTester tester, {MediaLibrariesApi? api}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _bundle.riverpodOverrides(mediaLibrariesApi: api),
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: MobileMediaLibrariesPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _enqueueCatalog(
  TestApiBundle bundle, {
  required List<Map<String, dynamic>> providers,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries/providers',
    body: providers,
  );
}

void _enqueueMediaLibraries(
  TestApiBundle bundle, {
  required List<Map<String, dynamic>> libraries,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: libraries,
  );
}

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

const _demoProvider = <String, dynamic>{
  'provider_key': 'demo',
  'display_name': 'Demo Provider',
  'library_config_fields': <Map<String, dynamic>>[
    <String, dynamic>{
      'key': 'root',
      'label': '媒体根目录',
      'input': 'path',
      'required': true,
      'multiline': false,
      'read_only': false,
      'hint': '例如 /media/archive',
    },
  ],
  'download_config_fields': null,
};

const _secretProvider = <String, dynamic>{
  'provider_key': 'demo-secret',
  'display_name': 'Secret Provider',
  'library_config_fields': <Map<String, dynamic>>[
    <String, dynamic>{
      'key': 'url',
      'label': '服务地址',
      'input': 'text',
      'required': true,
      'multiline': false,
      'read_only': false,
      'hint': null,
    },
    <String, dynamic>{
      'key': 'token',
      'label': '访问令牌',
      'input': 'secret',
      'required': true,
      'multiline': false,
      'read_only': false,
      'hint': null,
    },
  ],
  'download_config_fields': null,
};
