import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/mobile/mobile_plugins_page.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';
import '../../support/plugin_test_data.dart';

void main() {
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

  testWidgets('mobile plugin settings save shows restart notice', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/plugins',
      body: <Map<String, dynamic>>[pluginSummaryJson(enabled: true)],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/plugins/demo_plugin/settings',
      body: <String, dynamic>{
        'settings': <String, dynamic>{},
        'defaults': <String, dynamic>{},
      },
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/system/plugins/demo_plugin/settings',
      body: <String, dynamic>{'settings': <String, dynamic>{}},
    );

    await pumpPreviewApp(
      tester,
      home: const MobilePluginsPage(),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      extraOverrides: <Override>[
        pluginsApiProvider.overrideWithValue(
          PluginsApi(apiClient: bundle.apiClient),
        ),
      ],
    );

    await tester.tap(
      find.byKey(const Key('mobile-plugin-card-body-demo_plugin')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-plugin-settings-drawer-demo_plugin')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('plugin-settings-save-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('plugin-restart-notice-dialog')),
      findsOneWidget,
    );
  });
}
