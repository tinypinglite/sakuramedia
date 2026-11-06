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
    const size = Size(1200, 800);
    await _pumpLogin(
      tester,
      platform: AppPlatform.desktop,
      size: size,
      theme: buildSakuraDesktopThemeData(),
    );

    _expectLoginFitsWithoutScrolling(tester, size);
    expect(find.byKey(const Key('login-language-switcher')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pad landscape login fits on one screen', (tester) async {
    const size = Size(1024, 768);
    await _pumpLogin(
      tester,
      platform: AppPlatform.desktop,
      size: size,
      theme: buildSakuraDesktopThemeData(),
    );

    _expectLoginFitsWithoutScrolling(tester, size);
    expect(find.byKey(const Key('login-first-run-notice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile login fits on one screen without scrolling', (
    tester,
  ) async {
    const size = Size(390, 844);
    await _pumpLogin(
      tester,
      platform: AppPlatform.mobile,
      size: size,
      theme: buildSakuraMobileThemeData(),
    );

    _expectLoginFitsWithoutScrolling(tester, size);
    expect(find.byKey(const Key('login-first-run-details')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360x640 mobile login still fits on one screen', (tester) async {
    const size = Size(360, 640);
    await _pumpLogin(
      tester,
      platform: AppPlatform.mobile,
      size: size,
      theme: buildSakuraMobileThemeData(),
    );

    _expectLoginFitsWithoutScrolling(tester, size);
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

  testWidgets(
    'compact first-run entry opens full details and can be dismissed',
    (tester) async {
      await _pumpLogin(
        tester,
        platform: AppPlatform.mobile,
        size: const Size(390, 844),
        theme: buildSakuraMobileThemeData(),
      );

      await tester.tap(find.byKey(const Key('login-first-run-details')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login-first-run-modal')), findsOneWidget);
      expect(find.byKey(const Key('login-open-deploy-guide')), findsOneWidget);

      await tester.tap(find.byKey(const Key('login-dismiss-first-run-modal')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login-first-run-modal')), findsNothing);
      expect(find.byKey(const Key('login-first-run-notice')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.byKey(const Key('login-page-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'short viewport keeps the form reachable through scroll fallback',
    (tester) async {
      await _pumpLogin(
        tester,
        platform: AppPlatform.mobile,
        size: const Size(390, 500),
        theme: buildSakuraMobileThemeData(),
      );

      expect(find.byKey(const Key('login-page-scroll')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('login-submit-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('login-submit-button')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

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

void _expectLoginFitsWithoutScrolling(WidgetTester tester, Size size) {
  expect(find.byKey(const Key('login-page-scroll')), findsNothing);
  for (final key in <Key>[
    const Key('login-main-card'),
    const Key('login-form-base-url'),
    const Key('login-form-username'),
    const Key('login-form-password'),
    const Key('login-submit-button'),
  ]) {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget);
    final rect = tester.getRect(finder);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(size.width));
    expect(rect.bottom, lessThanOrEqualTo(size.height));
  }
}
