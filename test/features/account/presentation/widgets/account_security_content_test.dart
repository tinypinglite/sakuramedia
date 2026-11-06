import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/presentation/widgets/account_security_content.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('desktop content shows profile, password and API keys', (
    tester,
  ) async {
    _enqueueAccount(bundle);

    await pumpPreviewApp(
      tester,
      home: const AccountSecurityContent(mobile: false),
      size: const Size(1100, 900),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      wrap: (child) => SingleChildScrollView(child: child),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('configuration-username-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('configuration-password-submit-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('configuration-api-key-delete-1')),
      findsOneWidget,
    );
    expect(bundle.adapter.hitCount('GET', '/account'), 1);
    expect(bundle.adapter.hitCount('GET', '/account/api-keys'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile content shows profile, password and API keys', (
    tester,
  ) async {
    _enqueueAccount(bundle);

    await pumpPreviewApp(
      tester,
      home: const AccountSecurityContent(mobile: true),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-settings-account-security')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-account-username-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-account-password-submit-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-account-apikey-delete-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

void _enqueueAccount(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/account',
    body: <String, dynamic>{
      'username': 'account',
      'created_at': '2026-03-08T09:00:00Z',
      'last_login_at': '2026-03-08T10:00:00Z',
      'language': 'zh-CN',
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/account/api-keys',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': 'NAS',
        'key_hint': 'sk-…1234',
        'created_at': '2026-03-08T09:00:00Z',
        'last_used_at': '2026-03-08T10:00:00Z',
      },
    ],
  );
}
