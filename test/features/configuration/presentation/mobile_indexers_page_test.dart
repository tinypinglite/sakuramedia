import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/mobile_indexers_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';

import '../../../support/test_api_bundle.dart';

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
  });

  testWidgets(
    'renders overview card, api key card, empty state and disabled create action',
    (WidgetTester tester) async {
      _enqueueIndexersData(
        _bundle,
        clients: const <Map<String, dynamic>>[],
        indexers: const <Map<String, dynamic>>[],
      );

      await _pumpPage(tester);

      expect(find.byKey(const Key('mobile-settings-indexers')), findsOneWidget);
      expect(
        find.byKey(const Key('mobile-indexers-overview-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mobile-indexers-api-key-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mobile-indexers-empty-state')),
        findsOneWidget,
      );
      expect(find.text('还没有索引器配置'), findsOneWidget);
      expect(
        find.byKey(const Key('mobile-indexers-guide-downloaders')),
        findsOneWidget,
      );
      final createButton = tester.widget<AppButton>(
        find.byKey(const Key('mobile-indexers-create-button')),
      );
      expect(createButton.onPressed, isNull);
    },
  );

  testWidgets('shows load error and retries to empty state', (
    WidgetTester tester,
  ) async {
    _bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/indexer-settings',
      responder: (_, __) async {
        return ResponseBody.fromString(
          jsonEncode({
            'error': <String, dynamic>{
              'code': 'server_error',
              'message': '索引器加载失败，请稍后重试。',
            },
          }),
          500,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients',
      body: const <Map<String, dynamic>>[],
    );
    _enqueueIndexersData(
      _bundle,
      clients: const <Map<String, dynamic>>[],
      indexers: const <Map<String, dynamic>>[],
    );

    await _pumpPage(tester);

    expect(
      find.byKey(const Key('mobile-indexers-error-state')),
      findsOneWidget,
    );
    expect(find.text('索引器加载失败，请稍后重试。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-indexers-retry-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-indexers-empty-state')),
      findsOneWidget,
    );
  });

  testWidgets('pull to refresh failure keeps current list and shows toast', (
    WidgetTester tester,
  ) async {
    final downloadClientsApi = _StaticDownloadClientsApi(
      apiClient: _bundle.apiClient,
      clients: <DownloadClientDto>[
        DownloadClientDto.fromJson(_buildClientJson()),
      ],
    );
    final indexerSettingsApi = _RefreshFailureIndexerSettingsApi(
      apiClient: _bundle.apiClient,
      initialSettings: IndexerSettingsDto.fromJson(
        _buildSettingsJson(
          apiKey: 'secret-key',
          indexers: const <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'name': '馒头',
              'url': 'https://mt.example/api',
              'kind': 'pt',
              'download_client_id': 1,
              'download_client_name': 'client-a',
            },
          ],
        ),
      ),
    );

    await _pumpPage(
      tester,
      downloadClientsApi: downloadClientsApi,
      indexerSettingsApi: indexerSettingsApi,
    );

    expect(find.text('馒头'), findsOneWidget);

    final refresh = tester.widget<AppPullToRefresh>(
      find.byType(AppPullToRefresh),
    );
    await refresh.onRefresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('馒头'), findsOneWidget);
    expect(find.text('索引器加载失败，请稍后重试。'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('saves api key and updates overview state', (
    WidgetTester tester,
  ) async {
    _enqueueIndexersData(
      _bundle,
      clients: _defaultClients,
      apiKey: '',
      indexers: const <Map<String, dynamic>>[],
    );
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/indexer-settings',
      body: _buildSettingsJson(
        apiKey: 'secret-key',
        indexers: const <Map<String, dynamic>>[],
      ),
    );

    await _pumpPage(tester);

    await tester.enterText(
      find.byKey(const Key('mobile-indexers-api-key-field')),
      'secret-key',
    );
    await tester.tap(
      find.byKey(const Key('mobile-indexers-api-key-save-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = _bundle.adapter.requests.firstWhere(
      (request) =>
          request.method == 'PATCH' && request.path == '/indexer-settings',
    );
    expect(patchRequest.body['api_key'], 'secret-key');
    expect(find.text('已配置'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('blocks saving empty api key', (WidgetTester tester) async {
    _enqueueIndexersData(
      _bundle,
      clients: _defaultClients,
      apiKey: '',
      indexers: const <Map<String, dynamic>>[],
    );

    await _pumpPage(tester);

    await tester.tap(
      find.byKey(const Key('mobile-indexers-api-key-save-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('请输入 API Key'), findsOneWidget);
    expect(_bundle.adapter.hitCount('PATCH', '/indexer-settings'), 0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('creates indexer and submits bound download client id', (
    WidgetTester tester,
  ) async {
    _enqueueIndexersData(
      _bundle,
      clients: _defaultClients,
      apiKey: 'secret-key',
      indexers: const <Map<String, dynamic>>[],
    );
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/indexer-settings',
      body: _buildSettingsJson(
        apiKey: 'secret-key',
        indexers: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 2,
            'name': 'M-Team',
            'url': 'https://mteam.example/api',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'client-a',
          },
        ],
      ),
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-indexers-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('indexer-entry-name-field')),
      'M-Team',
    );
    await tester.enterText(
      find.byKey(const Key('indexer-entry-url-field')),
      'https://mteam.example/api',
    );
    await tester.tap(find.text('PT (私有)').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('indexer-entry-download-client-field')),
    );
    await tester.tap(
      find.byKey(const Key('indexer-entry-download-client-field')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('client-a').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-indexer-submit-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = _bundle.adapter.requests.firstWhere(
      (request) =>
          request.method == 'PATCH' && request.path == '/indexer-settings',
    );
    expect(patchRequest.body['indexers'][0]['download_client_id'], 1);
    expect(find.text('M-Team'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('opens detail drawer and edits indexer', (
    WidgetTester tester,
  ) async {
    _enqueueIndexersData(_bundle, apiKey: 'secret-key');
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/indexer-settings',
      body: _buildSettingsJson(
        apiKey: 'secret-key',
        indexers: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': '馒头-更新',
            'url': 'https://mt-updated.example/api',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'client-a',
          },
        ],
      ),
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-indexer-card-body-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-indexer-detail-drawer')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('mobile-indexer-detail-edit-button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('indexer-entry-name-field')),
      '馒头-更新',
    );
    await tester.enterText(
      find.byKey(const Key('indexer-entry-url-field')),
      'https://mt-updated.example/api',
    );
    await tester.tap(find.byKey(const Key('mobile-indexer-submit-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = _bundle.adapter.requests.firstWhere(
      (request) =>
          request.method == 'PATCH' && request.path == '/indexer-settings',
    );
    expect(patchRequest.body['indexers'][0]['name'], '馒头-更新');
    expect(find.text('馒头-更新'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('deletes indexer from detail action after confirm', (
    WidgetTester tester,
  ) async {
    _enqueueIndexersData(_bundle, apiKey: 'secret-key');
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/indexer-settings',
      body: _buildSettingsJson(
        apiKey: 'secret-key',
        indexers: const <Map<String, dynamic>>[],
      ),
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-indexer-card-body-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mobile-indexer-detail-delete-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mobile-indexer-delete-confirm-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_bundle.adapter.hitCount('PATCH', '/indexer-settings'), 1);
    expect(find.text('还没有索引器配置'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'validates duplicate name, invalid url and missing download client',
    (WidgetTester tester) async {
      _enqueueIndexersData(_bundle, apiKey: 'secret-key');

      await _pumpPage(tester);

      await tester.tap(find.byKey(const Key('mobile-indexers-create-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('indexer-entry-name-field')),
        '馒头',
      );
      await tester.enterText(
        find.byKey(const Key('indexer-entry-url-field')),
        'not-url',
      );
      await tester.tap(find.byKey(const Key('mobile-indexer-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('索引器名称重复'), findsOneWidget);
      expect(find.text('请输入合法的 http/https 地址'), findsOneWidget);
    expect(find.text('请选择下载器'), findsWidgets);
      expect(_bundle.adapter.hitCount('PATCH', '/indexer-settings'), 0);
    },
  );

  testWidgets(
    'shows invalid binding warning and can rebind to existing client',
    (WidgetTester tester) async {
      _enqueueIndexersData(
        _bundle,
        apiKey: 'secret-key',
        indexers: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': '失效索引器',
            'url': 'https://broken.example/api',
            'kind': 'bt',
            'download_client_id': 99,
            'download_client_name': 'missing-client',
          },
        ],
      );
      _bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/indexer-settings',
        body: _buildSettingsJson(
          apiKey: 'secret-key',
          indexers: const <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'name': '失效索引器',
              'url': 'https://broken.example/api',
              'kind': 'bt',
              'download_client_id': 1,
              'download_client_name': 'client-a',
            },
          ],
        ),
      );

      await _pumpPage(tester);

      expect(
        find.byKey(const Key('mobile-indexer-invalid-binding-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('mobile-indexer-card-body-1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('mobile-indexer-detail-edit-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('indexer-entry-download-client-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('client-a').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-indexer-submit-button')));
      await tester.pump();
      await tester.pumpAndSettle();

      final patchRequest = _bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'PATCH' && request.path == '/indexer-settings',
      );
      expect(patchRequest.body['indexers'][0]['download_client_id'], 1);
      expect(
        find.byKey(const Key('mobile-indexer-invalid-binding-1')),
        findsNothing,
      );
      expect(find.text('绑定下载器: client-a'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  DownloadClientsApi? downloadClientsApi,
  IndexerSettingsApi? indexerSettingsApi,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<DownloadClientsApi>.value(
          value: downloadClientsApi ?? _bundle.downloadClientsApi,
        ),
        Provider<IndexerSettingsApi>.value(
          value: indexerSettingsApi ?? _bundle.indexerSettingsApi,
        ),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: MobileIndexersPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _enqueueIndexersData(
  TestApiBundle bundle, {
  List<Map<String, dynamic>>? clients,
  String apiKey = '',
  List<Map<String, dynamic>>? indexers,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    body: clients ?? _defaultClients,
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/indexer-settings',
    body: _buildSettingsJson(apiKey: apiKey, indexers: indexers),
  );
}

Map<String, dynamic> _buildSettingsJson({
  String apiKey = '',
  List<Map<String, dynamic>>? indexers,
}) {
  return <String, dynamic>{
    'type': 'jackett',
    'api_key': apiKey,
    'indexers':
        indexers ??
        const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': '馒头',
            'url': 'https://mt.example/api',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'client-a',
          },
        ],
  };
}

Map<String, dynamic> _buildClientJson({int id = 1, String name = 'client-a'}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'base_url': 'http://qb.local:8080',
    'username': 'alice',
    'client_save_path': '/downloads/a',
    'local_root_path': '/mnt/downloads/a',
    'media_library_id': 1,
    'has_password': true,
    'created_at': '2026-03-08T09:30:00Z',
    'updated_at': '2026-03-08T10:30:00Z',
  };
}

const List<Map<String, dynamic>> _defaultClients = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 1,
    'name': 'client-a',
    'base_url': 'http://qb.local:8080',
    'username': 'alice',
    'client_save_path': '/downloads/a',
    'local_root_path': '/mnt/downloads/a',
    'media_library_id': 1,
    'has_password': true,
    'created_at': '2026-03-08T09:30:00Z',
    'updated_at': '2026-03-08T10:30:00Z',
  },
];

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

class _StaticDownloadClientsApi extends DownloadClientsApi {
  _StaticDownloadClientsApi({required super.apiClient, required this.clients});

  final List<DownloadClientDto> clients;

  @override
  Future<List<DownloadClientDto>> getClients() async {
    return clients;
  }
}

class _RefreshFailureIndexerSettingsApi extends IndexerSettingsApi {
  _RefreshFailureIndexerSettingsApi({
    required super.apiClient,
    required this.initialSettings,
  });

  final IndexerSettingsDto initialSettings;
  int _requestCount = 0;

  @override
  Future<IndexerSettingsDto> getSettings() async {
    _requestCount += 1;
    if (_requestCount == 1) {
      return initialSettings;
    }
    throw Exception('refresh failed');
  }
}
