import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/api/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_indexers_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pull_to_refresh.dart';

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
  });

  testWidgets(
    'renders overview card, connection test card, empty state and disabled create action',
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
        find.byKey(const Key('mobile-indexers-connection-test-card')),
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

  testWidgets('shows per-indexer API Key status in card and detail drawer', (
    WidgetTester tester,
  ) async {
    _enqueueIndexersData(
      _bundle,
      indexers: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': '馒头',
          'url': 'https://mt.example/api',
          'kind': 'pt',
          'api_key': 'secret-key',
          'download_client_id': 1,
          'download_client_name': 'client-a',
        },
        <String, dynamic>{
          'id': 2,
          'name': 'dmhy',
          'url': 'https://dmhy.example/api',
          'kind': 'bt',
          'api_key': null,
          'download_client_id': 1,
          'download_client_name': 'client-a',
        },
      ],
    );

    await _pumpPage(tester);

    expect(find.text('API Key: 已配置'), findsOneWidget);
    expect(find.text('API Key: 未配置'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-indexer-card-body-1')));
    await tester.pumpAndSettle();

    expect(find.text('已配置'), findsWidgets);
    expect(find.byKey(const Key('mobile-indexer-detail-drawer')), findsOneWidget);
  });

  testWidgets('tests saved Torznab settings and shows the result', (
    WidgetTester tester,
  ) async {
    _enqueueIndexersData(_bundle);
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/indexer-settings/test',
      body: <String, dynamic>{
        'healthy': true,
        'checked_at': '2026-07-11T08:00:00Z',
        'query': 'SSNI-888',
        'indexers_checked': 1,
        'result_count': 0,
        'elapsed_ms': 30,
        'error': null,
      },
    );

    await _pumpPage(tester);
    await tester.tap(
      find.byKey(const Key('mobile-indexers-connection-test-button')),
    );
    await tester.pumpAndSettle();

    expect(_bundle.adapter.hitCount('GET', '/indexer-settings/test'), 1);
    expect(
      find.byKey(const Key('mobile-indexers-connection-test-result')),
      findsOneWidget,
    );
    expect(find.text('Torznab 已连通，测试查询未返回候选。'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shows Torznab connection failure details', (
    WidgetTester tester,
  ) async {
    _enqueueIndexersData(_bundle);
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/indexer-settings/test',
      body: <String, dynamic>{
        'healthy': false,
        'checked_at': '2026-07-11T08:00:00Z',
        'query': 'SSNI-888',
        'indexers_checked': 1,
        'result_count': 0,
        'elapsed_ms': 30,
        'error': <String, dynamic>{
          'type': 'torznab_request_error',
          'message': 'connection refused',
        },
      },
    );

    await _pumpPage(tester);
    await tester.tap(
      find.byKey(const Key('mobile-indexers-connection-test-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-indexers-connection-test-result')),
      findsOneWidget,
    );
    expect(find.text('connection refused'), findsOneWidget);
    expect(find.text('torznab_request_error'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shows a repair hint when the connection request fails', (
    WidgetTester tester,
  ) async {
    _enqueueIndexersData(_bundle);
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/indexer-settings/test',
      statusCode: 500,
      body: <String, dynamic>{'message': 'service unavailable'},
    );

    await _pumpPage(tester);
    await tester.tap(
      find.byKey(const Key('mobile-indexers-connection-test-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppStatusChip), findsOneWidget);
    expect(find.text('请检查 Torznab 服务、API Key 和索引器地址后重试。'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('creates indexer and submits bound download client id', (
    WidgetTester tester,
  ) async {
    _enqueueIndexersData(
      _bundle,
      clients: _defaultClients,
      indexers: const <Map<String, dynamic>>[],
    );
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/indexer-settings',
      body: _buildSettingsJson(
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
    await tester.enterText(
      find.byKey(const Key('indexer-entry-api-key-field')),
      'secret-key',
    );
    await tester.tap(find.text('PT (私有)').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('indexer-download-client-1')),
    );
    await tester.tap(find.byKey(const Key('indexer-download-client-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('mobile-indexer-submit-button')),
    );
    await tester.tap(find.byKey(const Key('mobile-indexer-submit-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = _bundle.adapter.requests.firstWhere(
      (request) =>
          request.method == 'PATCH' && request.path == '/indexer-settings',
    );
    expect(patchRequest.body['indexers'][0]['download_client_ids'], <int>[1]);
    expect(patchRequest.body['indexers'][0]['api_key'], 'secret-key');
    expect(find.text('M-Team'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('BT indexer can bind qBittorrent and cloud115 together', (
    WidgetTester tester,
  ) async {
    _enqueueIndexersData(
      _bundle,
      clients: <Map<String, dynamic>>[..._defaultClients, _cloudDownloadClient],
      indexers: const <Map<String, dynamic>>[],
    );
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/indexer-settings',
      body: _buildSettingsJson(
        indexers: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 3,
            'name': 'DMHY',
            'url': 'https://dmhy.example/api',
            'kind': 'bt',
            'api_key': null,
            'download_clients': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'name': 'client-a',
                'kind': 'qbittorrent',
              },
              <String, dynamic>{'id': 8, 'name': '115 主账号', 'kind': 'cloud115'},
            ],
          },
        ],
      ),
    );

    await _pumpPage(tester);
    await tester.tap(find.byKey(const Key('mobile-indexers-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('indexer-entry-name-field')),
      'DMHY',
    );
    await tester.enterText(
      find.byKey(const Key('indexer-entry-url-field')),
      'https://dmhy.example/api',
    );
    expect(find.byKey(const Key('indexer-download-client-8')), findsNothing);
    await tester.tap(find.text('BT (公网)').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('indexer-download-client-1')),
    );
    await tester.tap(find.byKey(const Key('indexer-download-client-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('indexer-download-client-8')),
    );
    await tester.tap(find.byKey(const Key('indexer-download-client-8')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('mobile-indexer-submit-button')),
    );
    await tester.tap(find.byKey(const Key('mobile-indexer-submit-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = _bundle.adapter.requests.firstWhere(
      (request) =>
          request.method == 'PATCH' && request.path == '/indexer-settings',
    );
    expect(patchRequest.body['indexers'][0]['download_client_ids'], <int>[
      1,
      8,
    ]);
    expect(find.textContaining('client-a、115 主账号'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('opens detail drawer and edits indexer', (
    WidgetTester tester,
  ) async {
    _enqueueIndexersData(_bundle);
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/indexer-settings',
      body: _buildSettingsJson(
        indexers: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': '馒头-更新',
            'url': 'https://mt-updated.example/api',
            'kind': 'pt',
            'api_key': 'new-key',
            'download_client_id': 1,
            'download_client_name': 'client-a',
          },
        ],
      ),
    );

    await _pumpPage(tester);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
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
    await tester.enterText(
      find.byKey(const Key('indexer-entry-api-key-field')),
      'new-key',
    );
    await tester.ensureVisible(
      find.byKey(const Key('mobile-indexer-submit-button')),
    );
    await tester.tap(find.byKey(const Key('mobile-indexer-submit-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = _bundle.adapter.requests.firstWhere(
      (request) =>
          request.method == 'PATCH' && request.path == '/indexer-settings',
    );
    expect(patchRequest.body['indexers'][0]['name'], '馒头-更新');
    expect(patchRequest.body['indexers'][0]['api_key'], 'new-key');
    expect(find.text('馒头-更新'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('deletes indexer from detail action after confirm', (
    WidgetTester tester,
  ) async {
    _enqueueIndexersData(_bundle);
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/indexer-settings',
      body: _buildSettingsJson(
        indexers: const <Map<String, dynamic>>[],
      ),
    );

    await _pumpPage(tester);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
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
      _enqueueIndexersData(_bundle);

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
      await tester.ensureVisible(
        find.byKey(const Key('mobile-indexer-submit-button')),
      );
      await tester.tap(find.byKey(const Key('mobile-indexer-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('索引器名称重复'), findsOneWidget);
      expect(find.text('请输入合法的 http/https 地址'), findsOneWidget);
      expect(find.text('请至少选择一个下载器'), findsWidgets);
      expect(_bundle.adapter.hitCount('PATCH', '/indexer-settings'), 0);
    },
  );

  testWidgets(
    'shows invalid binding warning and can rebind to existing client',
    (WidgetTester tester) async {
      _enqueueIndexersData(
        _bundle,
        indexers: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': '失效索引器',
            'url': 'https://broken.example/api',
            'kind': 'bt',
            'api_key': null,
            'download_client_id': 99,
            'download_client_name': 'missing-client',
          },
        ],
      );
      _bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/indexer-settings',
        body: _buildSettingsJson(
          indexers: const <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'name': '失效索引器',
              'url': 'https://broken.example/api',
              'kind': 'bt',
              'api_key': null,
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

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-indexer-card-body-1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('mobile-indexer-detail-edit-button')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('indexer-download-client-1')),
      );
      await tester.tap(find.byKey(const Key('indexer-download-client-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('mobile-indexer-submit-button')),
      );
      await tester.tap(find.byKey(const Key('mobile-indexer-submit-button')));
      await tester.pump();
      await tester.pumpAndSettle();

      final patchRequest = _bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'PATCH' && request.path == '/indexer-settings',
      );
      expect(patchRequest.body['indexers'][0]['download_client_ids'], <int>[1]);
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
    ProviderScope(
      overrides: _bundle.riverpodOverrides(
        downloadClientsApi: downloadClientsApi,
        indexerSettingsApi: indexerSettingsApi,
      ),
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
    body: _buildSettingsJson(indexers: indexers),
  );
}

Map<String, dynamic> _buildSettingsJson({
  List<Map<String, dynamic>>? indexers,
}) {
  return <String, dynamic>{
    'indexers': (indexers ??
            const <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'name': '馒头',
                'url': 'https://mt.example/api',
                'kind': 'pt',
                'api_key': 'secret-key',
                'download_client_id': 1,
                'download_client_name': 'client-a',
              },
            ])
        .map((entry) {
          final withApiKey = <String, dynamic>{
            ...entry,
            'api_key': entry.containsKey('api_key') ? entry['api_key'] : 'secret-key',
          };
          if (entry.containsKey('download_clients')) return withApiKey;
          return <String, dynamic>{
            ...withApiKey,
            'download_clients': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': entry['download_client_id'],
                'name': entry['download_client_name'],
                'kind': 'qbittorrent',
              },
            ],
          };
        })
        .toList(growable: false),
  };
}

Map<String, dynamic> _buildClientJson({int id = 1, String name = 'client-a'}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'kind': 'qbittorrent',
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
    'kind': 'qbittorrent',
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

const Map<String, dynamic> _cloudDownloadClient = <String, dynamic>{
  'id': 8,
  'name': '115 主账号',
  'kind': 'cloud115',
  'base_url': null,
  'username': null,
  'client_save_path': null,
  'local_root_path': null,
  'media_library_id': 8,
  'has_password': false,
  'created_at': '2026-07-15T08:00:00Z',
  'updated_at': '2026-07-15T08:00:00Z',
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
