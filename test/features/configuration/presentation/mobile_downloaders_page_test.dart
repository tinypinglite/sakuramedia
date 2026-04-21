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
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/mobile_downloaders_page.dart';
import 'package:sakuramedia/theme.dart';
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

  testWidgets('renders overview card, tabs and empty state', (
    WidgetTester tester,
  ) async {
    _enqueueDownloadersData(
      _bundle,
      clients: const <Map<String, dynamic>>[],
      libraries: const <Map<String, dynamic>>[],
      indexers: const <Map<String, dynamic>>[],
    );

    await _pumpPage(tester);

    expect(
      find.byKey(const Key('mobile-settings-downloaders')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-downloaders-overview-card')),
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
    expect(
      find.byKey(const Key('mobile-downloaders-create-button')),
      findsOneWidget,
    );
  });

  testWidgets('shows load error and retries to empty state', (
    WidgetTester tester,
  ) async {
    _bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/download-clients',
      responder: (_, __) async {
        return ResponseBody.fromString(
          jsonEncode({
            'error': <String, dynamic>{
              'code': 'server_error',
              'message': '下载器加载失败，请稍后重试。',
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
      path: '/media-libraries',
      body: const <Map<String, dynamic>>[],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/indexer-settings',
      body: const <String, dynamic>{
        'type': 'builtin',
        'api_key': '',
        'indexers': <Map<String, dynamic>>[],
      },
    );
    _enqueueDownloadersData(
      _bundle,
      clients: const <Map<String, dynamic>>[],
      libraries: const <Map<String, dynamic>>[],
      indexers: const <Map<String, dynamic>>[],
    );

    await _pumpPage(tester);

    expect(
      find.byKey(const Key('mobile-downloaders-error-state')),
      findsOneWidget,
    );
    expect(find.text('下载器加载失败，请稍后重试。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-downloaders-retry-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-downloaders-empty-state')),
      findsOneWidget,
    );
  });

  testWidgets('pull to refresh failure keeps current list and shows toast', (
    WidgetTester tester,
  ) async {
    final downloadClientsApi = _RefreshFailureDownloadClientsApi(
      apiClient: _bundle.apiClient,
    );
    final mediaLibrariesApi = _StaticMediaLibrariesApi(
      apiClient: _bundle.apiClient,
      libraries: _defaultLibraries,
    );
    final indexerSettingsApi = _StaticIndexerSettingsApi(
      apiClient: _bundle.apiClient,
      settings: const IndexerSettingsDto(
        type: 'builtin',
        apiKey: '',
        indexers: <IndexerEntryDto>[],
      ),
    );

    await _pumpPage(
      tester,
      downloadClientsApi: downloadClientsApi,
      mediaLibrariesApi: mediaLibrariesApi,
      indexerSettingsApi: indexerSettingsApi,
    );

    expect(find.text('client-a'), findsOneWidget);

    final refresh = tester.widget<AppPullToRefresh>(
      find.byType(AppPullToRefresh).first,
    );
    await refresh.onRefresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('client-a'), findsOneWidget);
    expect(find.text('下载器加载失败，请稍后重试。'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('creates downloader and syncs list', (WidgetTester tester) async {
    _enqueueDownloadersData(
      _bundle,
      clients: const <Map<String, dynamic>>[],
      libraries: _defaultLibraries,
      indexers: const <Map<String, dynamic>>[],
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-clients',
      body: _buildClientJson(id: 2, name: 'client-b', hasPassword: true),
    );
    _enqueueDownloadersData(
      _bundle,
      clients: <Map<String, dynamic>>[
        _buildClientJson(id: 2, name: 'client-b', hasPassword: true),
      ],
      libraries: _defaultLibraries,
      indexers: const <Map<String, dynamic>>[],
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-downloaders-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('download-client-name-field')),
      'client-b',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-base-url-field')),
      'http://127.0.0.1:8080',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-username-field')),
      'alice',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-password-field')),
      'secret',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-client-save-path-field')),
      '/downloads/b',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-local-root-path-field')),
      '/mnt/downloads/b',
    );
    await tester.ensureVisible(
      find.byKey(const Key('download-client-media-library-field')),
    );
    await tester.tap(
      find.byKey(const Key('download-client-media-library-field')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main Library').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-downloader-submit-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final postRequest = _bundle.adapter.requests.firstWhere(
      (request) =>
          request.method == 'POST' && request.path == '/download-clients',
    );
    expect(postRequest.body['name'], 'client-b');
    expect(postRequest.body['password'], 'secret');
    expect(postRequest.body['media_library_id'], 1);
    expect(find.text('client-b'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('validates fields before create submit', (
    WidgetTester tester,
  ) async {
    _enqueueDownloadersData(
      _bundle,
      clients: const <Map<String, dynamic>>[],
      libraries: _defaultLibraries,
      indexers: const <Map<String, dynamic>>[],
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-downloaders-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('download-client-name-field')),
      'client-b',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-base-url-field')),
      'not-url',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-username-field')),
      'alice',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-password-field')),
      'secret',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-client-save-path-field')),
      'downloads',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-local-root-path-field')),
      'relative/path',
    );
    await tester.ensureVisible(
      find.byKey(const Key('mobile-downloader-submit-button')),
    );
    await tester.tap(find.byKey(const Key('mobile-downloader-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('请输入合法的 http/https 地址'), findsOneWidget);
    expect(find.text('请输入路径'), findsNWidgets(2));
    expect(find.text('请选择目标媒体库'), findsWidgets);
    expect(_bundle.adapter.hitCount('POST', '/download-clients'), 0);
  });

  testWidgets('opens detail drawer and edits from detail action', (
    WidgetTester tester,
  ) async {
    _enqueueDownloadersData(_bundle);
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/download-clients/1',
      body: _buildClientJson(
        id: 1,
        name: 'client-a-updated',
        baseUrl: 'http://qb-updated:8080',
        clientSavePath: '/downloads/updated',
        localRootPath: '/mnt/downloads/updated',
      ),
    );
    _enqueueDownloadersData(
      _bundle,
      clients: <Map<String, dynamic>>[
        _buildClientJson(
          id: 1,
          name: 'client-a-updated',
          baseUrl: 'http://qb-updated:8080',
          clientSavePath: '/downloads/updated',
          localRootPath: '/mnt/downloads/updated',
        ),
      ],
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-downloader-card-body-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-downloader-detail-drawer')),
      findsOneWidget,
    );
    expect(find.text('client-a'), findsWidgets);
    await tester.ensureVisible(
      find.byKey(const Key('mobile-downloader-detail-edit-button')),
    );
    await tester.tap(
      find.byKey(const Key('mobile-downloader-detail-edit-button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('download-client-name-field')),
      'client-a-updated',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-base-url-field')),
      'http://qb-updated:8080',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-client-save-path-field')),
      '/downloads/updated',
    );
    await tester.enterText(
      find.byKey(const Key('download-client-local-root-path-field')),
      '/mnt/downloads/updated',
    );
    await tester.ensureVisible(
      find.byKey(const Key('mobile-downloader-submit-button')),
    );
    await tester.tap(find.byKey(const Key('mobile-downloader-submit-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = _bundle.adapter.requests.firstWhere(
      (request) =>
          request.method == 'PATCH' && request.path == '/download-clients/1',
    );
    expect(patchRequest.body['name'], 'client-a-updated');
    expect(patchRequest.body.containsKey('password'), isFalse);
    expect(find.text('client-a-updated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('deletes downloader from detail action after confirm', (
    WidgetTester tester,
  ) async {
    _enqueueDownloadersData(_bundle);
    _bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/download-clients/1',
      statusCode: 204,
    );
    _enqueueDownloadersData(
      _bundle,
      clients: const <Map<String, dynamic>>[],
      libraries: _defaultLibraries,
      indexers: const <Map<String, dynamic>>[],
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-downloader-card-body-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('mobile-downloader-detail-delete-button')),
    );
    await tester.tap(
      find.byKey(const Key('mobile-downloader-detail-delete-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mobile-downloader-delete-confirm-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_bundle.adapter.hitCount('DELETE', '/download-clients/1'), 1);
    expect(find.text('还没有下载器配置'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('guide tab reflects setup status', (WidgetTester tester) async {
    _enqueueDownloadersData(
      _bundle,
      clients: const <Map<String, dynamic>>[],
      libraries: _defaultLibraries,
      indexers: const <Map<String, dynamic>>[],
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-downloaders-tab-guide')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-downloaders-guide-step-libraries')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-downloaders-guide-step-downloaders')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-downloaders-guide-step-indexers')),
      findsOneWidget,
    );
    expect(find.text('已配置'), findsOneWidget);
    expect(find.text('待配置'), findsNWidgets(2));
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  DownloadClientsApi? downloadClientsApi,
  MediaLibrariesApi? mediaLibrariesApi,
  IndexerSettingsApi? indexerSettingsApi,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<DownloadClientsApi>.value(
          value: downloadClientsApi ?? _bundle.downloadClientsApi,
        ),
        Provider<MediaLibrariesApi>.value(
          value: mediaLibrariesApi ?? _bundle.mediaLibrariesApi,
        ),
        Provider<IndexerSettingsApi>.value(
          value: indexerSettingsApi ?? _bundle.indexerSettingsApi,
        ),
      ],
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

void _enqueueDownloadersData(
  TestApiBundle bundle, {
  List<Map<String, dynamic>>? clients,
  List<Map<String, dynamic>>? libraries,
  List<Map<String, dynamic>>? indexers,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    body: clients ?? <Map<String, dynamic>>[_buildClientJson()],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: libraries ?? _defaultLibraries,
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/indexer-settings',
    body: <String, dynamic>{
      'type': 'builtin',
      'api_key': '',
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
    },
  );
}

Map<String, dynamic> _buildClientJson({
  int id = 1,
  String name = 'client-a',
  String baseUrl = 'http://qb.local:8080',
  String username = 'alice',
  String clientSavePath = '/downloads/a',
  String localRootPath = '/mnt/downloads/a',
  int mediaLibraryId = 1,
  bool hasPassword = true,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'base_url': baseUrl,
    'username': username,
    'client_save_path': clientSavePath,
    'local_root_path': localRootPath,
    'media_library_id': mediaLibraryId,
    'has_password': hasPassword,
    'created_at': '2026-03-08T09:30:00Z',
    'updated_at': '2026-03-08T10:30:00Z',
  };
}

const List<Map<String, dynamic>> _defaultLibraries = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 1,
    'name': 'Main Library',
    'root_path': '/media/library/main',
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

class _RefreshFailureDownloadClientsApi extends DownloadClientsApi {
  _RefreshFailureDownloadClientsApi({required super.apiClient});

  int _requestCount = 0;

  @override
  Future<List<DownloadClientDto>> getClients() async {
    _requestCount += 1;
    if (_requestCount == 1) {
      return <DownloadClientDto>[
        DownloadClientDto.fromJson(_buildClientJson()),
      ];
    }
    throw Exception('refresh failed');
  }
}

class _StaticMediaLibrariesApi extends MediaLibrariesApi {
  _StaticMediaLibrariesApi({required super.apiClient, required this.libraries});

  final List<Map<String, dynamic>> libraries;

  @override
  Future<List<MediaLibraryDto>> getLibraries() async {
    return libraries.map(MediaLibraryDto.fromJson).toList(growable: false);
  }
}

class _StaticIndexerSettingsApi extends IndexerSettingsApi {
  _StaticIndexerSettingsApi({required super.apiClient, required this.settings});

  final IndexerSettingsDto settings;

  @override
  Future<IndexerSettingsDto> getSettings() async {
    return settings;
  }
}
