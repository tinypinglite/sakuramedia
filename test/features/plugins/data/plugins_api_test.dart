import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';

import '../../../support/fake_http_client_adapter.dart';
import '../../../support/logged_in_session_store.dart';
import '../support/plugin_test_data.dart';

void main() {
  group('PluginsApi', () {
    late ApiClient apiClient;
    late FakeHttpClientAdapter adapter;
    late PluginsApi api;

    setUp(() async {
      final store = await buildLoggedInSessionStore();
      apiClient = ApiClient(sessionStore: store);
      adapter = FakeHttpClientAdapter();
      apiClient.rawDio.httpClientAdapter = adapter;
      apiClient.rawRefreshDio.httpClientAdapter = adapter;
      api = PluginsApi(apiClient: apiClient);
    });

    tearDown(() {
      apiClient.dispose();
    });

    test('lists plugin summaries', () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/system/plugins',
        body: <Map<String, dynamic>>[pluginSummaryJson(enabled: true)],
      );

      final plugins = await api.list();

      expect(plugins.single.pluginId, 'demo_plugin');
      expect(plugins.single.displayName, '演示插件');
      expect(plugins.single.version, '1.0.0');
      expect(plugins.single.enabled, isTrue);
      expect(plugins.single.loadStatus, 'ok');
      expect(adapter.hitCount('GET', '/system/plugins'), 1);
    });

    test('installs a zip with multipart file and enable flag', () async {
      adapter.enqueueJson(
        method: 'POST',
        path: '/system/plugins',
        statusCode: 201,
        body: <String, dynamic>{
          'plugin_id': 'demo_plugin',
          'version': '1.0.0',
          'pending_restart': <String>['api', 'aps'],
        },
      );

      await api.install(
        fileBytes: Uint8List.fromList(<int>[80, 75, 3, 4]),
        fileName: 'demo.zip',
      );

      final request = adapter.requests.single;
      final formData = request.body as FormData;
      expect(formData.files.single.key, 'file');
      expect(formData.files.single.value.filename, 'demo.zip');
      expect(
        formData.fields.singleWhere((entry) => entry.key == 'enable').value,
        'true',
      );
    });

    test('sets enabled via query parameter', () async {
      adapter.enqueueJson(
        method: 'PATCH',
        path: '/system/plugins/demo_plugin',
        body: pluginSummaryJson(enabled: true),
      );

      final updated = await api.setEnabled('demo_plugin', enabled: true);

      expect(updated.enabled, isTrue);
      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/system/plugins/demo_plugin');
      expect(request.uri.queryParameters['enabled'], 'true');
    });

    test('removes a plugin', () async {
      adapter.enqueueJson(
        method: 'DELETE',
        path: '/system/plugins/demo_plugin',
        body: <String, dynamic>{
          'plugin_id': 'demo_plugin',
          'version': '1.0.0',
          'pending_restart': <String>['api', 'aps'],
        },
      );

      await api.remove('demo_plugin');

      expect(adapter.hitCount('DELETE', '/system/plugins/demo_plugin'), 1);
    });

    test('reads and replaces plugin settings', () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/system/plugins/demo_plugin/settings',
        body: <String, dynamic>{
          'settings': <String, dynamic>{'overlap_days': 7},
        },
      );
      adapter.enqueueJson(
        method: 'PUT',
        path: '/system/plugins/demo_plugin/settings',
        body: <String, dynamic>{
          'settings': <String, dynamic>{'overlap_days': 14},
          'pending_restart': <String>['api', 'aps'],
        },
      );

      final current = await api.getSettings('demo_plugin');
      final updated = await api.updateSettings(
        'demo_plugin',
        settings: <String, dynamic>{'overlap_days': 14},
      );

      expect(current.settings['overlap_days'], 7);
      expect(updated.settings['overlap_days'], 14);
      final request = adapter.requests.last;
      expect(request.method, 'PUT');
      expect(request.body, <String, dynamic>{'overlap_days': 14});
    });
  });
}
