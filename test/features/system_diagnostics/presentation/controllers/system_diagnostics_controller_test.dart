import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/metadata_sources_api.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/metadata_sources_api_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_category_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_kind.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/controllers/system_diagnostics_controller.dart';

import '../../../../support/test_api_bundle.dart';

late TestApiBundle _bundle;
ProviderContainer? _container;

Future<SessionStore> _buildLoggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 't',
    refreshToken: 'r',
    expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
  );
  return store;
}

_SystemDiagnosticsHarness _newController() {
  _container = ProviderContainer(
    overrides: [
      mediaLibrariesApiProvider.overrideWithValue(_bundle.mediaLibrariesApi),
      metadataSourcesApiProvider.overrideWithValue(
        MetadataSourcesApi(apiClient: _bundle.apiClient),
      ),
      pluginsApiProvider.overrideWithValue(
        PluginsApi(apiClient: _bundle.apiClient),
      ),
      downloadClientsApiProvider.overrideWithValue(_bundle.downloadClientsApi),
      indexerSettingsApiProvider.overrideWithValue(_bundle.indexerSettingsApi),
      statusApiProvider.overrideWithValue(_bundle.statusApi),
    ],
    retry: (_, __) => null,
  );
  _container!.listen<SystemDiagnosticsState>(
    systemDiagnosticsProvider(SystemDiagnosticsHost.desktopPage),
    (_, _) {},
  );
  final notifier = _container!.read(
    systemDiagnosticsProvider(SystemDiagnosticsHost.desktopPage).notifier,
  );
  return _SystemDiagnosticsHarness(notifier);
}

class _SystemDiagnosticsHarness {
  const _SystemDiagnosticsHarness(this._notifier);

  final SystemDiagnostics _notifier;

  Future<void> runAll() => _notifier.runAll();
  List<DiagnosticCategoryState> get categories => _notifier.state.categories;
  DiagnosticItemStatus get overallStatus => _notifier.state.overallStatus;
  int get unhealthyCount => _notifier.state.unhealthyCount;
  DateTime? get lastRunAt => _notifier.state.lastRunAt;
}

Map<String, dynamic> _library({int id = 1, String name = 'Main'}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'provider_key': 'demo',
    'provider_config': <String, dynamic>{'root': '/media'},
    'created_at': null,
    'updated_at': null,
  };
}

Map<String, dynamic> _clientDto({int id = 1, String name = 'qb'}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'provider_config': <String, dynamic>{'endpoint': 'http://qb.example'},
    'library_id': 1,
  };
}

Map<String, dynamic> _indexerSettings({
  List<Map<String, dynamic>> entries = const <Map<String, dynamic>>[],
}) {
  return <String, dynamic>{
    'indexers': entries
        .map((entry) {
          if (entry.containsKey('download_clients')) return entry;
          return <String, dynamic>{
            ...entry,
            'download_clients': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': entry['download_client_id'],
                'name': entry['download_client_name'],
              },
            ],
          };
        })
        .toList(growable: false),
  };
}

Map<String, dynamic> _indexerConnectionTest({
  required bool healthy,
  int indexersChecked = 1,
  int resultCount = 2,
  int elapsedMs = 24,
  String? errorType,
  String? errorMessage,
}) {
  return <String, dynamic>{
    'healthy': healthy,
    'checked_at': '2026-07-11T08:00:00Z',
    'query': 'SSNI-888',
    'indexers_checked': indexersChecked,
    'result_count': resultCount,
    'elapsed_ms': elapsedMs,
    'error': errorType == null
        ? null
        : <String, dynamic>{'type': errorType, 'message': errorMessage ?? ''},
  };
}

/// 对齐后端 `StatusImageSearchResource`。向量库那一节后端也会返回，但前端不做
/// 独立诊断项，所以这里不造它。
Map<String, dynamic> _imageSearchStatus({
  required bool joyTagHealthy,
  bool enabled = true,
}) {
  return <String, dynamic>{
    'enabled': enabled,
    'healthy': joyTagHealthy,
    'checked_at': '2026-07-11T08:00:00Z',
    'embedding_service': <String, dynamic>{
      'healthy': joyTagHealthy,
      'space_id': 'clip-vit-l-14',
      'dimension': 768,
      'modalities': <String>['image', 'text'],
      'endpoint': 'http://embedding:8000',
      'error': joyTagHealthy ? null : 'model file not found',
    },
    'indexing': <String, dynamic>{
      'pending_thumbnails': 0,
      'failed_thumbnails': 0,
    },
  };
}

Map<String, dynamic> _metadataSource({
  required String pluginId,
  required String displayName,
}) {
  return <String, dynamic>{'plugin_id': pluginId, 'display_name': displayName};
}

Map<String, dynamic> _metadataTestResult({
  String status = 'ok',
  String movieNumber = 'SSIS-001',
  int durationMs = 25,
  String title = '测试影片',
  int actorCount = 2,
  int tagCount = 6,
  int imageCount = 4,
  String? errorMessage,
  bool includeMetadata = true,
}) {
  return <String, dynamic>{
    'capability': 'metadata',
    'status': status,
    'movie_number': movieNumber,
    'duration_ms': durationMs,
    if (status == 'ok' && includeMetadata)
      'metadata': <String, dynamic>{
        'movie_number': movieNumber,
        'title': title,
        'release_date': '2024-01-01',
        'duration_minutes': 120,
        'actor_count': actorCount,
        'tag_count': tagCount,
        'image_count': imageCount,
      },
    'error_message': ?errorMessage,
  };
}

// 独立探针的响应：一次性 enqueue 好，媒体库/索引器分支是否继续都不影响
// 嵌入服务探针执行。
void _enqueueIndependentProbes({
  bool joyTagHealthy = true,
  bool joyTagEnabled = true,
}) {
  _bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    body: _imageSearchStatus(
      joyTagHealthy: joyTagHealthy,
      enabled: joyTagEnabled,
    ),
  );
}

/// 除元数据源外全部健康的底座，便于单独断言元数据分支。
void _enqueueHealthyBase() {
  _bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: <Map<String, dynamic>>[_library()],
  );
  _bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    body: <Map<String, dynamic>>[_clientDto()],
  );
  _bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/indexer-settings',
    body: _indexerSettings(
      entries: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'e1',
          'url': 'https://torznab.example/api',
          'kind': 'pt',
          'download_client_id': 1,
          'download_client_name': 'qb',
        },
      ],
    ),
  );
  _bundle.adapter.enqueueJson(
    method: 'POST',
    path: '/indexer-settings/test',
    body: _indexerConnectionTest(healthy: true),
  );
  _enqueueIndependentProbes();
}

DiagnosticItemState _find(
  _SystemDiagnosticsHarness c,
  bool Function(DiagnosticItemState) predicate,
) {
  for (final cat in c.categories) {
    for (final item in cat.items) {
      if (predicate(item)) return item;
    }
  }
  fail('未找到满足条件的诊断项');
}

List<DiagnosticItemState> _findAll(
  _SystemDiagnosticsHarness c,
  bool Function(DiagnosticItemState) predicate,
) {
  return <DiagnosticItemState>[
    for (final cat in c.categories)
      for (final item in cat.items)
        if (predicate(item)) item,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await _buildLoggedInSessionStore();
    _bundle = await createTestApiBundle(store);
    _bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/system/metadata-sources',
      body: <Map<String, dynamic>>[
        _metadataSource(pluginId: 'meta_default', displayName: '默认元数据源'),
      ],
    );
    _bundle.adapter.setFallbackJson(
      method: 'POST',
      path: '/system/plugins/meta_default/test',
      body: _metadataTestResult(title: '默认测试影片'),
    );
  });

  tearDown(() {
    _container?.dispose();
    _container = null;
    _bundle.dispose();
  });

  test('happy path：全部通过 → overall healthy', () async {
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: <Map<String, dynamic>>[_library()],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients',
      body: <Map<String, dynamic>>[_clientDto()],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/indexer-settings',
      body: _indexerSettings(
        entries: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': 'e1',
            'url': 'https://torznab.example/api',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'qb',
          },
        ],
      ),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/indexer-settings/test',
      body: _indexerConnectionTest(healthy: true),
    );
    _enqueueIndependentProbes();

    final c = _newController();
    await c.runAll();

    expect(c.overallStatus, DiagnosticItemStatus.healthy);
    expect(c.unhealthyCount, 0);
    expect(c.lastRunAt, isNotNull);
    final ml = _find(c, (i) => i.kind == DiagnosticItemKind.mediaLibrary);
    expect(ml.status, DiagnosticItemStatus.healthy);
    final indexer = _find(c, (i) => i.kind == DiagnosticItemKind.indexer);
    expect(indexer.status, DiagnosticItemStatus.healthy);
    expect(indexer.summary, contains('2 条候选'));
  });

  test('媒体库为空 → 索引器 blocked，不发索引器请求', () async {
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: <Map<String, dynamic>>[],
    );
    _enqueueIndependentProbes();

    final c = _newController();
    await c.runAll();

    final ml = _find(c, (i) => i.kind == DiagnosticItemKind.mediaLibrary);
    expect(ml.status, DiagnosticItemStatus.unhealthy);

    final chainCat = c.categories.firstWhere((cat) => cat.label == '下载与检索链');
    expect(
      chainCat.items.every((i) => i.status == DiagnosticItemStatus.blocked),
      isTrue,
    );

    // 媒体库未就绪时索引器阶段被跳过；嵌入服务探针仍会完成。
    expect(_bundle.adapter.hitCount('GET', '/download-clients'), 0);
    expect(_bundle.adapter.hitCount('GET', '/indexer-settings'), 0);
  });

  test('索引器静态校验失败时不发起真实搜索', () async {
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: <Map<String, dynamic>>[_library()],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients',
      body: <Map<String, dynamic>>[_clientDto()],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/indexer-settings',
      body: _indexerSettings(
        entries: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': 'e1',
            'url': 'not-a-url',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'qb',
          },
        ],
      ),
    );
    _enqueueIndependentProbes();

    final c = _newController();
    await c.runAll();

    expect(_bundle.adapter.hitCount('POST', '/indexer-settings/test'), 0);
    final indexer = _find(c, (i) => i.kind == DiagnosticItemKind.indexer);
    expect(indexer.status, DiagnosticItemStatus.unhealthy);
    expect(indexer.summary, '存在非法 tracker URL');
  });

  test('Torznab 业务失败映射为可修复的索引器错误', () async {
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: <Map<String, dynamic>>[_library()],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients',
      body: <Map<String, dynamic>>[_clientDto()],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/indexer-settings',
      body: _indexerSettings(
        entries: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': 'e1',
            'url': 'https://torznab.example/api',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'qb',
          },
        ],
      ),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/indexer-settings/test',
      body: _indexerConnectionTest(
        healthy: false,
        errorType: 'torznab_request_error',
        errorMessage: 'connection refused',
      ),
    );
    _enqueueIndependentProbes();

    final c = _newController();
    await c.runAll();

    final indexer = _find(c, (i) => i.kind == DiagnosticItemKind.indexer);
    expect(indexer.status, DiagnosticItemStatus.unhealthy);
    expect(indexer.summary, 'connection refused');
    expect(indexer.fixHint, contains('API Key'));
  });

  test('runAll 幂等：正在跑时二次调用被吞掉', () async {
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: <Map<String, dynamic>>[_library()],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients',
      body: <Map<String, dynamic>>[],
    );
    _enqueueIndependentProbes();

    final c = _newController();
    final first = c.runAll();
    // 第二次调用应立即 return，不产生新的 HTTP hit。
    final second = c.runAll();
    await Future.wait<void>([first, second]);

    expect(_bundle.adapter.hitCount('GET', '/media-libraries'), 1);
    expect(_bundle.adapter.hitCount('GET', '/system/metadata-sources'), 1);
    expect(
      _bundle.adapter.hitCount('POST', '/system/plugins/meta_default/test'),
      1,
    );
  });

  // 独立探针场景的最小骨架：媒体库有 1 个，索引器配置列表为空，
  // 只验证嵌入服务的结果与媒体库状态互不干扰。
  Future<_SystemDiagnosticsHarness> _runWithProbes({
    required void Function() enqueueProbes,
  }) async {
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: <Map<String, dynamic>>[_library()],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients',
      body: <Map<String, dynamic>>[],
    );
    enqueueProbes();
    final c = _newController();
    await c.runAll();
    return c;
  }

  test('JoyTag 挂了 → 状态短句带上后端给的失败原因', () async {
    final c = await _runWithProbes(
      enqueueProbes: () => _enqueueIndependentProbes(joyTagHealthy: false),
    );

    final joyTag = _find(c, (i) => i.kind == DiagnosticItemKind.joyTag);
    expect(joyTag.status, DiagnosticItemStatus.unhealthy);
    // 后端带了 error，比前端硬编码的"模型未就绪"有用。
    expect(joyTag.summary, 'model file not found');
  });

  test('图搜未启用 → 嵌入服务显示未启用，不算故障', () async {
    final c = await _runWithProbes(
      enqueueProbes: () => _enqueueIndependentProbes(joyTagEnabled: false),
    );

    final joyTag = _find(c, (i) => i.kind == DiagnosticItemKind.joyTag);
    expect(joyTag.status, DiagnosticItemStatus.disabled);
    expect(joyTag.summary, contains('未启用'));
  });

  test('媒体库列表接口失败 → 不再谎报"还没有配置媒体库"', () async {
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'internal_error',
          'message': '数据库连接失败',
        },
      },
    );
    _enqueueIndependentProbes();

    final c = _newController();
    await c.runAll();

    final ml = _find(c, (i) => i.kind == DiagnosticItemKind.mediaLibrary);
    expect(ml.status, DiagnosticItemStatus.unhealthy);
    expect(ml.cause, contains('后端没有正常响应'));
    expect(ml.cause, isNot(contains('还没有配置任何媒体库')));
    expect(ml.summary, '数据库连接失败');
    // 这一条不该给"去建媒体库"的跳转。
    expect(ml.fixTarget, isNull);
  });

  test('元数据源逐个调用真实插件测试接口并按顺序展示', () async {
    _enqueueHealthyBase();
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/metadata-sources',
      body: <Map<String, dynamic>>[
        _metadataSource(pluginId: 'meta_a', displayName: '元数据 A'),
        _metadataSource(pluginId: 'meta_b', displayName: '元数据 B'),
      ],
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/meta_a/test',
      body: _metadataTestResult(title: '影片 A'),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/meta_b/test',
      body: _metadataTestResult(
        title: '影片 B',
        actorCount: 3,
        tagCount: 7,
        imageCount: 5,
      ),
    );

    final c = _newController();
    await c.runAll();

    final items = _findAll(
      c,
      (i) => i.kind == DiagnosticItemKind.metadataSource,
    );
    expect(items.map((i) => i.displayName), <String>['元数据 A', '元数据 B']);
    expect(items.map((i) => i.status), <DiagnosticItemStatus>[
      DiagnosticItemStatus.healthy,
      DiagnosticItemStatus.healthy,
    ]);
    expect(items.first.summary, contains('影片 A'));
    expect(items.last.summary, contains('影片 B'));
    expect(c.overallStatus, DiagnosticItemStatus.healthy);

    final requests = _bundle.adapter.requests
        .where(
          (request) =>
              request.method == 'POST' &&
              request.path.startsWith('/system/plugins/meta_'),
        )
        .toList(growable: false);
    expect(requests.length, 2);
    expect(
      requests.map((request) => request.body),
      everyElement(equals(<String, dynamic>{'capability': 'metadata'})),
    );
  });

  test('元数据源 ok/empty/failed 分别映射为 healthy/warning/unhealthy', () async {
    _enqueueHealthyBase();
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/metadata-sources',
      body: <Map<String, dynamic>>[
        _metadataSource(pluginId: 'meta_ok', displayName: '正常源'),
        _metadataSource(pluginId: 'meta_empty', displayName: '空结果源'),
        _metadataSource(pluginId: 'meta_failed', displayName: '失败源'),
      ],
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/meta_ok/test',
      body: _metadataTestResult(title: '正常影片'),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/meta_empty/test',
      body: _metadataTestResult(
        status: 'empty',
        movieNumber: 'FC2-PPV-4972378',
        includeMetadata: false,
      ),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/meta_failed/test',
      body: _metadataTestResult(
        status: 'failed',
        includeMetadata: false,
        errorMessage: 'upstream unavailable',
      ),
    );

    final c = _newController();
    await c.runAll();

    final items = _findAll(
      c,
      (i) => i.kind == DiagnosticItemKind.metadataSource,
    );
    expect(items.map((i) => i.status), <DiagnosticItemStatus>[
      DiagnosticItemStatus.healthy,
      DiagnosticItemStatus.warning,
      DiagnosticItemStatus.unhealthy,
    ]);
    expect(items[1].summary, contains('FC2-PPV-4972378'));
    expect(items[1].fixTarget, isNotNull);
    expect(items[2].summary, 'upstream unavailable');
    expect(items[2].fixTarget, isNotNull);
    expect(c.overallStatus, DiagnosticItemStatus.unhealthy);
  });

  test('元数据源单次请求失败不影响其他源', () async {
    _enqueueHealthyBase();
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/metadata-sources',
      body: <Map<String, dynamic>>[
        _metadataSource(pluginId: 'meta_ok', displayName: '正常源'),
        _metadataSource(pluginId: 'meta_error', displayName: '请求失败源'),
      ],
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/meta_ok/test',
      body: _metadataTestResult(title: '正常影片'),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/meta_error/test',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'internal_error',
          'message': '插件测试崩溃',
        },
      },
    );

    final c = _newController();
    await c.runAll();

    final items = _findAll(
      c,
      (i) => i.kind == DiagnosticItemKind.metadataSource,
    );
    expect(items[0].status, DiagnosticItemStatus.healthy);
    expect(items[1].status, DiagnosticItemStatus.unhealthy);
    expect(items[1].summary, '插件测试崩溃');
    expect(items[1].fixTarget, isNull);
  });

  test('元数据源列表读取失败 → 单项 unhealthy，其他诊断继续', () async {
    _enqueueHealthyBase();
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/metadata-sources',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'internal_error',
          'message': '数据库连接失败',
        },
      },
    );

    final c = _newController();
    await c.runAll();

    final items = _findAll(
      c,
      (i) => i.kind == DiagnosticItemKind.metadataSource,
    );
    expect(items, hasLength(1));
    expect(items.single.status, DiagnosticItemStatus.unhealthy);
    expect(items.single.summary, '数据库连接失败');
    expect(items.single.cause, contains('后端没有正常响应'));
    expect(
      _find(c, (i) => i.kind == DiagnosticItemKind.mediaLibrary).status,
      DiagnosticItemStatus.healthy,
    );
  });

  test('没有启用元数据源 → warning，且不发插件测试请求', () async {
    _enqueueHealthyBase();
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/metadata-sources',
      body: <Map<String, dynamic>>[],
    );

    final c = _newController();
    await c.runAll();

    final items = _findAll(
      c,
      (i) => i.kind == DiagnosticItemKind.metadataSource,
    );
    expect(items, hasLength(1));
    expect(items.single.status, DiagnosticItemStatus.warning);
    expect(items.single.summary, '未启用元数据插件');
    expect(items.single.fixTarget, isNotNull);
    expect(
      _bundle.adapter.requests.where(
        (request) =>
            request.method == 'POST' &&
            request.path.startsWith('/system/plugins/'),
      ),
      isEmpty,
    );
  });

  test('ok 但没有 metadata 载荷 → unhealthy', () async {
    _enqueueHealthyBase();
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/metadata-sources',
      body: <Map<String, dynamic>>[
        _metadataSource(pluginId: 'meta_bad', displayName: '坏返回源'),
      ],
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/meta_bad/test',
      body: _metadataTestResult(includeMetadata: false),
    );

    final c = _newController();
    await c.runAll();

    final item = _find(c, (i) => i.kind == DiagnosticItemKind.metadataSource);
    expect(item.status, DiagnosticItemStatus.unhealthy);
    expect(item.summary, '插件测试失败');
  });
}
