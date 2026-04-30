import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/account/presentation/mobile_change_username_page.dart';
import 'package:sakuramedia/theme.dart';

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
      accessToken: 'mobile-access-token',
      refreshToken: 'mobile-refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
  });

  testWidgets('loads account profile and pre-fills username', (
    WidgetTester tester,
  ) async {
    _enqueueAccount(bundle, username: 'account');

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);

    expect(find.byKey(const Key('mobile-settings-username')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-username-notice-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-username-summary-card')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('mobile-username-field')))
          .controller
          ?.text,
      'account',
    );
    expect(find.text('保存用户名'), findsOneWidget);
  });

  testWidgets('validates empty username before submitting', (
    WidgetTester tester,
  ) async {
    _enqueueAccount(bundle, username: 'account');

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.enterText(find.byKey(const Key('mobile-username-field')), '');
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-username-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('请输入用户名'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-username-submit-button')),
      findsOneWidget,
    );
    expect(bundle.adapter.hitCount('PATCH', '/account'), 0);
  });

  testWidgets('submits trimmed username and keeps session', (
    WidgetTester tester,
  ) async {
    _enqueueAccount(bundle, username: 'account');
    _enqueueAccount(bundle, method: 'PATCH', username: 'renamed-account');

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.enterText(
      find.byKey(const Key('mobile-username-field')),
      '  renamed-account  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-username-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      bundle.adapter.requests
          .firstWhere(
            (request) =>
                request.method == 'PATCH' && request.path == '/account',
          )
          .body,
      <String, dynamic>{'username': 'renamed-account'},
    );
    expect(sessionStore.hasSession, isTrue);
    expect(find.text('用户名已更新'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shows username conflict feedback', (WidgetTester tester) async {
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

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.enterText(
      find.byKey(const Key('mobile-username-field')),
      'taken',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-username-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('用户名已存在，请换一个名称'), findsWidgets);
    expect(sessionStore.hasSession, isTrue);
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<AccountApi>.value(value: bundle.accountApi),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: MobileChangeUsernamePage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
