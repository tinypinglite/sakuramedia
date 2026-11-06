import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/configuration_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_back_guard.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/pump_with_providers.dart';
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

  testWidgets('dirty configuration confirms before back guard allows leaving', (
    tester,
  ) async {
    _enqueueInitialConfig(bundle);
    final guard = AppBackGuardController();

    await pumpWithProviders(
      tester,
      home: AppBackGuardScope(
        controller: guard,
        child: const Scaffold(body: DesktopConfigurationPage()),
      ),
      bundle: bundle,
      theme: sakuraDesktopThemeData,
      physicalSize: const Size(1200, 900),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('configuration-tab-download-selection')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('download-selection-min-seeders')),
      '5',
    );
    await tester.pump();

    final firstAttempt = guard.canLeave();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('configuration-advanced-leave-confirm-dialog')),
      findsOneWidget,
    );

    expect(await guard.canLeave(), isFalse);
    expect(
      find.byKey(const Key('configuration-advanced-leave-confirm-dialog')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('configuration-advanced-leave-cancel-button')),
    );
    await tester.pumpAndSettle();
    expect(await firstAttempt, isFalse);

    final secondAttempt = guard.canLeave();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('configuration-advanced-leave-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(await secondAttempt, isTrue);
    expect(
      find.byKey(const Key('configuration-advanced-leave-confirm-dialog')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

void _enqueueInitialConfig(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: const <dynamic>[],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/indexer-settings',
    body: const <String, dynamic>{'indexers': <dynamic>[]},
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-selection-policy',
    body: <String, dynamic>{
      'version': 1,
      'created_at': '2026-10-29T12:00:00Z',
      'updated_at': '2026-10-29T12:00:00Z',
      'rules': <String, dynamic>{
        'schema_version': 1,
        'indexer_kinds': <String>[],
        'indexer_names': <String>[],
        'min_size_bytes': 1024 * 1024 * 1024,
        'max_size_bytes': 40 * 1024 * 1024 * 1024,
        'min_seeders': 1,
        'max_age_days': null,
        'match_title': true,
        'match_description': true,
        'required_groups': <dynamic>[],
        'excluded_terms': <String>[],
        'preferred_groups': <dynamic>[],
        'ranking': <String>['size_desc'],
        'indexer_priority_names': <String>[],
      },
    },
  );
}
