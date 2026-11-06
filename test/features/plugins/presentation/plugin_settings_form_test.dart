import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/desktop/plugin_settings_dialog.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/shared/plugin_settings_content.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_settings_schema.dart';
import 'package:sakuramedia/widgets/base/actions/app_switch.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';

import '../../../support/logged_in_session_store.dart';
import '../../../support/test_api_bundle.dart';
import '../support/plugin_test_data.dart';

String fieldText(WidgetTester tester, Finder field) {
  return tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .controller
      .text;
}

Map<String, dynamic> actorSchema() =>
    jsonDecode(
          File(
            'test/features/plugins/support/actor_metadata_settings_schema.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

Future<TestApiBundle> openSettings(
  WidgetTester tester, {
  required bool mobile,
  Map<String, dynamic>? schema,
  Map<String, dynamic> settings = const {},
  Map<String, dynamic> defaults = const {},
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = mobile
      ? const Size(360, 760)
      : const Size(1100, 760);
  addTearDown(tester.view.reset);
  final session = await buildLoggedInSessionStore();
  final bundle = await createTestApiBundle(session);
  addTearDown(bundle.dispose);
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/plugins/demo_plugin/settings',
    body: {
      'settings': settings,
      'defaults': defaults,
      if (schema != null) 'schema': schema,
    },
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...bundle.riverpodOverrides(),
        pluginsApiProvider.overrideWithValue(
          PluginsApi(apiClient: bundle.apiClient),
        ),
      ],
      child: MaterialApp(
        theme: mobile ? sakuraMobileThemeData : sakuraThemeData,
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        builder: (context, child) =>
            OKToast(child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('配置'),
              onPressed: () => mobile
                  ? showAppBottomDrawer<void>(
                      context: context,
                      builder: (_) => PluginSettingsContent(
                        plugin: pluginSummaryDto(),
                        mobile: true,
                      ),
                    )
                  : showPluginSettingsDialog(
                      context,
                      plugin: pluginSummaryDto(),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('配置'));
  await tester.pumpAndSettle();
  return bundle;
}

Map<String, dynamic> genericSchema() => {
  'type': 'object',
  'required': ['name', 'nested'],
  'properties': {
    'name': {'type': 'string', 'title': '名称', 'minLength': 1},
    'password': {
      'anyOf': [
        {'type': 'string'},
        {'type': 'null'},
      ],
      'default': null,
      'format': 'password',
      'title': '密码',
    },
    'mode': {
      'type': 'string',
      'enum': ['fast', 'slow'],
      'default': 'fast',
      'title': '模式',
    },
    'nested': {r'$ref': r'#/$defs/Nested', 'title': '请求配置'},
    'retired': {'type': 'integer', 'default': 8, 'x-hidden': true},
  },
  r'$defs': {
    'Nested': {
      'type': 'object',
      'properties': {
        'timeout': {
          'type': 'number',
          'exclusiveMinimum': 0,
          'default': 20,
          'title': '超时',
        },
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
          'title': '标签',
        },
        'optional': {
          'anyOf': [
            {'type': 'integer'},
            {'type': 'null'},
          ],
          'default': null,
          'title': '可选数字',
        },
      },
    },
  },
};

void main() {
  test('unsupported unions and recursive refs fall back to JSON', () {
    expect(
      pluginFormSchema({
        'type': 'object',
        'properties': {
          'value': {
            'oneOf': [
              {'type': 'string'},
              {'type': 'number'},
            ],
          },
        },
      }),
      isNull,
    );
    expect(
      pluginFormSchema({
        'type': 'object',
        'properties': {
          'child': {r'$ref': '#/definitions/Node'},
        },
        'definitions': {
          'Node': {
            'type': 'object',
            'properties': {
              'child': {r'$ref': '#/definitions/Node'},
            },
          },
        },
      }),
      isNull,
    );
  });

  for (final mobile in [false, true]) {
    testWidgets(
      'new plugin edits generic types and preserves defaults (mobile=$mobile)',
      (tester) async {
        final bundle = await openSettings(
          tester,
          mobile: mobile,
          schema: genericSchema(),
          defaults: {
            'nested': {
              'timeout': 20,
              'tags': ['AA', 'BB'],
              'optional': null,
            },
          },
          settings: {
            'nested': {'timeout': 5},
            'retired': 9,
          },
        );
        final password = find.byKey(const Key('plugin-setting-password'));
        await tester.enterText(
          find.byKey(const Key('plugin-setting-name')),
          '新插件',
        );
        await tester.ensureVisible(password);
        await tester.enterText(password, 'secret');
        final mode = find.byKey(const Key('plugin-setting-mode'));
        await tester.ensureVisible(mode);
        await tester.tap(mode);
        await tester.pumpAndSettle();
        await tester.tap(find.text('slow').last);
        await tester.pumpAndSettle();
        final tags = find.byKey(const Key('plugin-setting-nested.tags'));
        expect(fieldText(tester, tags), 'AA\nBB');
        await tester.ensureVisible(tags);
        await tester.enterText(tags, 'CC\nDD');
        final timeout = find.byKey(const Key('plugin-setting-nested.timeout'));
        await tester.ensureVisible(timeout);
        await tester.enterText(timeout, '0');
        final save = find.byKey(const Key('plugin-settings-save-button'));
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(
          bundle.adapter.hitCount(
            'PUT',
            '/system/plugins/demo_plugin/settings',
          ),
          0,
        );
        await tester.ensureVisible(timeout);
        await tester.enterText(timeout, '1.5');
        bundle.adapter.enqueueJson(
          method: 'PUT',
          path: '/system/plugins/demo_plugin/settings',
          body: {'settings': {}},
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(
          bundle.adapter.requests.singleWhere((r) => r.method == 'PUT').body,
          {
            'name': '新插件',
            'password': 'secret',
            'mode': 'slow',
            'nested': {
              'timeout': 1.5,
              'tags': ['CC', 'DD'],
              'optional': null,
            },
            'retired': 9,
          },
        );
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  for (final mobile in [false, true]) {
    testWidgets('saved password survives skeleton handoff (mobile=$mobile)', (
      tester,
    ) async {
      final bundle = await openSettings(
        tester,
        mobile: mobile,
        schema: {
          'type': 'object',
          'properties': {
            'api_key': {
              'type': 'string',
              'default': '',
              'format': 'password',
              'title': 'API 密钥',
            },
            'request_timeout_seconds': {
              'type': 'number',
              'default': 20,
              'title': '请求超时（秒）',
            },
          },
        },
        settings: {'api_key': 'sk-existing'},
      );
      final password = find.byKey(const Key('plugin-setting-api_key'));
      expect(fieldText(tester, password), 'sk-existing');
      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/system/plugins/demo_plugin/settings',
        body: {'settings': {}},
      );
      await tester.tap(find.byKey(const Key('plugin-settings-save-button')));
      await tester.pumpAndSettle();
      final body =
          bundle.adapter.requests.singleWhere((r) => r.method == 'PUT').body
              as Map;
      expect(body['api_key'], 'sk-existing');
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets(
    'server field errors can be corrected and nullable values cleared',
    (tester) async {
      final bundle = await openSettings(
        tester,
        mobile: false,
        schema: genericSchema(),
        settings: {'name': '名称', 'password': 'secret'},
        defaults: {
          'nested': {
            'tags': ['AA'],
          },
        },
      );
      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/system/plugins/demo_plugin/settings',
        statusCode: 422,
        body: {
          'error': {
            'code': 'invalid_plugin_settings',
            'message': '配置不正确',
            'details': {
              'fields': [
                {
                  'path': ['nested', 'timeout'],
                  'message': '服务器要求更长的超时',
                },
              ],
            },
          },
        },
      );
      final save = find.byKey(const Key('plugin-settings-save-button'));
      await tester.tap(save);
      await tester.pumpAndSettle();
      final password = find.byKey(const Key('plugin-setting-password'));
      await tester.ensureVisible(password);
      await tester.enterText(password, '');
      await tester.pumpAndSettle();
      final timeout = find.byKey(const Key('plugin-setting-nested.timeout'));
      await tester.ensureVisible(timeout);
      await tester.enterText(timeout, '60');
      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/system/plugins/demo_plugin/settings',
        body: {'settings': {}},
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      final body =
          bundle.adapter.requests.where((r) => r.method == 'PUT').last.body
              as Map;
      expect(body['password'], isNull);
      expect(body['nested']['timeout'], 60);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  for (final mobile in [false, true]) {
    testWidgets('schema defaults, editing and save (mobile=$mobile)', (
      tester,
    ) async {
      final bundle = await openSettings(
        tester,
        mobile: mobile,
        schema: actorSchema(),
        settings: {'retry_days': 5},
      );
      final retry = find.byKey(const Key('plugin-setting-retry_days'));
      expect(fieldText(tester, retry), '5');
      expect(
        fieldText(tester, find.byKey(const Key('plugin-setting-max_attempts'))),
        '3',
      );
      await tester.enterText(retry, '7');
      final toggle = find.byKey(const Key('plugin-setting-subscribed_only'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<AppSwitch>(toggle).value, isTrue);
      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/system/plugins/demo_plugin/settings',
        body: {'settings': {}},
      );
      await tester.tap(find.byKey(const Key('plugin-settings-save-button')));
      await tester.pumpAndSettle();
      expect(
        bundle.adapter.requests.singleWhere((r) => r.method == 'PUT').body,
        {
          'retry_days': 7,
          'max_attempts': 3,
          'subscribed_only': true,
          'request_interval_seconds': 1,
          'timeout_seconds': 20,
        },
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'invalid number is not saved and can be corrected (mobile=$mobile)',
      (tester) async {
        final bundle = await openSettings(
          tester,
          mobile: mobile,
          schema: actorSchema(),
        );
        final retry = find.byKey(const Key('plugin-setting-retry_days'));
        final save = find.byKey(const Key('plugin-settings-save-button'));
        for (final invalid in ['0', '366', '1.5', '']) {
          await tester.ensureVisible(retry);
          await tester.enterText(retry, invalid);
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(
            bundle.adapter.hitCount(
              'PUT',
              '/system/plugins/demo_plugin/settings',
            ),
            0,
          );
        }
        await tester.ensureVisible(retry);
        await tester.enterText(retry, '3');
        bundle.adapter.enqueueJson(
          method: 'PUT',
          path: '/system/plugins/demo_plugin/settings',
          body: {'settings': {}},
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(
          bundle.adapter.hitCount(
            'PUT',
            '/system/plugins/demo_plugin/settings',
          ),
          1,
        );
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  testWidgets('unsupported schema keeps all JSON fields', (tester) async {
    final schema = actorSchema();
    (schema['properties'] as Map)['custom'] = {'type': 'object'};
    final bundle = await openSettings(
      tester,
      mobile: false,
      schema: schema,
      settings: {
        'custom': {'a': 1},
      },
    );
    final jsonField = find.byKey(const Key('plugin-settings-json-field'));
    await tester.enterText(jsonField, '{"custom":{"a":2}}');
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/system/plugins/demo_plugin/settings',
      body: {'settings': {}},
    );
    await tester.tap(find.byKey(const Key('plugin-settings-save-button')));
    await tester.pumpAndSettle();
    expect(bundle.adapter.requests.singleWhere((r) => r.method == 'PUT').body, {
      'custom': {'a': 2},
    });
    await tester.pump(const Duration(seconds: 3));
  });
}
