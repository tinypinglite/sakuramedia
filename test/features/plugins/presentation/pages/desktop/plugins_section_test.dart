import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/desktop/plugins_section.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_zip_picker.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/logged_in_session_store.dart';
import '../../../../../support/test_api_bundle.dart';
import '../../../support/plugin_test_data.dart';

void main() {
  group('DesktopPluginsSection', () {
    late SessionStore sessionStore;
    late TestApiBundle bundle;

    setUp(() async {
      sessionStore = await buildLoggedInSessionStore();
      bundle = await createTestApiBundle(sessionStore);
    });

    tearDown(() {
      bundle.dispose();
    });

    testWidgets('loads lazily only when active', (WidgetTester tester) async {
      await _pumpSection(tester, bundle, active: false);

      expect(bundle.adapter.hitCount('GET', '/system/plugins'), 0);

      _enqueueList(
        bundle,
        plugins: <Map<String, dynamic>>[pluginSummaryJson()],
      );
      await _pumpSection(tester, bundle, active: true);

      expect(bundle.adapter.hitCount('GET', '/system/plugins'), 1);
      expect(find.byKey(const Key('plugins-list-card')), findsOneWidget);
      expect(find.byKey(const Key('plugins-restart-notice')), findsOneWidget);
    });

    testWidgets('shows empty state when no plugins are installed', (
      WidgetTester tester,
    ) async {
      _enqueueList(bundle, plugins: const <Map<String, dynamic>>[]);

      await _pumpSection(tester, bundle, active: true);

      expect(find.byKey(const Key('plugins-empty-state')), findsOneWidget);
    });

    testWidgets('toggles a plugin through PATCH', (WidgetTester tester) async {
      _enqueueList(
        bundle,
        plugins: <Map<String, dynamic>>[pluginSummaryJson(enabled: false)],
      );
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/system/plugins/demo_plugin',
        body: pluginSummaryJson(enabled: true),
      );

      await _pumpSection(tester, bundle, active: true);
      await tester.tap(
        find.byKey(const Key('plugin-enabled-switch-demo_plugin')),
      );
      await tester.pumpAndSettle();

      expect(
        bundle.adapter.hitCount('PATCH', '/system/plugins/demo_plugin'),
        1,
      );
      final request = bundle.adapter.requests.singleWhere(
        (item) => item.method == 'PATCH',
      );
      expect(request.uri.queryParameters['enabled'], 'true');
      await tester.pump(const Duration(seconds: 3)); // 排掉 oktoast 计时器
    });

    testWidgets('deletes a plugin after confirmation', (
      WidgetTester tester,
    ) async {
      _enqueueList(
        bundle,
        plugins: <Map<String, dynamic>>[pluginSummaryJson()],
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/system/plugins/demo_plugin',
        body: <String, dynamic>{
          'plugin_id': 'demo_plugin',
          'version': '1.0.0',
          'pending_restart': <String>['api', 'aps'],
        },
      );

      await _pumpSection(tester, bundle, active: true);
      await tester.tap(
        find.byKey(const Key('plugin-remove-button-demo_plugin')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('plugins-delete-confirm-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('plugins-delete-confirm-button')));
      await tester.pumpAndSettle();

      expect(
        bundle.adapter.hitCount('DELETE', '/system/plugins/demo_plugin'),
        1,
      );
      expect(find.byKey(const Key('plugins-empty-state')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // 排掉 oktoast 计时器
    });

    testWidgets('edits plugin settings as a JSON object', (
      WidgetTester tester,
    ) async {
      _enqueueList(
        bundle,
        plugins: <Map<String, dynamic>>[pluginSummaryJson()],
      );
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
          'pending_restart': <String>['api', 'aps'],
        },
      );

      await _pumpSection(tester, bundle, active: true);
      await tester.tap(find.byKey(const Key('plugin-row-demo_plugin')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('plugin-settings-dialog')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('plugin-settings-json-field')),
        '{"overlap_days": 14}',
      );
      await tester.tap(find.byKey(const Key('plugin-settings-save-button')));
      await tester.pumpAndSettle();

      final request = bundle.adapter.requests.singleWhere(
        (item) => item.method == 'PUT',
      );
      expect(request.body, <String, dynamic>{'overlap_days': 14});
      expect(find.byKey(const Key('plugin-settings-dialog')), findsNothing);
      await tester.pump(const Duration(seconds: 3)); // 排掉 oktoast 计时器
    });

    testWidgets('installs a picked zip and reloads the list', (
      WidgetTester tester,
    ) async {
      _enqueueList(bundle, plugins: const <Map<String, dynamic>>[]);
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/system/plugins',
        statusCode: 201,
        body: <String, dynamic>{
          'plugin_id': 'demo_plugin',
          'version': '1.0.0',
          'pending_restart': <String>['api', 'aps'],
        },
      );
      _enqueueList(
        bundle,
        plugins: <Map<String, dynamic>>[pluginSummaryJson()],
      );
      debugPluginZipPicker = () async => PluginZipFile(
        bytes: Uint8List.fromList(<int>[80, 75, 3, 4]),
        fileName: 'demo.zip',
      );
      addTearDown(() => debugPluginZipPicker = null);

      await _pumpSection(tester, bundle, active: true);
      await tester.tap(find.byKey(const Key('plugins-install-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('plugins-install-confirm-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('plugins-install-confirm-button')));
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('POST', '/system/plugins'), 1);
      expect(find.byKey(const Key('plugins-list-card')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // 排掉 oktoast 计时器
    });
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

Future<void> _pumpSection(
  WidgetTester tester,
  TestApiBundle bundle, {
  required bool active,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
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
          theme: sakuraThemeData,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DesktopPluginsSection(active: active),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(tester.view.reset);
}
