import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/app/providers/app_update_check_provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';

import '../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    final adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  List<Override> overrides({required Future<PackageInfo> packageInfo}) {
    return <Override>[
      statusApiProvider.overrideWithValue(_FakeStatusApi(apiClient)),
      appPackageInfoLoaderProvider.overrideWithValue(() => packageInfo),
    ];
  }

  test(
    'disposing the container while check is awaiting does not leak errors',
    () async {
      final packageInfoCompleter = Completer<PackageInfo>();
      final errors = <Object>[];
      late ProviderContainer container;
      runZonedGuarded(() {
        container = ProviderContainer(
          overrides: overrides(packageInfo: packageInfoCompleter.future),
        );
        // 触发 build，scheduleMicrotask(check) 在守卫 zone 内注册。
        container.read(appUpdateCheckProvider);
      }, (error, stack) => errors.add(error));

      // 让 check 走到 `await load()` 并挂起在未完成的 package info 上。
      await Future<void>.delayed(Duration.zero);

      container.dispose();
      packageInfoCompleter.complete(_packageInfo());

      // 等 load / check 的后续 continuation 全部执行完。
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // 修复前 check 会在 await 之后继续使用已销毁的 ref，以
      // UnmountedRefException 逃逸到 Zone（unawaited）。
      expect(errors, isEmpty);
    },
  );

  test('stays alive after the last listener is removed', () async {
    final packageInfoCompleter = Completer<PackageInfo>();
    final container = ProviderContainer(
      overrides: overrides(packageInfo: packageInfoCompleter.future),
    );
    addTearDown(container.dispose);

    final subscription = container.listen(appUpdateCheckProvider, (_, _) {});
    final first = container.read(appUpdateCheckProvider.notifier);
    subscription.close();

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // keepAlive：最后一个监听者移除后实例保留；若被改成 autoDispose，
    // 移动端每次打开抽屉都会重跑全量检查并清空「有更新」标记。
    final second = container.read(appUpdateCheckProvider.notifier);
    expect(identical(first, second), isTrue);
  });
}

/// 只实现本测试用到的 [StatusApi.getStatus]：其余请求不应发生。
class _FakeStatusApi extends StatusApi {
  _FakeStatusApi(ApiClient apiClient) : super(apiClient: apiClient);

  @override
  Future<StatusDto> getStatus() async {
    return StatusDto.fromJson(_statusJson(backendVersion: 'v0.2.0'));
  }
}

PackageInfo _packageInfo() {
  return PackageInfo(
    appName: 'Sakuramedia',
    packageName: 'sakuramedia',
    version: '0.2.3',
    buildNumber: '1',
    buildSignature: '',
  );
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
