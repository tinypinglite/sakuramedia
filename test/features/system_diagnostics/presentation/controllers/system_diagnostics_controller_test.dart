import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_api_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
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
    'root_path': '/media',
    'created_at': null,
    'updated_at': null,
  };
}

Map<String, dynamic> _clientDto({int id = 1, String name = 'qb'}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'kind': 'qbittorrent',
    'base_url': 'http://qb.example',
    'username': 'user',
    'client_save_path': '/dl',
    'local_root_path': '/mnt/dl',
    'media_library_id': 1,
    'has_password': true,
  };
}

Map<String, dynamic> _connectivityResult({
  required bool healthy,
  int clientId = 1,
  String? errorType,
  String? errorMessage,
}) {
  return <String, dynamic>{
    'healthy': healthy,
    'checked_at': null,
    'client_id': clientId,
    'client_name': 'qb',
    'base_url': 'http://qb.example',
    'elapsed_ms': 20,
    'version': healthy ? '5.0.4' : null,
    'web_api_version': healthy ? '2.11' : null,
    'error':
        errorType == null
            ? null
            : <String, dynamic>{
              'type': errorType,
              'message': errorMessage ?? '',
            },
  };
}

Map<String, dynamic> _storageResult({required bool healthy, int clientId = 1}) {
  return <String, dynamic>{
    'healthy': healthy,
    'checked_at': null,
    'client_id': clientId,
    'client_name': 'qb',
    'elapsed_ms': 30,
    'warnings': const <String>[],
    'directory_mapping': <String, dynamic>{
      'status': healthy ? 'ok' : 'error',
      'client_save_path': '/dl',
      'local_root_path': '/mnt/dl',
      'probe_remote_dir': '/dl/.p',
      'probe_local_dir': '/mnt/dl/.p',
      'sentinel_visible_to_qb': healthy,
      'error':
          healthy
              ? null
              : <String, dynamic>{'type': 'mapping', 'message': 'nope'},
    },
    'hardlink': <String, dynamic>{
      'status': 'ok',
      'supported': true,
      'source_path': '/mnt/dl/.p/s',
      'target_path': '/media/.p/s',
      'error': null,
    },
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
                'kind': 'qbittorrent',
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
    'error':
        errorType == null
            ? null
            : <String, dynamic>{
              'type': errorType,
              'message': errorMessage ?? '',
            },
  };
}

/// 对齐后端 `StatusMetadataProviderTestResource`：带 movie_number / elapsed_ms，
/// error 带结构化 type（`StatusMetadataProviderTestError`）。
Map<String, dynamic> _providerTest({
  required bool healthy,
  String provider = 'javdb',
  String errorType = 'metadata_request_error',
  String errorMessage = 'metadata request failed: GET https://example ()',
}) {
  return <String, dynamic>{
    'healthy': healthy,
    'checked_at': '2026-07-11T08:00:00Z',
    'provider': provider,
    'movie_number': 'SSNI-888',
    'elapsed_ms': 42,
    'error':
        healthy
            ? null
            : <String, dynamic>{'type': errorType, 'message': errorMessage},
  };
}

/// 对齐后端 `StatusImageSearchResource`。向量库那一节后端也会返回，但前端不做
/// 独立诊断项，所以这里不造它。
Map<String, dynamic> _imageSearchStatus({required bool joyTagHealthy}) {
  return <String, dynamic>{
    'healthy': joyTagHealthy,
    'checked_at': '2026-07-11T08:00:00Z',
    'joytag': <String, dynamic>{
      'healthy': joyTagHealthy,
      'used_device': joyTagHealthy ? 'cuda:0' : null,
      'endpoint': 'http://joytag:8000',
      'error': joyTagHealthy ? null : 'model file not found',
    },
    'indexing': <String, dynamic>{
      'pending_thumbnails': 0,
      'failed_thumbnails': 0,
      'success_thumbnails': 15295,
    },
  };
}

// 独立探针的响应：一次性 enqueue 好，无论媒体库/下载器分支是否触发它们都会跑。
void _enqueueIndependentProbes({
  bool javdbHealthy = true,
  bool joyTagHealthy = true,
}) {
  _bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/metadata-providers/javdb/test',
    body: _providerTest(healthy: javdbHealthy, provider: 'javdb'),
  );
  _bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    body: _imageSearchStatus(joyTagHealthy: joyTagHealthy),
  );
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await _buildLoggedInSessionStore();
    _bundle = await createTestApiBundle(store);
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
      path: '/download-clients/1/test',
      body: _connectivityResult(healthy: true),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-clients/1/storage-test',
      body: _storageResult(healthy: true),
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
      method: 'GET',
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

  test('cloud115 downloader probes login state without storage test', () async {
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: <Map<String, dynamic>>[_library()],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 8,
          'name': '115 主账号',
          'kind': 'cloud115',
          'base_url': null,
          'username': null,
          'client_save_path': null,
          'local_root_path': null,
          'media_library_id': 1,
          'has_password': false,
        },
      ],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients/8/test',
      body: <String, dynamic>{
        ..._connectivityResult(healthy: true, clientId: 8),
        'client_name': '115 主账号',
        'base_url': null,
        'version': null,
        'web_api_version': null,
      },
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/indexer-settings',
      body: _indexerSettings(
        entries: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': 'dmhy',
            'url': 'https://torznab.example/api',
            'kind': 'bt',
            'download_clients': <Map<String, dynamic>>[
              <String, dynamic>{'id': 8, 'name': '115 主账号', 'kind': 'cloud115'},
            ],
          },
        ],
      ),
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/indexer-settings/test',
      body: _indexerConnectionTest(healthy: true),
    );
    _enqueueIndependentProbes();

    final controller = _newController();
    await controller.runAll();

    expect(
      _bundle.adapter.hitCount('POST', '/download-clients/8/storage-test'),
      0,
    );
    final connectivity = _find(
      controller,
      (item) => item.itemKey == 'downloader-connectivity-8',
    );
    expect(connectivity.status, DiagnosticItemStatus.healthy);
    expect(connectivity.summary, '115 登录状态正常');
  });

  test('媒体库空 → 下载器 + 索引器全部 blocked，不发多余请求', () async {
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

    final downloaderCat = c.categories.firstWhere(
      (cat) => cat.label == '下载与检索链',
    );
    expect(
      downloaderCat.items.every(
        (i) => i.status == DiagnosticItemStatus.blocked,
      ),
      isTrue,
    );

    // Stage C/D 都被跳过 → 不应看到下载器/索引器请求。
    expect(_bundle.adapter.hitCount('GET', '/download-clients'), 0);
    expect(_bundle.adapter.hitCount('GET', '/indexer-settings'), 0);
  });

  test('下载器 1 挂 + 下载器 2 通 → 索引器仍能跑', () async {
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: <Map<String, dynamic>>[_library()],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients',
      body: <Map<String, dynamic>>[
        _clientDto(id: 1, name: 'qb-a'),
        _clientDto(id: 2, name: 'qb-b'),
      ],
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients/1/test',
      body: _connectivityResult(
        healthy: false,
        clientId: 1,
        // 后端 qB 只发这一种 type，认证/网络靠 message 尽力细分。
        errorType: 'qbittorrent_request_error',
        errorMessage: 'Login authorization failed.',
      ),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-clients/1/storage-test',
      body: _storageResult(healthy: false, clientId: 1),
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients/2/test',
      body: _connectivityResult(healthy: true, clientId: 2),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-clients/2/storage-test',
      body: _storageResult(healthy: true, clientId: 2),
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/indexer-settings',
      body: _indexerSettings(
        entries: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': 'e1',
            'url': 'https://torznab.example',
            'kind': 'pt',
            'download_client_id': 2,
            'download_client_name': 'qb-b',
          },
        ],
      ),
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/indexer-settings/test',
      body: _indexerConnectionTest(healthy: true, resultCount: 0),
    );
    _enqueueIndependentProbes();

    final c = _newController();
    await c.runAll();

    // 索引器不被 block（因为有健康的下载器 2），真实搜索无候选仍代表连通正常。
    final idx = _find(c, (i) => i.kind == DiagnosticItemKind.indexer);
    expect(idx.status, DiagnosticItemStatus.healthy);
    expect(idx.summary, contains('未返回候选'));

    // 下载器 1 连通性 → unhealthy，命中 qB auth 细分 hint。
    final c1 = _find(
      c,
      (i) =>
          i.kind == DiagnosticItemKind.downloaderConnectivity &&
          i.itemKey == 'downloader-connectivity-1',
    );
    expect(c1.status, DiagnosticItemStatus.unhealthy);
    expect(c1.cause, contains('不认这个账号密码'));
    // 状态短句用后端 message，而不是内部 type 名。
    expect(c1.summary, 'Login authorization failed.');
  });

  test('下载器全挂 → 索引器 blocked', () async {
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
      path: '/download-clients/1/test',
      body: _connectivityResult(
        healthy: false,
        errorType: 'qbittorrent_request_error',
        errorMessage: 'connect timed out',
      ),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-clients/1/storage-test',
      body: _storageResult(healthy: false),
    );
    _enqueueIndependentProbes();

    final c = _newController();
    await c.runAll();

    // 索引器 blocked → 不该发 GET /indexer-settings。
    expect(_bundle.adapter.hitCount('GET', '/indexer-settings'), 0);
    final idx = _find(c, (i) => i.kind == DiagnosticItemKind.indexer);
    expect(idx.status, DiagnosticItemStatus.blocked);
    expect(idx.blockedByLabel, '下载器');
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
      path: '/download-clients/1/test',
      body: _connectivityResult(healthy: true),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-clients/1/storage-test',
      body: _storageResult(healthy: true),
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

    expect(_bundle.adapter.hitCount('GET', '/indexer-settings/test'), 0);
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
      path: '/download-clients/1/test',
      body: _connectivityResult(healthy: true),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-clients/1/storage-test',
      body: _storageResult(healthy: true),
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
      method: 'GET',
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

  test('单项 throw 不影响其他项：JavDB 抛错 → JavDB unhealthy，其他仍推进', () async {
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
    // javdb 端点直接返回 500
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/status/metadata-providers/javdb/test',
      statusCode: 500,
      body: <String, dynamic>{'message': 'boom'},
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/status/image-search',
      body: _imageSearchStatus(joyTagHealthy: true),
    );

    final c = _newController();
    await c.runAll();

    final javdb = _find(c, (i) => i.kind == DiagnosticItemKind.javdb);
    expect(javdb.status, DiagnosticItemStatus.unhealthy);
    final joyTag = _find(c, (i) => i.kind == DiagnosticItemKind.joyTag);
    expect(joyTag.status, DiagnosticItemStatus.healthy);
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
  });

  // 只跑独立探针的最小骨架：媒体库有 1 个、下载器 0 个，Stage C/D 不产生额外请求。
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

  group('元数据源：按后端 error.type 出 JavDB 文案', () {
    test('JavDB 请求失败 → 说明代理由环境变量分流并导向 wiki，不给跳转按钮', () async {
      final c = await _runWithProbes(
        enqueueProbes: () => _enqueueIndependentProbes(javdbHealthy: false),
      );

      final javdb = _find(c, (i) => i.kind == DiagnosticItemKind.javdb);
      expect(javdb.status, DiagnosticItemStatus.unhealthy);
      expect(javdb.fixHint, contains('环境变量'));
      expect(javdb.fixHint, contains('wiki'));
      // 「JavDB API 域名」不是该让用户改的字段，所以不给跳转。
      expect(javdb.fixTarget, isNull);
    });

    test('探测端点本身 500 → 用"后端故障"文案，不套站点结论', () async {
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
      _bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/status/metadata-providers/javdb/test',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'internal', 'message': 'boom'},
        },
      );
      _bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/status/image-search',
        body: _imageSearchStatus(joyTagHealthy: true),
      );

      final c = _newController();
      await c.runAll();

      final javdb = _find(c, (i) => i.kind == DiagnosticItemKind.javdb);
      expect(javdb.status, DiagnosticItemStatus.unhealthy);
      expect(javdb.cause, contains('后端没有响应'));
      // 旧实现 probe 失败会套 proxy-required 文案，让用户去查一个应用内已不存在的代理字段。
      expect(javdb.fixHint, isNot(contains('代理')));
    });
  });

  test('JoyTag 挂了 → 状态短句带上后端给的失败原因', () async {
    final c = await _runWithProbes(
      enqueueProbes: () => _enqueueIndependentProbes(joyTagHealthy: false),
    );

    final joyTag = _find(c, (i) => i.kind == DiagnosticItemKind.joyTag);
    expect(joyTag.status, DiagnosticItemStatus.unhealthy);
    // 后端带了 error，比前端硬编码的"模型未就绪"有用。
    expect(joyTag.summary, 'model file not found');
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

}
