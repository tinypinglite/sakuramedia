import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_management_actions.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/theme.dart';

import '../../../support/logged_in_session_store.dart';
import '../../../support/pump_with_providers.dart';
import '../../../support/test_api_bundle.dart';
import '../support/plugin_test_data.dart';

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

  testWidgets('successful plugin toggle shows restart notice', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/plugins',
      body: <Map<String, dynamic>>[pluginSummaryJson(enabled: true)],
    );
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/system/plugins/demo_plugin',
      body: pluginSummaryJson(enabled: false),
    );

    await pumpWithProviders(
      tester,
      theme: buildSakuraDesktopThemeData(),
      physicalSize: const Size(1100, 800),
      bundle: bundle,
      overrides: <Override>[
        pluginsApiProvider.overrideWithValue(
          PluginsApi(apiClient: bundle.apiClient),
        ),
      ],
      home: Consumer(
        builder: (context, ref, _) {
          final plugin = ref.watch(pluginsProvider).value?.plugins.firstOrNull;
          return TextButton(
            key: const Key('toggle-plugin'),
            onPressed: plugin == null
                ? null
                : () => PluginManagementActions(
                    context: context,
                    ref: ref,
                  ).toggle(plugin, false),
            child: const Text('toggle'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('toggle-plugin')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('plugin-restart-notice-dialog')),
      findsOneWidget,
    );
  });
}
