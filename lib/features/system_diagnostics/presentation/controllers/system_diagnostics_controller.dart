import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/api/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/api/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/movie_desc_translation_settings_dto.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_category_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_kind.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/downloader_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/indexer_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/joytag_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/llm_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/media_library_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/metadata_provider_hints.dart';

/// 一次「组件诊断」检测的调度器。
///
/// 调度算法（[runAll]）：
///   Stage A（基础资源）：媒体库。空 → 后置全部 blocked。
///   Stage B（独立探针，与 A 并行）：JavDB / DMM / LLM / JoyTag。
///   Stage C（依赖 A）：下载器（每个 client → 连通性 + 存储 两项，全部并发）。
///   Stage D（依赖 C）：索引器 —— 静态校验、下载器绑定核对和真实搜索测试。
///
/// 单项 try/catch 隔离，任何一项抛异常不影响整体流水推进。
class SystemDiagnosticsController extends ChangeNotifier {
  SystemDiagnosticsController({
    required MediaLibrariesApi mediaLibrariesApi,
    required DownloadClientsApi downloadClientsApi,
    required IndexerSettingsApi indexerSettingsApi,
    required StatusApi statusApi,
    required MovieDescTranslationSettingsApi llmApi,
  }) : _mediaLibrariesApi = mediaLibrariesApi,
       _downloadClientsApi = downloadClientsApi,
       _indexerSettingsApi = indexerSettingsApi,
       _statusApi = statusApi,
       _llmApi = llmApi {
    _categories = _buildInitialCategories();
  }

  final MediaLibrariesApi _mediaLibrariesApi;
  final DownloadClientsApi _downloadClientsApi;
  final IndexerSettingsApi _indexerSettingsApi;
  final StatusApi _statusApi;
  final MovieDescTranslationSettingsApi _llmApi;

  static const String _mediaLibraryItemKey = 'media-library';
  static const String _indexerItemKey = 'indexer';
  static const String _javdbItemKey = 'javdb';
  static const String _dmmItemKey = 'dmm';
  static const String _llmItemKey = 'llm';
  static const String _joyTagItemKey = 'joytag';

  bool _isRunning = false;
  DateTime? _lastRunAt;
  late List<DiagnosticCategoryState> _categories;

  // 保留一份下载器 diagnostics 原始 DTO，供 tile 上的「查看诊断详情」dialog 复用。
  final Map<int, DownloadClientTestResultDto> _lastConnectivityResults =
      <int, DownloadClientTestResultDto>{};
  final Map<int, DownloadClientStorageTestResultDto> _lastStorageResults =
      <int, DownloadClientStorageTestResultDto>{};
  final Map<int, DownloadClientDto> _lastKnownClients =
      <int, DownloadClientDto>{};

  bool get isRunning => _isRunning;
  DateTime? get lastRunAt => _lastRunAt;
  List<DiagnosticCategoryState> get categories => _categories;

  DiagnosticItemStatus get overallStatus =>
      mergeDiagnosticStatuses(_categories.map((cat) => cat.aggregate));

  int get unhealthyCount {
    var count = 0;
    for (final cat in _categories) {
      for (final item in cat.items) {
        if (item.status == DiagnosticItemStatus.unhealthy) count++;
      }
    }
    return count;
  }

  int get totalItemCount {
    var count = 0;
    for (final cat in _categories) {
      count += cat.items.length;
    }
    return count;
  }

  int get completedItemCount {
    var count = 0;
    for (final cat in _categories) {
      for (final item in cat.items) {
        if (item.status != DiagnosticItemStatus.notTested &&
            item.status != DiagnosticItemStatus.probing) {
          count++;
        }
      }
    }
    return count;
  }

  DownloadClientTestResultDto? connectivityResultFor(int clientId) =>
      _lastConnectivityResults[clientId];
  DownloadClientStorageTestResultDto? storageResultFor(int clientId) =>
      _lastStorageResults[clientId];
  DownloadClientDto? clientFor(int clientId) => _lastKnownClients[clientId];

  /// 幂等：正在跑就直接 return。
  Future<void> runAll() async {
    if (_isRunning) return;
    _isRunning = true;
    _categories = _buildInitialCategories(status: DiagnosticItemStatus.probing);
    notifyListeners();

    // Stage A + Stage B 完全并发（独立项互不依赖）。
    final mediaLibraryFuture = _probeMediaLibrary();
    final javdbFuture = _probeMetadataProvider(_javdbItemKey);
    final dmmFuture = _probeMetadataProvider(_dmmItemKey);
    final llmFuture = _probeLlm();
    final joyTagFuture = _probeJoyTag();

    final mediaLibrary = await mediaLibraryFuture;
    _replaceItem('基础资源', mediaLibrary);
    notifyListeners();

    // Stage C：媒体库不通 → 下载器 + 索引器全 blocked。
    if (mediaLibrary.status != DiagnosticItemStatus.healthy) {
      _replaceCategoryItems('下载与检索链', <DiagnosticItemState>[
        DiagnosticItemState.blocked(
          kind: DiagnosticItemKind.downloaderConnectivity,
          itemKey: 'downloader-blocked',
          displayName: '下载器',
          blockedByLabel: '媒体库',
        ),
        DiagnosticItemState.blocked(
          kind: DiagnosticItemKind.indexer,
          itemKey: _indexerItemKey,
          displayName: '索引器',
          blockedByLabel: '媒体库',
        ),
      ]);
    } else {
      final downloaderItems = await _probeAllDownloaders();
      final indexerItem = await _probeIndexer(
        downloaderConnectivityItems: downloaderItems
            .where(
              (item) => item.kind == DiagnosticItemKind.downloaderConnectivity,
            )
            .toList(growable: false),
      );
      _replaceCategoryItems('下载与检索链', <DiagnosticItemState>[
        ...downloaderItems,
        indexerItem,
      ]);
    }
    notifyListeners();

    // 收 stage B。
    final javdb = await javdbFuture;
    final dmm = await dmmFuture;
    _replaceCategoryItems('外部数据源', <DiagnosticItemState>[javdb, dmm]);

    final llm = await llmFuture;
    final joyTag = await joyTagFuture;
    _replaceCategoryItems('智能能力', <DiagnosticItemState>[llm, joyTag]);

    _isRunning = false;
    _lastRunAt = DateTime.now();
    notifyListeners();
  }

  // --------- 单项探针 ---------

  Future<DiagnosticItemState> _probeMediaLibrary() async {
    final started = DateTime.now();
    try {
      final libraries = await _mediaLibrariesApi.getLibraries();
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      if (libraries.isEmpty) {
        return _fromHint(
          kind: DiagnosticItemKind.mediaLibrary,
          itemKey: _mediaLibraryItemKey,
          displayName: '媒体库',
          status: DiagnosticItemStatus.unhealthy,
          hint: mediaLibraryEmptyHint,
          elapsedMs: elapsed,
          summary: '尚未配置任何媒体库',
        );
      }
      return DiagnosticItemState.healthy(
        kind: DiagnosticItemKind.mediaLibrary,
        itemKey: _mediaLibraryItemKey,
        displayName: '媒体库',
        elapsedMs: elapsed,
        summary: _mediaLibrarySummary(libraries),
      );
    } catch (_) {
      return _fromHint(
        kind: DiagnosticItemKind.mediaLibrary,
        itemKey: _mediaLibraryItemKey,
        displayName: '媒体库',
        status: DiagnosticItemStatus.unhealthy,
        hint: mediaLibraryEmptyHint,
        summary: '接口调用失败',
      );
    }
  }

  Future<List<DiagnosticItemState>> _probeAllDownloaders() async {
    final List<DownloadClientDto> clients;
    try {
      clients = await _downloadClientsApi.getClients();
    } catch (_) {
      return <DiagnosticItemState>[
        _fromHint(
          kind: DiagnosticItemKind.downloaderConnectivity,
          itemKey: 'downloader-list-error',
          displayName: '下载器',
          status: DiagnosticItemStatus.unhealthy,
          hint: downloaderConnectivityHints['unknown']!,
          summary: '获取下载器列表失败',
        ),
      ];
    }

    _lastKnownClients
      ..clear()
      ..addEntries(clients.map((c) => MapEntry(c.id, c)));
    _lastConnectivityResults.clear();
    _lastStorageResults.clear();

    if (clients.isEmpty) {
      return <DiagnosticItemState>[
        DiagnosticItemState(
          kind: DiagnosticItemKind.downloaderConnectivity,
          itemKey: 'downloader-empty',
          displayName: '下载器',
          status: DiagnosticItemStatus.unhealthy,
          summary: '尚未配置任何下载器',
          cause: '还没有配置 qBittorrent 下载器，影片详情里的下载按钮会全部 disabled。',
          fixHint: '在「下载器」页新增一个 qBittorrent 客户端，绑定媒体库。',
          impact: '影片详情无法投递下载；索引器也拿不到下载出口。',
          fixTarget: const DiagnosticFixTarget.configurationTab(2),
        ),
      ];
    }

    return Future.wait<DiagnosticItemState>([
      for (final client in clients) ...<Future<DiagnosticItemState>>[
        _probeDownloaderConnectivity(client),
        _probeDownloaderStorage(client),
      ],
    ]);
  }

  Future<DiagnosticItemState> _probeDownloaderConnectivity(
    DownloadClientDto client,
  ) async {
    try {
      final result = await _downloadClientsApi.testClient(client.id);
      _lastConnectivityResults[client.id] = result;
      if (result.healthy) {
        return DiagnosticItemState.healthy(
          kind: DiagnosticItemKind.downloaderConnectivity,
          itemKey: 'downloader-connectivity-${client.id}',
          displayName: '${client.name} · 连通性',
          elapsedMs: result.elapsedMs,
          summary: _downloaderVersionSummary(result),
        );
      }
      final hintKey = resolveDownloaderConnectivityHintKey(result.error);
      final hint =
          downloaderConnectivityHints[hintKey] ??
          downloaderConnectivityHints['unknown']!;
      return _fromHint(
        kind: DiagnosticItemKind.downloaderConnectivity,
        itemKey: 'downloader-connectivity-${client.id}',
        displayName: '${client.name} · 连通性',
        status: DiagnosticItemStatus.unhealthy,
        hint: hint,
        elapsedMs: result.elapsedMs,
        summary:
            result.error?.type.isNotEmpty == true ? result.error!.type : '连通失败',
      );
    } catch (_) {
      return _fromHint(
        kind: DiagnosticItemKind.downloaderConnectivity,
        itemKey: 'downloader-connectivity-${client.id}',
        displayName: '${client.name} · 连通性',
        status: DiagnosticItemStatus.unhealthy,
        hint: downloaderConnectivityHints['network-error']!,
        summary: '请求异常',
      );
    }
  }

  Future<DiagnosticItemState> _probeDownloaderStorage(
    DownloadClientDto client,
  ) async {
    try {
      final result = await _downloadClientsApi.storageTestClient(client.id);
      _lastStorageResults[client.id] = result;
      if (result.healthy && result.warnings.isEmpty) {
        return DiagnosticItemState.healthy(
          kind: DiagnosticItemKind.downloaderStorage,
          itemKey: 'downloader-storage-${client.id}',
          displayName: '${client.name} · 目录映射',
          elapsedMs: result.elapsedMs,
          summary: '目录映射 + 硬链接均通过',
        );
      }
      final hintKey = resolveDownloaderStorageHintKey(result);
      final hint =
          downloaderStorageHints[hintKey] ?? downloaderStorageHints['unknown']!;
      // 业务上 healthy 但带 warnings（例如硬链接不支持）→ 落 warning，不阻塞。
      final status =
          result.healthy
              ? DiagnosticItemStatus.warning
              : DiagnosticItemStatus.unhealthy;
      return _fromHint(
        kind: DiagnosticItemKind.downloaderStorage,
        itemKey: 'downloader-storage-${client.id}',
        displayName: '${client.name} · 目录映射',
        status: status,
        hint: hint,
        elapsedMs: result.elapsedMs,
        summary:
            result.warnings.isNotEmpty
                ? result.warnings.first
                : (status == DiagnosticItemStatus.unhealthy
                    ? '存储映射不通'
                    : '存在告警'),
      );
    } catch (_) {
      return _fromHint(
        kind: DiagnosticItemKind.downloaderStorage,
        itemKey: 'downloader-storage-${client.id}',
        displayName: '${client.name} · 目录映射',
        status: DiagnosticItemStatus.unhealthy,
        hint: downloaderStorageHints['unknown']!,
        summary: '请求异常',
      );
    }
  }

  Future<DiagnosticItemState> _probeIndexer({
    required List<DiagnosticItemState> downloaderConnectivityItems,
  }) async {
    // 下载器一个都没健康 → 索引器 blocked。
    final anyHealthyDownloader = downloaderConnectivityItems.any(
      (item) => item.status == DiagnosticItemStatus.healthy,
    );
    if (!anyHealthyDownloader) {
      return DiagnosticItemState.blocked(
        kind: DiagnosticItemKind.indexer,
        itemKey: _indexerItemKey,
        displayName: '索引器',
        blockedByLabel: '下载器',
      );
    }

    try {
      final settings = await _indexerSettingsApi.getSettings();
      final List<DownloadClientDto> clients = _lastKnownClients.values.toList(
        growable: false,
      );
      final hintKey = resolveIndexerConfigHintKey(
        settings: settings,
        existingClients: clients,
      );
      if (hintKey != null) {
        return _fromHint(
          kind: DiagnosticItemKind.indexer,
          itemKey: _indexerItemKey,
          displayName: '索引器',
          status: DiagnosticItemStatus.unhealthy,
          hint: indexerHints[hintKey] ?? indexerHints['jackett-request-error']!,
          summary: _indexerSummary(hintKey, settings),
        );
      }

      final result = await _indexerSettingsApi.testConnection();
      if (result.healthy) {
        return DiagnosticItemState.healthy(
          kind: DiagnosticItemKind.indexer,
          itemKey: _indexerItemKey,
          displayName: '索引器',
          elapsedMs: result.elapsedMs,
          summary: _indexerConnectionSummary(result),
        );
      }
      final connectionHintKey = resolveIndexerConnectionHintKey(
        result.error?.type,
      );
      return _fromHint(
        kind: DiagnosticItemKind.indexer,
        itemKey: _indexerItemKey,
        displayName: '索引器',
        status: DiagnosticItemStatus.unhealthy,
        hint: indexerHints[connectionHintKey]!,
        elapsedMs: result.elapsedMs,
        summary: _indexerConnectionErrorSummary(result),
      );
    } catch (_) {
      return _fromHint(
        kind: DiagnosticItemKind.indexer,
        itemKey: _indexerItemKey,
        displayName: '索引器',
        status: DiagnosticItemStatus.unhealthy,
        hint: indexerHints['jackett-request-error']!,
        summary: '索引器配置或连通性检测失败',
      );
    }
  }

  Future<DiagnosticItemState> _probeMetadataProvider(String provider) async {
    final displayName = provider == _javdbItemKey ? 'JavDB' : 'DMM';
    final kind =
        provider == _javdbItemKey
            ? DiagnosticItemKind.javdb
            : DiagnosticItemKind.dmm;
    final started = DateTime.now();
    try {
      final result = await _statusApi.testMetadataProvider(provider);
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      if (result.healthy) {
        return DiagnosticItemState.healthy(
          kind: kind,
          itemKey: provider,
          displayName: displayName,
          elapsedMs: elapsed,
          summary: '连通正常',
        );
      }
      final hintKey = resolveMetadataProviderHintKey(
        provider: provider,
        error: result.error,
      );
      return _fromHint(
        kind: kind,
        itemKey: provider,
        displayName: displayName,
        status: DiagnosticItemStatus.unhealthy,
        hint: javdbHints[hintKey] ?? javdbHints['unknown']!,
        elapsedMs: elapsed,
        summary:
            result.error?.message.isNotEmpty == true
                ? _shortenError(result.error!.message)
                : '接口返回不健康',
      );
    } catch (_) {
      return _fromHint(
        kind: kind,
        itemKey: provider,
        displayName: displayName,
        status: DiagnosticItemStatus.unhealthy,
        hint: javdbHints['proxy-required']!,
        summary: '请求异常',
      );
    }
  }

  Future<DiagnosticItemState> _probeLlm() async {
    final MovieDescTranslationSettingsDto settings;
    try {
      settings = await _llmApi.getSettings();
    } catch (_) {
      return _fromHint(
        kind: DiagnosticItemKind.llm,
        itemKey: _llmItemKey,
        displayName: 'LLM 翻译',
        status: DiagnosticItemStatus.unhealthy,
        hint: llmHints['unknown']!,
        summary: 'LLM 配置读取失败',
      );
    }

    if (!settings.enabled) {
      return _fromHint(
        kind: DiagnosticItemKind.llm,
        itemKey: _llmItemKey,
        displayName: 'LLM 翻译',
        status: DiagnosticItemStatus.warning,
        hint: llmHints['disabled']!,
        summary: '总开关未启用',
      );
    }
    if (settings.baseUrl.trim().isEmpty ||
        settings.apiKey.trim().isEmpty ||
        settings.model.trim().isEmpty) {
      return _fromHint(
        kind: DiagnosticItemKind.llm,
        itemKey: _llmItemKey,
        displayName: 'LLM 翻译',
        status: DiagnosticItemStatus.unhealthy,
        hint: llmHints['not-configured']!,
        summary: '关键字段为空',
      );
    }

    final payload = TestMovieDescTranslationSettingsPayload(
      enabled: settings.enabled,
      baseUrl: settings.baseUrl,
      apiKey: settings.apiKey,
      model: settings.model,
      timeoutSeconds: settings.timeoutSeconds,
      connectTimeoutSeconds: settings.connectTimeoutSeconds,
    );
    final started = DateTime.now();
    try {
      final ok = await _llmApi.testSettings(payload);
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      if (ok) {
        return DiagnosticItemState.healthy(
          kind: DiagnosticItemKind.llm,
          itemKey: _llmItemKey,
          displayName: 'LLM 翻译',
          elapsedMs: elapsed,
          summary: '模型 ${settings.model} 可用',
        );
      }
      return _fromHint(
        kind: DiagnosticItemKind.llm,
        itemKey: _llmItemKey,
        displayName: 'LLM 翻译',
        status: DiagnosticItemStatus.unhealthy,
        hint: llmHints['unknown']!,
        elapsedMs: elapsed,
        summary: '测试请求失败',
      );
    } catch (_) {
      return _fromHint(
        kind: DiagnosticItemKind.llm,
        itemKey: _llmItemKey,
        displayName: 'LLM 翻译',
        status: DiagnosticItemStatus.unhealthy,
        hint: llmHints['unknown']!,
        summary: '测试请求异常',
      );
    }
  }

  Future<DiagnosticItemState> _probeJoyTag() async {
    final started = DateTime.now();
    try {
      final status = await _statusApi.getImageSearchStatus();
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      if (status.joyTag.healthy) {
        final device = status.joyTag.usedDevice;
        return DiagnosticItemState.healthy(
          kind: DiagnosticItemKind.joyTag,
          itemKey: _joyTagItemKey,
          displayName: 'JoyTag 推理',
          elapsedMs: elapsed,
          summary: device == null || device.isEmpty ? '模型加载正常' : '推理设备：$device',
        );
      }
      return _fromHint(
        kind: DiagnosticItemKind.joyTag,
        itemKey: _joyTagItemKey,
        displayName: 'JoyTag 推理',
        status: DiagnosticItemStatus.unhealthy,
        hint: joyTagHints['unhealthy']!,
        elapsedMs: elapsed,
        summary: '模型未就绪',
      );
    } catch (_) {
      return _fromHint(
        kind: DiagnosticItemKind.joyTag,
        itemKey: _joyTagItemKey,
        displayName: 'JoyTag 推理',
        status: DiagnosticItemStatus.unhealthy,
        hint: joyTagHints['unhealthy']!,
        summary: '状态接口异常',
      );
    }
  }

  // --------- 内部辅助 ---------

  DiagnosticItemState _fromHint({
    required DiagnosticItemKind kind,
    required String itemKey,
    required String displayName,
    required DiagnosticItemStatus status,
    required DiagnosticHint hint,
    int? elapsedMs,
    String? summary,
  }) {
    return DiagnosticItemState(
      kind: kind,
      itemKey: itemKey,
      displayName: displayName,
      status: status,
      elapsedMs: elapsedMs,
      summary: summary,
      cause: hint.cause,
      fixHint: hint.fixHint,
      impact: hint.impact,
      fixTarget: hint.fixTarget,
    );
  }

  /// 在 [categoryLabel] 分类里，按 `(kind, itemKey)` 命中并替换单个 item，
  /// 其余 item 保持不变。
  void _replaceItem(String categoryLabel, DiagnosticItemState next) {
    final category = _categories.firstWhere(
      (cat) => cat.label == categoryLabel,
    );
    _replaceCategoryItems(categoryLabel, <DiagnosticItemState>[
      for (final item in category.items)
        if (item.kind == next.kind && item.itemKey == next.itemKey)
          next
        else
          item,
    ]);
  }

  /// 整体替换 [categoryLabel] 分类的 item 列表。
  void _replaceCategoryItems(
    String categoryLabel,
    List<DiagnosticItemState> items,
  ) {
    _categories = <DiagnosticCategoryState>[
      for (final cat in _categories)
        if (cat.label == categoryLabel)
          DiagnosticCategoryState(
            label: cat.label,
            icon: cat.icon,
            items: items,
          )
        else
          cat,
    ];
  }

  List<DiagnosticCategoryState> _buildInitialCategories({
    DiagnosticItemStatus status = DiagnosticItemStatus.notTested,
  }) {
    DiagnosticItemState make(DiagnosticItemKind kind, String key, String name) {
      if (status == DiagnosticItemStatus.probing) {
        return DiagnosticItemState.probing(
          kind: kind,
          itemKey: key,
          displayName: name,
        );
      }
      return DiagnosticItemState.notTested(
        kind: kind,
        itemKey: key,
        displayName: name,
      );
    }

    return <DiagnosticCategoryState>[
      DiagnosticCategoryState(
        label: '基础资源',
        icon: Icons.folder_special_outlined,
        items: <DiagnosticItemState>[
          make(DiagnosticItemKind.mediaLibrary, _mediaLibraryItemKey, '媒体库'),
        ],
      ),
      DiagnosticCategoryState(
        label: '下载与检索链',
        icon: Icons.download_outlined,
        items: <DiagnosticItemState>[
          make(
            DiagnosticItemKind.downloaderConnectivity,
            'downloader-placeholder',
            '下载器',
          ),
          make(DiagnosticItemKind.indexer, _indexerItemKey, '索引器'),
        ],
      ),
      DiagnosticCategoryState(
        label: '外部数据源',
        icon: Icons.public,
        items: <DiagnosticItemState>[
          make(DiagnosticItemKind.javdb, _javdbItemKey, 'JavDB'),
          make(DiagnosticItemKind.dmm, _dmmItemKey, 'DMM'),
        ],
      ),
      DiagnosticCategoryState(
        label: '智能能力',
        icon: Icons.psychology_outlined,
        items: <DiagnosticItemState>[
          make(DiagnosticItemKind.llm, _llmItemKey, 'LLM 翻译'),
          make(DiagnosticItemKind.joyTag, _joyTagItemKey, 'JoyTag 推理'),
        ],
      ),
    ];
  }

  String _mediaLibrarySummary(List<MediaLibraryDto> libraries) {
    if (libraries.length == 1) {
      return '1 个可用（${libraries.first.name}）';
    }
    return '${libraries.length} 个可用';
  }

  String _downloaderVersionSummary(DownloadClientTestResultDto result) {
    if (result.version != null && result.version!.isNotEmpty) {
      return '${result.version}';
    }
    return '连通正常';
  }

  String _indexerSummary(String hintKey, IndexerSettingsDto settings) {
    switch (hintKey) {
      case 'type-missing':
        return '未选择索引器类型';
      case 'api-key-missing':
        return 'API Key 未填';
      case 'entries-empty':
        return '尚未添加任何索引器条目';
      case 'entry-url-invalid':
        return '存在非法 tracker URL';
      case 'entry-client-missing':
        return '存在未绑定下载器的 entry';
      case 'entry-client-stale':
        return '存在绑定到已删除下载器的 entry';
      default:
        return '配置存在问题';
    }
  }

  String _indexerConnectionSummary(IndexerConnectionTestResultDto result) {
    if (result.resultCount == 0) {
      return '${result.indexersChecked} 个索引器已连接，测试查询未返回候选';
    }
    return '${result.indexersChecked} 个索引器已连接，返回 ${result.resultCount} 条候选';
  }

  String _indexerConnectionErrorSummary(IndexerConnectionTestResultDto result) {
    final message = result.error?.message ?? '';
    if (message.trim().isNotEmpty) {
      return _shortenError(message);
    }
    return result.error?.type == 'no_indexers_configured'
        ? '尚未保存任何索引器条目'
        : 'Jackett 连通性测试失败';
  }

  String _shortenError(String message) {
    final trimmed = message.trim();
    if (trimmed.length <= 40) return trimmed;
    return '${trimmed.substring(0, 40)}…';
  }
}
