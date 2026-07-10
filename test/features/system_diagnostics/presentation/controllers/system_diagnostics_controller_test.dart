import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_kind.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/controllers/system_diagnostics_controller.dart';

import '../../../../support/test_api_bundle.dart';

late TestApiBundle _bundle;

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

SystemDiagnosticsController _newController() {
  return SystemDiagnosticsController(
    mediaLibrariesApi: _bundle.mediaLibrariesApi,
    downloadClientsApi: _bundle.downloadClientsApi,
    indexerSettingsApi: _bundle.indexerSettingsApi,
    statusApi: _bundle.statusApi,
    llmApi: _bundle.movieDescTranslationSettingsApi,
  );
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
  String type = 'jackett',
  String apiKey = 'k',
  List<Map<String, dynamic>> entries = const <Map<String, dynamic>>[],
}) {
  return <String, dynamic>{
    'type': type,
    'api_key': apiKey,
    'indexers': entries,
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

Map<String, dynamic> _configWithLlm({
  bool enabled = true,
  String baseUrl = 'https://llm',
  String apiKey = 'sk',
  String model = 'gpt-4o-mini',
}) {
  return <String, dynamic>{
    'values': <String, dynamic>{
      'movie_info_translation': <String, dynamic>{
        'enabled': enabled,
        'base_url': baseUrl,
        'api_key': apiKey,
        'model': model,
        'timeout_seconds': 30,
        'connect_timeout_seconds': 10,
      },
    },
  };
}

Map<String, dynamic> _providerTest({
  required bool healthy,
  String provider = 'javdb',
}) {
  return <String, dynamic>{
    'healthy': healthy,
    'provider': provider,
    'error': healthy ? null : <String, dynamic>{'message': 'login required'},
  };
}

Map<String, dynamic> _imageSearchStatus({required bool joyTagHealthy}) {
  return <String, dynamic>{
    'healthy': true,
    'joytag': <String, dynamic>{
      'healthy': joyTagHealthy,
      'used_device': joyTagHealthy ? 'cuda:0' : null,
    },
    'indexing': <String, dynamic>{
      'pending_thumbnails': 0,
      'failed_thumbnails': 0,
    },
  };
}

// 独立探针的响应：一次性 enqueue 好，无论媒体库/下载器分支是否触发它们都会跑。
void _enqueueIndependentProbes({
  bool javdbHealthy = true,
  bool dmmHealthy = true,
  bool llmEnabled = true,
  bool llmOk = true,
  bool joyTagHealthy = true,
}) {
  _bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/metadata-providers/javdb/test',
    body: _providerTest(healthy: javdbHealthy, provider: 'javdb'),
  );
  _bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/metadata-providers/dmm/test',
    body: _providerTest(healthy: dmmHealthy, provider: 'dmm'),
  );
  _bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/config',
    body: _configWithLlm(enabled: llmEnabled),
  );
  if (llmEnabled) {
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movie-desc-translation-settings/test',
      body: <String, dynamic>{'ok': llmOk},
    );
  }
  _bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    body: _imageSearchStatus(joyTagHealthy: joyTagHealthy),
  );
}

DiagnosticItemState _find(
  SystemDiagnosticsController c,
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
            'url': 'https://jackett.example/api',
            'kind': 'jackett',
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
        errorType: 'auth',
        errorMessage: 'unauthorized',
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
            'url': 'https://jackett.example',
            'kind': 'jackett',
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

    // 下载器 1 连通性 → unhealthy，命中 auth-error hint。
    final c1 = _find(
      c,
      (i) =>
          i.kind == DiagnosticItemKind.downloaderConnectivity &&
          i.itemKey == 'downloader-connectivity-1',
    );
    expect(c1.status, DiagnosticItemStatus.unhealthy);
    expect(c1.cause, contains('拒绝了当前的用户名 / 密码'));
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
        errorType: 'timeout',
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
        apiKey: '',
        entries: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': 'e1',
            'url': 'https://jackett.example/api',
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
    expect(indexer.summary, 'API Key 未填');
  });

  test('Jackett 业务失败映射为可修复的索引器错误', () async {
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
            'url': 'https://jackett.example/api',
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
        errorType: 'jackett_request_error',
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
      path: '/status/metadata-providers/dmm/test',
      body: _providerTest(healthy: true, provider: 'dmm'),
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/config',
      body: _configWithLlm(),
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movie-desc-translation-settings/test',
      body: <String, dynamic>{'ok': true},
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
    final dmm = _find(c, (i) => i.kind == DiagnosticItemKind.dmm);
    expect(dmm.status, DiagnosticItemStatus.healthy);
    final llm = _find(c, (i) => i.kind == DiagnosticItemKind.llm);
    expect(llm.status, DiagnosticItemStatus.healthy);
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

  test('LLM 关掉总开关 → warning，不发 test 请求', () async {
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
    _enqueueIndependentProbes(llmEnabled: false);

    final c = _newController();
    await c.runAll();

    final llm = _find(c, (i) => i.kind == DiagnosticItemKind.llm);
    expect(llm.status, DiagnosticItemStatus.warning);
    expect(
      _bundle.adapter.hitCount('POST', '/movie-desc-translation-settings/test'),
      0,
    );
  });
}
