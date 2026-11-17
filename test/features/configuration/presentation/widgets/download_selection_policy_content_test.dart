import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_selection_policy_content.dart';
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

  testWidgets('desktop content marks numeric edits dirty and discards them', (
    tester,
  ) async {
    _enqueuePolicy(bundle);

    await pumpPreviewApp(
      tester,
      home: const DownloadSelectionPolicyContent(mobile: false),
      size: const Size(1100, 900),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('download-selection-scope-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('download-selection-unsaved-badge')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const Key('download-selection-min-seeders')),
      '5',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('download-selection-unsaved-badge')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('download-selection-discard-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('download-selection-unsaved-badge')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile content exposes the persistent save footer', (
    tester,
  ) async {
    _enqueuePolicy(bundle);

    await pumpPreviewApp(
      tester,
      home: const DownloadSelectionPolicyContent(mobile: true),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('download-selection-save-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('download-selection-scope-section')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

void _enqueuePolicy(TestApiBundle bundle) {
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
