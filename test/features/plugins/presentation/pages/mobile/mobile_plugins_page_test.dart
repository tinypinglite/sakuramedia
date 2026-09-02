import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/mobile/mobile_plugins_page.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_zip_picker.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';

import '../../../../../support/test_api_bundle.dart';
import '../../../support/plugin_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'mobile-access-token',
      refreshToken: 'mobile-refresh-token',
      expiresAt: DateTime.parse('2026-09-02T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('loads an empty plugin list on mobile', (tester) async {
    _enqueueList(bundle, plugins: const <Map<String, dynamic>>[]);

    await _pumpPage(tester, bundle);

    expect(find.byKey(const Key('mobile-settings-plugins')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-plugins-restart-notice')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-plugins-empty-state')), findsOneWidget);
  });

  testWidgets('shows error state when plugin loading fails', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/plugins',
      statusCode: 500,
      body: <String, dynamic>{'message': '插件服务不可用'},
    );

    await _pumpPage(tester, bundle);

    expect(find.byKey(const Key('mobile-plugins-error-state')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-plugins-retry-button')),
      findsOneWidget,
    );
  });

  testWidgets('opens actions drawer and enables a plugin', (tester) async {
    _enqueueList(
      bundle,
      plugins: <Map<String, dynamic>>[pluginSummaryJson(enabled: false)],
    );
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/system/plugins/demo_plugin',
      body: pluginSummaryJson(enabled: true),
    );

    await _pumpPage(tester, bundle);
    await tester.tap(find.byKey(const Key('mobile-plugin-more-demo_plugin')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-plugin-actions-drawer-demo_plugin')),
      findsOneWidget,
    );
    expect(find.text('启用插件'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mobile-plugin-toggle-demo_plugin')));
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('PATCH', '/system/plugins/demo_plugin'), 1);
    final request = bundle.adapter.requests.singleWhere(
      (item) => item.method == 'PATCH',
    );
    expect(request.uri.queryParameters['enabled'], 'true');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('closes action drawer before delete confirmation', (
    tester,
  ) async {
    _enqueueList(bundle, plugins: <Map<String, dynamic>>[pluginSummaryJson()]);
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/system/plugins/demo_plugin',
      body: <String, dynamic>{},
    );

    await _pumpPage(tester, bundle);
    await tester.tap(find.byKey(const Key('mobile-plugin-more-demo_plugin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-plugin-delete-demo_plugin')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-plugin-actions-drawer-demo_plugin')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('plugins-delete-confirm-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('plugins-delete-confirm-button')));
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('DELETE', '/system/plugins/demo_plugin'), 1);
    expect(find.byKey(const Key('mobile-plugins-empty-state')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('checks and upgrades a plugin from the actions drawer', (
    tester,
  ) async {
    const releaseUrl =
        'https://api.github.com/repos/example/demo_plugin/releases/latest';
    const assetUrl = 'https://github.com/example/demo/download.zip';
    _enqueueList(
      bundle,
      plugins: <Map<String, dynamic>>[
        pluginSummaryJson(releaseApiUrl: releaseUrl),
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: releaseUrl,
      body: <String, dynamic>{
        'tag_name': 'v1.1.0',
        'body': '修复下载失败',
        'assets': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'demo_plugin-1.1.0.zip',
            'browser_download_url': assetUrl,
          },
        ],
      },
    );
    bundle.adapter.enqueueBytes(
      method: 'GET',
      path: assetUrl,
      body: Uint8List.fromList(<int>[80, 75, 3, 4]),
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/demo_plugin/upgrade',
      body: <String, dynamic>{
        'plugin_id': 'demo_plugin',
        'version': '1.1.0',
        'pending_restart': <String>['api'],
      },
    );

    await _pumpPage(tester, bundle);
    await tester.tap(
      find.byKey(const Key('mobile-plugins-check-updates-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('有更新'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-plugin-more-demo_plugin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-plugin-update-demo_plugin')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('plugin-upgrade-confirm-dialog-demo_plugin')),
      findsOneWidget,
    );
    expect(find.textContaining('修复下载失败'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('plugin-upgrade-confirm-button-demo_plugin')),
    );
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.hitCount('POST', '/system/plugins/demo_plugin/upgrade'),
      1,
    );
    expect(find.text('v1.1.0 · demo_plugin'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('installs a picked plugin zip', (tester) async {
    _enqueueList(bundle, plugins: const <Map<String, dynamic>>[]);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins',
      statusCode: 201,
      body: <String, dynamic>{'plugin_id': 'demo_plugin', 'version': '1.0.0'},
    );
    _enqueueList(bundle, plugins: <Map<String, dynamic>>[pluginSummaryJson()]);
    debugPluginZipPicker = () async => PluginZipFile(
      bytes: Uint8List.fromList(<int>[80, 75, 3, 4]),
      fileName: 'demo.zip',
    );
    addTearDown(() => debugPluginZipPicker = null);

    await _pumpPage(tester, bundle);
    await tester.tap(find.byKey(const Key('mobile-plugins-install-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('plugins-install-confirm-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('plugins-install-confirm-button')));
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('POST', '/system/plugins'), 1);
    expect(
      find.byKey(const Key('mobile-plugin-card-demo_plugin')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('validates and saves plugin JSON settings', (tester) async {
    _enqueueList(bundle, plugins: <Map<String, dynamic>>[pluginSummaryJson()]);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/plugins/demo_plugin/settings',
      body: <String, dynamic>{
        'settings': <String, dynamic>{'overlap_days': 7},
      },
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/system/plugins/demo_plugin/settings',
      body: <String, dynamic>{
        'settings': <String, dynamic>{'overlap_days': 14},
      },
    );

    await _pumpPage(tester, bundle);
    await tester.tap(
      find.byKey(const Key('mobile-plugin-card-body-demo_plugin')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-plugin-settings-drawer-demo_plugin')),
      findsOneWidget,
    );

    final field = find.byKey(const Key('plugin-settings-json-field'));
    await tester.enterText(field, '[]');
    await tester.tap(find.byKey(const Key('plugin-settings-save-button')));
    await tester.pump();
    expect(find.text('插件配置必须是一个 JSON 对象'), findsOneWidget);

    await tester.enterText(field, '{"overlap_days": 14}');
    await tester.tap(find.byKey(const Key('plugin-settings-save-button')));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.singleWhere(
      (item) => item.method == 'PUT',
    );
    expect(request.body, <String, dynamic>{'overlap_days': 14});
    expect(
      find.byKey(const Key('mobile-plugin-settings-drawer-demo_plugin')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('can cancel a settings drawer when loading fails', (
    tester,
  ) async {
    _enqueueList(bundle, plugins: <Map<String, dynamic>>[pluginSummaryJson()]);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/plugins/demo_plugin/settings',
      statusCode: 500,
      body: <String, dynamic>{'message': '配置暂不可用'},
    );

    await _pumpPage(tester, bundle);
    await tester.tap(
      find.byKey(const Key('mobile-plugin-card-body-demo_plugin')),
    );
    await tester.pumpAndSettle();

    final saveButton = tester.widget<AppButton>(
      find.byKey(const Key('plugin-settings-save-button')),
    );
    expect(saveButton.onPressed, isNull);
    expect(find.text('插件配置加载失败'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-plugin-settings-drawer-demo_plugin')),
      findsNothing,
    );
  });
}

void _enqueueList(
  TestApiBundle bundle, {
  required List<Map<String, dynamic>> plugins,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/plugins',
    body: plugins,
  );
}

Future<void> _pumpPage(WidgetTester tester, TestApiBundle bundle) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...bundle.riverpodOverrides(),
        pluginsApiProvider.overrideWithValue(
          PluginsApi(apiClient: bundle.apiClient),
        ),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraMobileThemeData,
          home: const AppPlatformScope(
            platform: AppPlatform.mobile,
            child: Scaffold(body: MobilePluginsPage()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
