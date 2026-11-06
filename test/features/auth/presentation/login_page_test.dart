import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/auth/presentation/login_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../support/pump_with_providers.dart';
import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('login brand asset is bundled', () async {
    final data = await rootBundle.load(
      'wiki/public/brand/sakuramedia-logo.png',
    );
    expect(data.lengthInBytes, greaterThan(0));
  });

  testWidgets('desktop login keeps the complete form available', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      platform: AppPlatform.desktop,
      size: const Size(1200, 800),
      theme: buildSakuraDesktopThemeData(),
    );

    expect(find.byKey(const Key('login-form-base-url')), findsOneWidget);
    expect(find.byKey(const Key('login-form-username')), findsOneWidget);
    expect(find.byKey(const Key('login-form-password')), findsOneWidget);
    expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
    expect(find.byKey(const Key('login-language-switcher')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile login remains usable on a narrow viewport', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      platform: AppPlatform.mobile,
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
    );

    expect(find.byKey(const Key('login-main-card')), findsOneWidget);
    expect(find.byKey(const Key('login-form-base-url')), findsOneWidget);
    expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password visibility toggle updates the secure field', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      platform: AppPlatform.desktop,
      size: const Size(1200, 800),
      theme: buildSakuraDesktopThemeData(),
    );

    EditableText passwordText() {
      return tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('login-form-password')),
          matching: find.byType(EditableText),
        ),
      );
    }

    expect(passwordText().obscureText, isTrue);
    await tester.tap(find.byKey(const Key('login-password-toggle')));
    await tester.pump();
    expect(passwordText().obscureText, isFalse);
  });

  testWidgets('first-run notice can be dismissed', (tester) async {
    await _pumpLogin(
      tester,
      platform: AppPlatform.desktop,
      size: const Size(1200, 800),
      theme: buildSakuraDesktopThemeData(),
    );

    expect(find.byKey(const Key('login-first-run-notice')), findsOneWidget);
    await tester.tap(find.byKey(const Key('login-dismiss-first-run')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-first-run-notice')), findsNothing);
  });

  testWidgets('desktop login reflows at large text sizes', (tester) async {
    final sessionStore = SessionStore.inMemory();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    await pumpWithProviders(
      tester,
      home: const LoginPage(platform: AppPlatform.desktop),
      bundle: bundle,
      theme: buildSakuraDesktopThemeData(),
      physicalSize: const Size(1200, 900),
      wrap: (child) => MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: child,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-main-card')), findsOneWidget);
    expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login failure stays on the page and shows an inline error', (
    tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    bundle.adapter.enqueueResponder(
      method: 'POST',
      path: '/auth/tokens',
      responder: (_, _) async => ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'invalid_credentials',
            'message': '用户名或密码错误',
          },
        }),
        401,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      ),
    );

    await pumpWithProviders(
      tester,
      home: const LoginPage(platform: AppPlatform.desktop),
      bundle: bundle,
      theme: buildSakuraDesktopThemeData(),
      physicalSize: const Size(1200, 800),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-form-base-url')),
      '192.168.1.10:38000',
    );
    await tester.enterText(
      find.byKey(const Key('login-form-username')),
      'account',
    );
    await tester.enterText(
      find.byKey(const Key('login-form-password')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-error-message')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  required AppPlatform platform,
  required Size size,
  required ThemeData theme,
}) async {
  final sessionStore = SessionStore.inMemory();
  final bundle = await createTestApiBundle(sessionStore);
  addTearDown(bundle.dispose);
  addTearDown(sessionStore.dispose);

  await pumpWithProviders(
    tester,
    home: LoginPage(platform: platform),
    bundle: bundle,
    theme: theme,
    physicalSize: size,
  );
  await tester.pumpAndSettle();
}
