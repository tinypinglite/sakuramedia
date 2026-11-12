import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/desktop/plugins_section.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';
import '../../support/plugin_test_data.dart';

void main() {
  testWidgets('desktop plugin with capabilities opens the test dialog', (
    tester,
  ) async {
    final session = await buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(session);
    addTearDown(bundle.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/plugins',
      body: <Map<String, dynamic>>[
        pluginSummaryJson(
          enabled: true,
          testCapabilities: <String>['metadata'],
          testMovieNumber: 'SSIS-001',
        ),
      ],
    );

    await pumpPreviewApp(
      tester,
      home: const DesktopPluginsSection(active: true),
      size: const Size(1100, 760),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );

    await tester.tap(find.byKey(const Key('plugin-test-button-demo_plugin')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plugin-test-dialog')), findsOneWidget);
  });
}
