import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_api_provider.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    container = ProviderContainer(
      overrides: [
        // invalidateOnSessionChange 会 watch sessionStoreProvider，必须 override。
        sessionStoreProvider.overrideWithValue(sessionStore),
        accountApiProvider.overrideWithValue(bundle.accountApi),
      ],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    bundle.dispose();
  });

  Future<void> _pumpUntilAccountLoaded() async {
    // build() 内的 Future.microtask(load) 需要 event loop tick 才发起请求；
    // 用一次 tick 即可完成微任务调度。
    while (container.read(accountProfileProvider).account == null) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _pumpUntil(bool Function() predicate) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!predicate()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('condition not met within 5s');
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('build triggers first load via microtask', () async {
    _enqueueAccount(bundle, username: 'account');

    // 立即 read 时 state 是初始 loading，account 尚未拉到。
    expect(container.read(accountProfileProvider).isLoading, isTrue);
    expect(container.read(accountProfileProvider).account, isNull);

    await _pumpUntilAccountLoaded();
    expect(container.read(accountProfileProvider).account?.username, 'account');
    expect(container.read(accountProfileProvider).isLoading, isFalse);
  });

  test('saveUsername trims request body and updates account', () async {
    _enqueueAccount(bundle, username: 'account');
    _enqueueAccount(bundle, method: 'PATCH', username: 'renamed-account');

    await _pumpUntilAccountLoaded();
    final saved = await container
        .read(accountProfileProvider.notifier)
        .saveUsername('  renamed-account  ');

    expect(saved, isTrue);
    expect(
      container.read(accountProfileProvider).account?.username,
      'renamed-account',
    );
    expect(
      bundle.adapter.requests
          .firstWhere((request) => request.method == 'PATCH')
          .body,
      <String, dynamic>{'username': 'renamed-account'},
    );
  });

  test('username conflict maps to localized message', () async {
    _enqueueAccount(bundle, username: 'account');
    bundle.adapter.enqueueResponder(
      method: 'PATCH',
      path: '/account',
      responder: (_, __) async {
        return ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{
              'code': 'username_conflict',
              'message': 'Username already exists',
              'details': null,
            },
          }),
          409,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    await _pumpUntilAccountLoaded();
    final saved = await container
        .read(accountProfileProvider.notifier)
        .saveUsername('taken');

    expect(saved, isFalse);
    expect(
      container.read(accountProfileProvider).errorMessage,
      '用户名已存在，请换一个名称',
    );
  });

  test('empty/unchanged username short-circuits without request', () async {
    _enqueueAccount(bundle, username: 'account');
    await _pumpUntilAccountLoaded();

    final emptySaved = await container
        .read(accountProfileProvider.notifier)
        .saveUsername('   ');
    expect(emptySaved, isFalse);
    expect(container.read(accountProfileProvider).errorMessage, '请输入用户名');

    final sameSaved = await container
        .read(accountProfileProvider.notifier)
        .saveUsername('account');
    expect(sameSaved, isFalse);
    expect(container.read(accountProfileProvider).errorMessage, '用户名未变化');

    // 未发出任何 PATCH 请求。
    expect(bundle.adapter.hitCount('PATCH', '/account'), 0);
  });

  test('saveUsername stays single-flight while request is in progress',
      () async {
    _enqueueAccount(bundle, username: 'account');
    final completer = Completer<ResponseBody>();
    bundle.adapter.enqueueResponder(
      method: 'PATCH',
      path: '/account',
      responder: (_, __) => completer.future,
    );

    await _pumpUntilAccountLoaded();
    final firstSave = container
        .read(accountProfileProvider.notifier)
        .saveUsername('renamed');
    await _waitForPatchRequest(bundle);
    final secondSave = await container
        .read(accountProfileProvider.notifier)
        .saveUsername('renamed-again');

    expect(secondSave, isFalse);
    expect(bundle.adapter.hitCount('PATCH', '/account'), 1);

    completer.complete(
      ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'username': 'renamed',
          'created_at': '2026-03-08T09:00:00Z',
          'last_login_at': '2026-03-08T10:00:00Z',
        }),
        200,
        headers: const <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      ),
    );

    expect(await firstSave, isTrue);
    expect(
      container.read(accountProfileProvider).account?.username,
      'renamed',
    );
  });

  test('登出失效：换账号后重新拉取新账号资料', () async {
    _enqueueAccount(bundle, username: 'first-account');
    await _pumpUntilAccountLoaded();
    expect(
      container.read(accountProfileProvider).account?.username,
      'first-account',
    );

    // keepAlive 状态不随页面卸载释放；组合根 ObjectKey 绑 SessionStore 实例，
    // 同一次运行内换账号不重建容器——必须靠 invalidateOnSessionChange 失效，
    // 否则新账号读到上一账号的资料。
    _enqueueAccount(bundle, username: 'second-account');
    await sessionStore.clearSession();
    await sessionStore.saveTokens(
      accessToken: 'access-token-2',
      refreshToken: 'refresh-token-2',
      expiresAt: DateTime.parse('2026-03-11T12:00:00Z'),
    );

    await _pumpUntilAccountLoaded();
    expect(
      container.read(accountProfileProvider).account?.username,
      'second-account',
    );
  });

  test('登出瞬间页面仍挂载：登录后自动重拉，旧 401 不残留', () async {
    var fetches = 0;
    void enqueueBySession() {
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/account',
        responder: (options, requestBody) async {
          fetches += 1;
          final hasSession = sessionStore.hasSession;
          final body = hasSession
              ? <String, dynamic>{
                  'username': 'account',
                  'created_at': '2026-03-08T09:00:00Z',
                  'last_login_at': '2026-03-08T10:00:00Z',
                }
              : <String, dynamic>{
                  'error': <String, dynamic>{
                    'code': 'unauthorized',
                    'message': '请先登录',
                  },
                };
          return ResponseBody.fromString(
            jsonEncode(body),
            hasSession ? 200 : 401,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );
    }

    // 初次加载 → 登出边沿重建 → 登录边沿重建。
    for (var i = 0; i < 3; i++) {
      enqueueBySession();
    }

    // 设置页正开着：provider 在登出边沿有活跃监听者。
    container.listen(accountProfileProvider, (_, _) {});
    await _pumpUntilAccountLoaded();
    expect(container.read(accountProfileProvider).account?.username, 'account');

    await sessionStore.clearSession();
    await _pumpUntil(
      () => container.read(accountProfileProvider).errorMessage != null,
    );
    expect(container.read(accountProfileProvider).errorMessage, '请先登录');

    // 重新登录必须再次失效并重拉，否则页面会一直显示登出瞬间缓存的 401。
    await sessionStore.saveTokens(
      accessToken: 'access-token-2',
      refreshToken: 'refresh-token-2',
      expiresAt: DateTime.parse('2026-03-11T12:00:00Z'),
    );
    await _pumpUntil(() {
      final state = container.read(accountProfileProvider);
      return !state.isLoading && state.errorMessage == null;
    });
    expect(container.read(accountProfileProvider).account?.username, 'account');
    expect(fetches, 3);
  });
}

Future<void> _waitForPatchRequest(TestApiBundle bundle) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (bundle.adapter.hitCount('PATCH', '/account') == 0 &&
      DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void _enqueueAccount(
  TestApiBundle bundle, {
  String method = 'GET',
  required String username,
}) {
  bundle.adapter.enqueueJson(
    method: method,
    path: '/account',
    body: <String, dynamic>{
      'username': username,
      'created_at': '2026-03-08T09:00:00Z',
      'last_login_at': '2026-03-08T10:00:00Z',
    },
  );
}
