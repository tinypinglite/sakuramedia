import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_market_dto.dart';
import 'package:sakuramedia/features/plugins/data/plugin_market_source.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';

import '../../../support/fake_http_client_adapter.dart';
import '../../../support/logged_in_session_store.dart';
import '../support/plugin_market_test_data.dart';
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
        body: <Map<String, dynamic>>[
          pluginSummaryJson(
            enabled: true,
            testCapabilities: <String>['metadata', 'reviews'],
            testMovieNumber: 'SSIS-001',
          ),
        ],
      );

      final plugins = await api.list();

      expect(plugins.single.pluginId, 'demo_plugin');
      expect(plugins.single.displayName, '演示插件');
      expect(plugins.single.version, '1.0.0');
      expect(plugins.single.enabled, isTrue);
      expect(plugins.single.loadStatus, 'ok');
      expect(plugins.single.testCapabilities, <PluginTestCapability>[
        PluginTestCapability.metadata,
        PluginTestCapability.reviews,
      ]);
      expect(plugins.single.testMovieNumber, 'SSIS-001');
      expect(adapter.hitCount('GET', '/system/plugins'), 1);
    });

    test('tests one declared plugin capability', () async {
      adapter.enqueueJson(
        method: 'POST',
        path: '/system/plugins/demo_plugin/test',
        body: <String, dynamic>{
          'capability': 'reviews',
          'status': 'ok',
          'movie_number': 'SSIS-001',
          'duration_ms': 123,
          'reviews': <String, dynamic>{
            'item_count': 5,
            'first_username': 'tester',
            'first_excerpt': '第一页评论',
          },
        },
      );

      final result = await api.testCapability(
        'demo_plugin',
        PluginTestCapability.reviews,
      );

      expect(result.capability, PluginTestCapability.reviews);
      expect(result.status, PluginTestStatus.ok);
      expect(result.reviews?.itemCount, 5);
      final request = adapter.requests.single;
      expect(request.path, '/system/plugins/demo_plugin/test');
      expect(request.body, <String, dynamic>{'capability': 'reviews'});
      expect(request.receiveTimeout, const Duration(seconds: 90));
    });

    test('reads and updates stats/review source bindings', () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/system/plugins/bindings',
        body: _bindingsJson(
          statsSource: 'stats_plugin',
          reviewSource: 'review_plugin',
        ),
      );
      adapter.enqueueJson(
        method: 'PUT',
        path: '/system/plugins/bindings',
        body: <String, dynamic>{
          ..._bindingsJson(statsSource: 'stats_plugin_2', reviewSource: null),
          'pending_restart': <String>['api', 'aps'],
        },
      );

      final current = await api.getBindings();
      final updated = await api.updateBindings(
        statsSource: 'stats_plugin_2',
        reviewSource: null,
      );

      expect(current.statsSource, 'stats_plugin');
      expect(current.reviewSource, 'review_plugin');
      expect(current.statsSourceAvailable, isTrue);
      expect(current.statsFields.single.key, 'watched_count');
      expect(current.statsFields.single.label, '观看数');
      expect(current.availableStatsSources.first.displayName, '互动数插件');
      expect(updated.statsSource, 'stats_plugin_2');
      expect(updated.reviewSource, isNull);
      expect(updated.pendingRestart, <String>['api', 'aps']);

      final request = adapter.requests.last;
      expect(request.method, 'PUT');
      expect(request.path, '/system/plugins/bindings');
      expect(request.body, <String, dynamic>{
        'stats_source': 'stats_plugin_2',
        'review_source': null,
      });
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

    test(
      'checks a GitHub Release without sending the SakuraMedia token',
      () async {
        const releaseUrl =
            'https://api.github.com/repos/example/demo_plugin/releases/latest';
        adapter.enqueueJson(
          method: 'GET',
          path: releaseUrl,
          body: <String, dynamic>{
            'tag_name': 'v1.1.0',
            'body': '修复下载失败',
            'assets': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'demo_plugin-1.1.0.zip',
                'browser_download_url':
                    'https://github.com/example/demo/download.zip',
                'digest':
                    'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
              },
            ],
          },
        );

        final update = await api.checkForUpdate(
          pluginSummaryDto(releaseApiUrl: releaseUrl),
        );

        expect(update, isNotNull);
        expect(update!.version, '1.1.0');
        expect(update.notes, '修复下载失败');
        expect(update.sha256, hasLength(64));
        final request = adapter.requests.single;
        expect(request.path, releaseUrl);
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.connectTimeout, const Duration(seconds: 10));
        expect(request.receiveTimeout, const Duration(seconds: 10));
      },
    );

    test('treats invalid plugin versions as no update', () async {
      const releaseUrl =
          'https://api.github.com/repos/example/demo_plugin/releases/latest';
      adapter.enqueueJson(
        method: 'GET',
        path: releaseUrl,
        body: <String, dynamic>{'tag_name': 'nightly'},
      );

      final update = await api.checkForUpdate(
        pluginSummaryDto(releaseApiUrl: releaseUrl),
      );

      expect(update, isNull);
    });

    test('skips the release request for an invalid installed version', () async {
      final update = await api.checkForUpdate(
        pluginSummaryDto(
          version: 'nightly',
          releaseApiUrl:
              'https://api.github.com/repos/example/demo_plugin/releases/latest',
        ),
      );

      expect(update, isNull);
      expect(adapter.requests, isEmpty);
    });

    test(
      'downloads a release zip and uploads it to the upgrade endpoint',
      () async {
        const update = PluginReleaseUpdate(
          version: '1.1.0',
          notes: '',
          assetUrl: 'https://github.com/example/demo/download.zip',
          assetFileName: 'demo_plugin-1.1.0.zip',
          sha256:
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        );
        adapter.enqueueBytes(
          method: 'GET',
          path: update.assetUrl,
          body: Uint8List.fromList(<int>[80, 75, 3, 4]),
        );
        adapter.enqueueJson(
          method: 'POST',
          path: '/system/plugins/demo_plugin/upgrade',
          body: <String, dynamic>{
            'plugin_id': 'demo_plugin',
            'version': '1.1.0',
            'pending_restart': <String>['api', 'aps'],
          },
        );

        final bytes = await api.downloadUpdate(update);
        final version = await api.upgrade(
          pluginId: 'demo_plugin',
          update: update,
          fileBytes: bytes,
        );

        expect(version, '1.1.0');
        final request = adapter.requests.last;
        final formData = request.body as FormData;
        expect(formData.files.single.value.filename, update.assetFileName);
        expect(
          formData.fields.singleWhere((entry) => entry.key == 'sha256').value,
          update.sha256,
        );
      },
    );

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

    test('fetches the market catalog from a text/plain raw response '
        'without sending the SakuraMedia token', () async {
      // GitHub raw 返回 text/plain，dio 不会自动按 JSON 解析；
      // 用真实 content-type 复现，防止再次退化为类型转换错误。
      adapter.enqueueResponder(
        method: 'GET',
        path: kPluginMarketIndexUrl,
        responder: (options, _) async {
          return ResponseBody.fromString(
            jsonEncode(pluginMarketIndexJson()),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>['text/plain; charset=utf-8'],
            },
          );
        },
      );

      final catalog = await api.fetchMarketCatalog(kPluginMarketIndexUrl);

      expect(catalog.schemaVersion, 1);
      final item = catalog.plugins.single;
      expect(item.pluginId, 'demo_plugin');
      expect(item.official, isTrue);
      expect(item.latest!.version, '1.1.0');
      expect(item.latest!.hostApiVersion, 10);
      expect(item.latest!.sha256, hasLength(64));
      final request = adapter.requests.single;
      expect(request.path, kPluginMarketIndexUrl);
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.connectTimeout, const Duration(seconds: 15));
      expect(request.receiveTimeout, const Duration(seconds: 15));
    });

    test('parses a JSON content-type market response too', () async {
      adapter.enqueueJson(
        method: 'GET',
        path: kPluginMarketIndexUrl,
        body: pluginMarketIndexJson(),
      );

      final catalog = await api.fetchMarketCatalog(kPluginMarketIndexUrl);

      expect(catalog.plugins.single.pluginId, 'demo_plugin');
    });

    test('downloads a market release zip without the token', () async {
      final release = PluginMarketReleaseDto(
        version: '1.1.0',
        hostApiVersion: 10,
        downloadUrl:
            'https://github.com/example/demo_plugin/releases/download/'
            'v1.1.0/demo_plugin-1.1.0.zip',
      );
      adapter.enqueueBytes(
        method: 'GET',
        path: release.downloadUrl,
        body: Uint8List.fromList(<int>[80, 75, 3, 4]),
      );

      final bytes = await api.downloadMarketRelease(release);

      expect(bytes, <int>[80, 75, 3, 4]);
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('installs a market package with sha256 verification', () async {
      adapter.enqueueJson(
        method: 'POST',
        path: '/system/plugins',
        statusCode: 201,
        body: <String, dynamic>{
          'plugin_id': 'demo_plugin',
          'version': '1.1.0',
          'pending_restart': <String>['api', 'aps'],
        },
      );

      await api.install(
        fileBytes: Uint8List.fromList(<int>[80, 75, 3, 4]),
        fileName: 'demo_plugin-1.1.0.zip',
        sha256:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );

      final formData = adapter.requests.single.body as FormData;
      expect(formData.files.single.value.filename, 'demo_plugin-1.1.0.zip');
      expect(
        formData.fields.singleWhere((entry) => entry.key == 'sha256').value,
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
    });
  });
}

Map<String, dynamic> _bindingsJson({
  required String? statsSource,
  required String? reviewSource,
}) {
  return <String, dynamic>{
    'stats_source': statsSource,
    'review_source': reviewSource,
    'stats_source_available': statsSource != null,
    'review_source_available': reviewSource != null,
    'stats_source_display_name': statsSource == null ? null : '互动数插件',
    'review_source_display_name': reviewSource == null ? null : '评论插件',
    'stats_fields': <Map<String, dynamic>>[
      <String, dynamic>{
        'key': 'watched_count',
        'label': '观看数',
        'value_type': 'int',
        'min': 0,
        'max': null,
        'unit': null,
      },
    ],
    'heat_version': 'plugin:v1',
    'available_stats_sources': <Map<String, dynamic>>[
      <String, dynamic>{'plugin_id': 'stats_plugin', 'display_name': '互动数插件'},
      <String, dynamic>{
        'plugin_id': 'stats_plugin_2',
        'display_name': '互动数插件 2',
      },
    ],
    'available_review_sources': <Map<String, dynamic>>[
      <String, dynamic>{'plugin_id': 'review_plugin', 'display_name': '评论插件'},
    ],
  };
}
