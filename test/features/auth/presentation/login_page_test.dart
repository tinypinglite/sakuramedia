import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/features/auth/presentation/login_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../support/fake_http_client_adapter.dart';

Future<void> _pumpLoginPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required AuthApi authApi,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<AuthApi>.value(value: authApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: const LoginPage(platform: AppPlatform.desktop),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillValidLoginForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('login-form-base-url')),
    'https://api.example.com',
  );
  await tester.enterText(find.byKey(const Key('login-form-username')), 'demo');
  await tester.enterText(find.byKey(const Key('login-form-password')), 'pwd');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late AuthApi authApi;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://saved.example.com');
    apiClient = ApiClient(sessionStore: sessionStore);
    authApi = AuthApi(apiClient: apiClient, sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  testWidgets('renders login fields and prefilled base url', (
    WidgetTester tester,
  ) async {
    await _pumpLoginPage(tester, sessionStore: sessionStore, authApi: authApi);

    expect(find.byKey(const Key('login-form-base-url')), findsOneWidget);
    expect(find.byKey(const Key('login-form-username')), findsOneWidget);
    expect(find.byKey(const Key('login-form-password')), findsOneWidget);
    expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
    expect(find.text('https://saved.example.com'), findsOneWidget);
  });

  testWidgets('validates base url format before submit', (
    WidgetTester tester,
  ) async {
    await _pumpLoginPage(tester, sessionStore: sessionStore, authApi: authApi);

    await tester.enterText(
      find.byKey(const Key('login-form-base-url')),
      'invalid-url',
    );
    await tester.enterText(
      find.byKey(const Key('login-form-username')),
      'demo',
    );
    await tester.enterText(find.byKey(const Key('login-form-password')), 'pwd');
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pump();

    expect(find.text('请输入有效的 http(s) 地址'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('disables submit and shows loading while request is running', (
    WidgetTester tester,
  ) async {
    final completer = Completer<void>();
    adapter.enqueueResponder(
      method: 'POST',
      path: '/auth/tokens',
      responder: (RequestOptions _, dynamic __) async {
        await completer.future;
        return ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{
              'code': 'invalid_credentials',
              'message': '用户名或密码错误',
            },
          }),
          401,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    await _pumpLoginPage(tester, sessionStore: sessionStore, authApi: authApi);
    await _fillValidLoginForm(tester);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pump();

    final submitButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('login-submit-button')),
    );
    expect(submitButton.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows backend error message after failed login', (
    WidgetTester tester,
  ) async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/auth/tokens',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'invalid_credentials',
          'message': '用户名或密码错误',
        },
      },
    );

    await _pumpLoginPage(tester, sessionStore: sessionStore, authApi: authApi);
    await _fillValidLoginForm(tester);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-error-message')), findsOneWidget);
    expect(find.text('用户名或密码错误'), findsOneWidget);
  });

  testWidgets('centers login card vertically on desktop viewport', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLoginPage(tester, sessionStore: sessionStore, authApi: authApi);

    final cardRect = tester.getRect(find.byKey(const Key('login-main-card')));
    final viewportCenterY = tester.binding.renderView.size.height / 2;
    final cardCenterY = cardRect.center.dy;
    final viewportHeight = tester.binding.renderView.size.height;

    expect((cardCenterY - viewportCenterY).abs(), lessThan(2.0));
    expect(cardRect.height, lessThan(viewportHeight * 0.8));
  });
}
