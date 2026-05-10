import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/presentation/account_profile_controller.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

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
  });

  tearDown(() {
    bundle.dispose();
  });

  test('saveUsername trims request body and updates account', () async {
    final controller = AccountProfileController(accountApi: bundle.accountApi);
    addTearDown(controller.dispose);
    _enqueueAccount(bundle, username: 'account');
    _enqueueAccount(bundle, method: 'PATCH', username: 'renamed-account');

    await controller.load();
    final saved = await controller.saveUsername('  renamed-account  ');

    expect(saved, isTrue);
    expect(controller.account?.username, 'renamed-account');
    expect(
      bundle.adapter.requests
          .firstWhere((request) => request.method == 'PATCH')
          .body,
      <String, dynamic>{'username': 'renamed-account'},
    );
  });

  test('username conflict maps to localized message', () async {
    final controller = AccountProfileController(accountApi: bundle.accountApi);
    addTearDown(controller.dispose);
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

    await controller.load();
    final saved = await controller.saveUsername('taken');

    expect(saved, isFalse);
    expect(controller.errorMessage, '用户名已存在，请换一个名称');
  });

  test(
    'saveUsername stays single-flight while request is in progress',
    () async {
      final controller = AccountProfileController(
        accountApi: bundle.accountApi,
      );
      addTearDown(controller.dispose);
      _enqueueAccount(bundle, username: 'account');
      final completer = Completer<ResponseBody>();
      bundle.adapter.enqueueResponder(
        method: 'PATCH',
        path: '/account',
        responder: (_, __) => completer.future,
      );

      await controller.load();
      final firstSave = controller.saveUsername('renamed');
      await _waitForPatchRequest(bundle);
      final secondSave = await controller.saveUsername('renamed-again');

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
      expect(controller.account?.username, 'renamed');
    },
  );
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
