import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/account/presentation/mobile_change_password_page.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';

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

  testWidgets('renders notice card, three fields and fixed submit action', (
    WidgetTester tester,
  ) async {
    await _pumpStandalonePage(tester);

    expect(find.byKey(const Key('mobile-settings-password')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-password-notice-card')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-password-form-card')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-password-current-field')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-password-new-field')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-password-confirm-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-password-submit-button')),
      findsOneWidget,
    );
    expect(find.text('确认修改'), findsOneWidget);
    expect(find.text('重置'), findsNothing);
  });

  testWidgets('validates required fields on first submit attempt', (
    WidgetTester tester,
  ) async {
    await _pumpStandalonePage(tester);

    expect(find.text('请输入当前密码'), findsNothing);
    await tester.tap(find.byKey(const Key('mobile-password-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('请输入当前密码'), findsOneWidget);
    expect(find.text('请输入新密码'), findsOneWidget);
    expect(find.text('请再次输入新密码'), findsOneWidget);
    expect(_bundle.adapter.hitCount('POST', '/account/password'), 0);
  });

  testWidgets('rejects same new password and mismatched confirmation', (
    WidgetTester tester,
  ) async {
    await _pumpStandalonePage(tester);

    await tester.enterText(
      find.byKey(const Key('mobile-password-current-field')),
      'same-password',
    );
    await tester.enterText(
      find.byKey(const Key('mobile-password-new-field')),
      'same-password',
    );
    await tester.enterText(
      find.byKey(const Key('mobile-password-confirm-field')),
      'other-password',
    );
    await tester.tap(find.byKey(const Key('mobile-password-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('新密码不能与当前密码相同'), findsOneWidget);
    expect(find.text('两次输入的新密码不一致'), findsOneWidget);
    expect(_bundle.adapter.hitCount('POST', '/account/password'), 0);
  });

  testWidgets('successful password change clears session and returns login', (
    WidgetTester tester,
  ) async {
    final router = buildMobileRouter(sessionStore: _sessionStore);
    addTearDown(router.dispose);
    router.go(mobileSettingsPasswordPath);

    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/account',
      body: <String, dynamic>{
        'username': 'account',
        'created_at': '2026-03-08T09:00:00Z',
        'last_login_at': '2026-03-08T10:00:00Z',
      },
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/account/password',
      statusCode: 204,
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/auth/tokens',
      body: <String, dynamic>{
        'access_token': 'verified-access-token',
        'refresh_token': 'verified-refresh-token',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'expires_at': '2026-03-10T13:00:00Z',
        'refresh_expires_at': '2026-03-17T13:00:00Z',
        'user': <String, dynamic>{'username': 'account'},
      },
    );

    await _pumpRouterApp(tester, router: router);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('mobile-password-current-field')),
      'old-password',
    );
    await tester.enterText(
      find.byKey(const Key('mobile-password-new-field')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('mobile-password-confirm-field')),
      'new-password',
    );
    await tester.tap(find.byKey(const Key('mobile-password-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(
      _bundle.adapter.requests
          .where(
            (request) =>
                request.path == '/account' ||
                request.path == '/account/password' ||
                request.path == '/auth/tokens',
          )
          .map((request) => '${request.method} ${request.path}')
          .toList(),
      <String>['GET /account', 'POST /account/password', 'POST /auth/tokens'],
    );
    expect(
      _bundle.adapter.requests
          .firstWhere((request) => request.path == '/account/password')
          .body,
      <String, dynamic>{
        'current_password': 'old-password',
        'new_password': 'new-password',
      },
    );
    expect(_sessionStore.hasSession, isFalse);
    expect(router.routeInformationProvider.value.uri.path, loginPath);
    expect(find.byKey(const Key('login-form-base-url')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'shows backend error and keeps session when password change fails',
    (WidgetTester tester) async {
      await _pumpStandalonePage(tester);
      _bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/account',
        body: <String, dynamic>{
          'username': 'account',
          'created_at': '2026-03-08T09:00:00Z',
          'last_login_at': '2026-03-08T10:00:00Z',
        },
      );
      _bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/account/password',
        statusCode: 401,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'invalid_credentials',
            'message': 'Current password is incorrect',
            'details': null,
          },
        },
      );

      await tester.enterText(
        find.byKey(const Key('mobile-password-current-field')),
        'wrong-password',
      );
      await tester.enterText(
        find.byKey(const Key('mobile-password-new-field')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('mobile-password-confirm-field')),
        'new-password',
      );
      await tester.tap(find.byKey(const Key('mobile-password-submit-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Current password is incorrect'), findsOneWidget);
      expect(_bundle.adapter.hitCount('POST', '/auth/tokens'), 0);
      expect(_sessionStore.hasSession, isTrue);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'keeps session when password verification with new password fails',
    (WidgetTester tester) async {
      await _pumpStandalonePage(tester);
      _bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/account',
        body: <String, dynamic>{
          'username': 'account',
          'created_at': '2026-03-08T09:00:00Z',
          'last_login_at': '2026-03-08T10:00:00Z',
        },
      );
      _bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/account/password',
        statusCode: 204,
      );
      _bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/auth/tokens',
        statusCode: 401,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'invalid_credentials',
            'message': 'Invalid username or password',
            'details': null,
          },
        },
      );

      await tester.enterText(
        find.byKey(const Key('mobile-password-current-field')),
        'old-password',
      );
      await tester.enterText(
        find.byKey(const Key('mobile-password-new-field')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('mobile-password-confirm-field')),
        'new-password',
      );
      await tester.tap(find.byKey(const Key('mobile-password-submit-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('密码已修改，但新密码登录校验失败，请重新登录确认'), findsOneWidget);
      expect(_sessionStore.hasSession, isTrue);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('submit stays single-flight while request is in progress', (
    WidgetTester tester,
  ) async {
    await _pumpStandalonePage(tester);
    final completer = Completer<ResponseBody>();

    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/account',
      body: <String, dynamic>{
        'username': 'account',
        'created_at': '2026-03-08T09:00:00Z',
        'last_login_at': '2026-03-08T10:00:00Z',
      },
    );
    _bundle.adapter.enqueueResponder(
      method: 'POST',
      path: '/account/password',
      responder: (_, __) => completer.future,
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/auth/tokens',
      body: <String, dynamic>{
        'access_token': 'verified-access-token',
        'refresh_token': 'verified-refresh-token',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'expires_at': '2026-03-10T13:00:00Z',
        'refresh_expires_at': '2026-03-17T13:00:00Z',
        'user': <String, dynamic>{'username': 'account'},
      },
    );

    await tester.enterText(
      find.byKey(const Key('mobile-password-current-field')),
      'old-password',
    );
    await tester.enterText(
      find.byKey(const Key('mobile-password-new-field')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('mobile-password-confirm-field')),
      'new-password',
    );

    await tester.tap(find.byKey(const Key('mobile-password-submit-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-password-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_bundle.adapter.hitCount('POST', '/account/password'), 1);

    completer.complete(
      ResponseBody.fromBytes(const <int>[], 204, headers: const {}),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpStandalonePage(WidgetTester tester) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: _sessionStore),
        Provider<AccountApi>.value(value: _bundle.accountApi),
        Provider<AuthApi>.value(value: _bundle.authApi),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: MobileChangePasswordPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRouterApp(
  WidgetTester tester, {
  required GoRouter router,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: _sessionStore),
        Provider<AccountApi>.value(value: _bundle.accountApi),
        Provider<AuthApi>.value(value: _bundle.authApi),
      ],
      child: OKToast(
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    ),
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
