import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/plugins/data/plugin_market_source.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/desktop/plugin_market_section.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/mobile/mobile_plugin_market_page.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';
import '../../support/plugin_market_test_data.dart';
import '../../support/plugin_test_data.dart';

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

  void enqueueMarket() {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/plugins',
      body: <Map<String, dynamic>>[
        pluginSummaryJson(version: '1.0.0'),
        <String, dynamic>{
          ...pluginSummaryJson(version: '1.0.0'),
          'plugin_id': 'installed_plugin',
          'display_name': '已安装插件',
        },
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: kPluginMarketIndexUrl,
      body: pluginMarketIndexJson(
        plugins: <Map<String, dynamic>>[
          pluginMarketItemJson(pluginId: 'demo_plugin', version: '1.1.0'),
          pluginMarketItemJson(pluginId: 'fresh_plugin', version: '2.0.0'),
          pluginMarketItemJson(pluginId: 'installed_plugin', version: '1.0.0'),
        ],
      ),
    );
  }

  List<Override> pluginsApiOverride() => <Override>[
    pluginsApiProvider.overrideWithValue(
      PluginsApi(apiClient: bundle.apiClient),
    ),
  ];

  testWidgets('desktop market renders rows and filters by keyword', (
    tester,
  ) async {
    enqueueMarket();

    await pumpPreviewApp(
      tester,
      home: const DesktopPluginMarketSection(),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      extraOverrides: pluginsApiOverride(),
    );

    expect(find.byKey(const Key('plugin-market-search-field')), findsOneWidget);
    expect(
      find.byKey(const Key('plugin-market-row-demo_plugin')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('plugin-market-upgrade-button-demo_plugin')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('plugin-market-install-button-fresh_plugin')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('plugin-market-copy-homepage-button-demo_plugin')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('plugin-market-search-field')),
      'fresh',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('plugin-market-row-fresh_plugin')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('plugin-market-row-demo_plugin')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile market renders cards and their actions', (tester) async {
    enqueueMarket();

    await pumpPreviewApp(
      tester,
      home: const MobilePluginMarketPage(),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      extraOverrides: pluginsApiOverride(),
    );

    expect(find.byKey(const Key('mobile-plugin-market')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-plugin-market-search-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-plugin-market-card-demo_plugin')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-plugin-market-upgrade-button-demo_plugin')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-plugin-market-install-button-fresh_plugin')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('mobile-plugin-market-copy-homepage-button-demo_plugin'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
