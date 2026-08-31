import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_provider.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-04T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        statusApiProvider.overrideWithValue(StatusApi(apiClient: apiClient)),
      ],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  void keepAlive() {
    // autoDispose：挂监听者保活。
    final subscription = container.listen(
      overviewSystemInfoProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);
  }

  OverviewSystemInfo notifier() =>
      container.read(overviewSystemInfoProvider.notifier);

  /// 等 build 里 microtask 触发的初始 load 完成。
  Future<void> settle() => pumpEventQueue();

  test('build kicks off load; both legs land and flags clear', () async {
    _enqueueOverviewStatus(adapter);

    keepAlive();
    expect(
      container.read(overviewSystemInfoProvider).isLoadingStatus,
      isTrue,
    );
    await settle();

    final state = container.read(overviewSystemInfoProvider);
    expect(state.isLoadingStatus, isFalse);
    expect(state.isLoadingImageSearchStatus, isFalse);
    expect(state.status, isNotNull);
    expect(state.statusError, isNull);
  });

  test('status failure sets error; image search failure stays silent',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/image-search',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );

    keepAlive();
    await settle();

    final state = container.read(overviewSystemInfoProvider);
    // 两腿错误语义不同:status 置错,imageSearchStatus 静默 null。
    expect(state.statusError, '系统信息加载失败，请稍后重试');
    expect(state.imageSearchStatus, isNull);
    expect(state.isLoadingStatus, isFalse);
    expect(state.isLoadingImageSearchStatus, isFalse);
  });

  test('refresh resets loading flags and clears previous error', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/image-search',
      body: <String, dynamic>{},
    );
    keepAlive();
    await settle();
    expect(container.read(overviewSystemInfoProvider).statusError, isNotNull);

    _enqueueOverviewStatus(adapter);
    await notifier().refresh();

    final state = container.read(overviewSystemInfoProvider);
    expect(state.statusError, isNull);
    expect(state.status, isNotNull);
  });

  test('initial load and refresh do not probe cloud115 authentication',
      () async {
    _enqueueOverviewStatus(adapter);
    _enqueueOverviewStatus(adapter);

    keepAlive();
    await settle();
    await notifier().refresh();

    expect(adapter.hitCount('GET', '/status/media-libraries/cloud115'), 0);
    final state = container.read(overviewSystemInfoProvider);
    expect(state.cloud115CookiesStatus, isNull);
    expect(state.cloud115AuthenticationRequestFailed, isFalse);
  });

  test('manual cloud115 authentication probe stores summary', () async {
    _enqueueOverviewStatus(adapter);
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/media-libraries/cloud115',
      body: _cloud115StatusJson(alive: 2, expired: 1, unavailable: 1),
    );

    keepAlive();
    await settle();
    await notifier().testCloud115Authentication();

    final state = container.read(overviewSystemInfoProvider);
    expect(state.isTestingCloud115Authentication, isFalse);
    expect(state.cloud115AuthenticationRequestFailed, isFalse);
    expect(state.cloud115CookiesStatus?.summary.total, 4);
    expect(state.cloud115CookiesStatus?.summary.expired, 1);
    expect(state.cloud115CookiesStatus?.summary.unavailable, 1);
  });

  test('manual cloud115 authentication probe exposes request failure',
      () async {
    _enqueueOverviewStatus(adapter);
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/media-libraries/cloud115',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'server_error',
          'message': 'server error',
        },
      },
    );

    keepAlive();
    await settle();
    await notifier().testCloud115Authentication();

    final state = container.read(overviewSystemInfoProvider);
    expect(state.isTestingCloud115Authentication, isFalse);
    expect(state.cloud115AuthenticationRequestFailed, isTrue);
    expect(state.cloud115CookiesStatus, isNull);
  });

  test('duplicate cloud115 probe is ignored while request is running',
      () async {
    _enqueueOverviewStatus(adapter);
    final release = Completer<void>();
    adapter.enqueueResponder(
      method: 'GET',
      path: '/status/media-libraries/cloud115',
      responder: (RequestOptions _, dynamic __) async {
        await release.future;
        return _jsonResponse(_cloud115StatusJson(alive: 1));
      },
    );

    keepAlive();
    await settle();
    final firstProbe = notifier().testCloud115Authentication();
    await _waitForRequest(
      adapter,
      method: 'GET',
      path: '/status/media-libraries/cloud115',
    );
    await notifier().testCloud115Authentication();

    expect(
      container.read(overviewSystemInfoProvider).isTestingCloud115Authentication,
      isTrue,
    );
    expect(adapter.hitCount('GET', '/status/media-libraries/cloud115'), 1);

    release.complete();
    await firstProbe;
  });

  test('cloud115 and metadata provider probes run independently', () async {
    _enqueueOverviewStatus(adapter);
    final releaseCloud115 = Completer<void>();
    adapter.enqueueResponder(
      method: 'GET',
      path: '/status/media-libraries/cloud115',
      responder: (RequestOptions _, dynamic __) async {
        await releaseCloud115.future;
        return _jsonResponse(_cloud115StatusJson(alive: 1));
      },
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/metadata-providers/javdb/test',
      body: <String, dynamic>{
        'healthy': true,
        'provider': 'javdb',
        'error': null,
      },
    );

    keepAlive();
    await settle();
    final cloud115Probe = notifier().testCloud115Authentication();
    await _waitForRequest(
      adapter,
      method: 'GET',
      path: '/status/media-libraries/cloud115',
    );
    await notifier().testExternalDataSources();

    final state = container.read(overviewSystemInfoProvider);
    expect(state.isTestingCloud115Authentication, isTrue);
    expect(state.isTestingMetadataProviders, isFalse);
    expect(state.javdbHealthy, isTrue);

    releaseCloud115.complete();
    await cloud115Probe;
  });
}

void _enqueueOverviewStatus(FakeHttpClientAdapter adapter) {
  adapter.enqueueJson(
    method: 'GET',
    path: '/status',
    body: <String, dynamic>{},
  );
  adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    body: <String, dynamic>{},
  );
}

Map<String, dynamic> _cloud115StatusJson({
  int alive = 0,
  int expired = 0,
  int unavailable = 0,
}) {
  return <String, dynamic>{
    'checked_at': '2026-08-04T10:00:00Z',
    'summary': <String, dynamic>{
      'total': alive + expired + unavailable,
      'alive': alive,
      'expired': expired,
      'unavailable': unavailable,
    },
    'libraries': <dynamic>[],
  };
}

ResponseBody _jsonResponse(Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: const <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

Future<void> _waitForRequest(
  FakeHttpClientAdapter adapter, {
  required String method,
  required String path,
}) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (adapter.hitCount(method, path) > 0) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Request was not started: $method $path');
}
