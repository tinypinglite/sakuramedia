import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sakuramedia/app/app_version_info_controller.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';

import '../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('loads frontend and backend version labels once', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      body: _statusJson(backendVersion: 'v0.2.0'),
    );
    var packageLoadCount = 0;
    final controller = AppVersionInfoController(
      statusApi: StatusApi(apiClient: apiClient),
      packageInfoLoader: () async {
        packageLoadCount += 1;
        return PackageInfo(
          appName: 'SakuraMedia',
          packageName: 'sakuramedia',
          version: '0.2.2',
          buildNumber: '1',
          buildSignature: '',
        );
      },
    );

    await Future.wait<void>([controller.load(), controller.load()]);

    expect(controller.frontendVersionLabel, '0.2.2');
    expect(controller.backendVersionLabel, 'v0.2.0');
    expect(controller.tooltipLabel, '客户端 0.2.2 · 服务端 v0.2.0');
    expect(packageLoadCount, 1);
    expect(adapter.hitCount('GET', '/status'), 1);
  });

  test('keeps backend placeholder when status request fails', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 500,
      body: <String, dynamic>{'error': 'server_error'},
    );
    final controller = AppVersionInfoController(
      statusApi: StatusApi(apiClient: apiClient),
      packageInfoLoader: () async {
        return PackageInfo(
          appName: 'SakuraMedia',
          packageName: 'sakuramedia',
          version: '0.2.2',
          buildNumber: '1',
          buildSignature: '',
        );
      },
    );

    await controller.load();

    expect(controller.frontendVersionLabel, '0.2.2');
    expect(controller.backendVersionLabel, '--');
  });
}

Map<String, dynamic> _statusJson({required String backendVersion}) {
  return <String, dynamic>{
    'backend_version': backendVersion,
    'actors': <String, dynamic>{'female_total': 12, 'female_subscribed': 8},
    'movies': <String, dynamic>{'total': 120, 'subscribed': 35, 'playable': 88},
    'media_files': <String, dynamic>{
      'total': 156,
      'total_size_bytes': 987654321,
    },
    'media_libraries': <String, dynamic>{'total': 3},
  };
}
