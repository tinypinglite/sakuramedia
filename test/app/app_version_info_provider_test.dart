import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';

import '../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;
  var packageLoadCount = 0;

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
    packageLoadCount = 0;
    container = ProviderContainer(
      overrides: <Override>[
        statusApiProvider.overrideWithValue(StatusApi(apiClient: apiClient)),
        appPackageInfoLoaderProvider.overrideWithValue(() async {
          packageLoadCount += 1;
          return PackageInfo(
            appName: 'SakuraMedia',
            packageName: 'sakuramedia',
            version: '0.2.3',
            buildNumber: '1',
            buildSignature: '',
          );
        }),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
  });

  test(
    'coalesces concurrent requests and refreshes backend version later',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/status',
        body: _statusJson(backendVersion: 'v0.2.0'),
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/status',
        body: _statusJson(backendVersion: 'v0.2.1'),
      );

      final notifier = container.read(appVersionInfoProvider.notifier);
      await Future.wait<void>([notifier.load(), notifier.load()]);

      var state = container.read(appVersionInfoProvider).requireValue;
      expect(state.frontendVersionLabel, '0.2.3');
      expect(state.backendVersionLabel, 'v0.2.0');
      expect(state.tooltipLabel, '客户端 0.2.3 · 服务端 v0.2.0');
      expect(packageLoadCount, 1);
      expect(adapter.hitCount('GET', '/status'), 1);

      await notifier.load();

      state = container.read(appVersionInfoProvider).requireValue;
      expect(state.backendVersionLabel, 'v0.2.1');
      expect(packageLoadCount, 1);
      expect(adapter.hitCount('GET', '/status'), 2);
    },
  );

  test('keeps backend placeholder when status request fails', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 500,
      body: <String, dynamic>{'error': 'server_error'},
    );

    await container.read(appVersionInfoProvider.notifier).load();

    final state = container.read(appVersionInfoProvider).requireValue;
    expect(state.frontendVersionLabel, '0.2.3');
    expect(state.backendVersionLabel, '--');
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
