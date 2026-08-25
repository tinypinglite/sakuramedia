import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/api/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_api_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_category_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_kind.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/indexer_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/joytag_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/media_library_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/metadata_provider_hints.dart';

part 'system_diagnostics_controller.g.dart';

/// 两个宿主各自保留一次诊断会话，避免概览条与独立页互相覆盖运行状态。
enum SystemDiagnosticsHost { overviewStrip, desktopPage }

@immutable
class SystemDiagnosticsState {
  const SystemDiagnosticsState({
    required this.categories,
    required this.isRunning,
    required this.lastRunAt,
  });

  final List<DiagnosticCategoryState> categories;
  final bool isRunning;
  final DateTime? lastRunAt;

  DiagnosticItemStatus get overallStatus =>
      mergeDiagnosticStatuses(categories.map((cat) => cat.aggregate));
  int get unhealthyCount => categories
      .expand((cat) => cat.items)
      .where((item) => item.status == DiagnosticItemStatus.unhealthy)
      .length;
  int get totalItemCount =>
      categories.fold(0, (sum, cat) => sum + cat.items.length);
  int get completedItemCount => categories
      .expand((cat) => cat.items)
      .where(
        (item) =>
            item.status != DiagnosticItemStatus.notTested &&
            item.status != DiagnosticItemStatus.probing,
      )
      .length;
}

/// 一次「组件诊断」检测的调度器。
///
/// 调度算法（[runAll]）：
///   Stage A（基础资源）：媒体库。空 → 后置全部 blocked。
///   Stage B（独立探针，与 A 并行）：JavDB / JoyTag。
///   Stage C（依赖 A）：索引器 —— 静态校验、绑定核对和真实搜索测试。
///
/// 单项 try/catch 隔离，任何一项抛异常不影响整体流水推进。
@riverpod
class SystemDiagnostics extends _$SystemDiagnostics {
  late final MediaLibrariesApi _mediaLibrariesApi;
  late final DownloadClientsApi _downloadClientsApi;
  late final IndexerSettingsApi _indexerSettingsApi;
  late final StatusApi _statusApi;
  var _disposed = false;

  @override
  SystemDiagnosticsState build(SystemDiagnosticsHost host) {
    _mediaLibrariesApi = ref.read(mediaLibrariesApiProvider);
    _downloadClientsApi = ref.read(downloadClientsApiProvider);
    _indexerSettingsApi = ref.read(indexerSettingsApiProvider);
    _statusApi = ref.read(statusApiProvider);
    ref.onDispose(() => _disposed = true);
    _categories = _buildInitialCategories();
    return _snapshot();
  }

  static const String _mediaLibraryItemKey = 'media-library';
  static const String _indexerItemKey = 'indexer';
  static const String _javdbItemKey = 'javdb';
  static const String _joyTagItemKey = 'joytag';

  bool _isRunning = false;
  DateTime? _lastRunAt;
  late List<DiagnosticCategoryState> _categories;

  void _publish() {
    if (!_disposed) state = _snapshot();
  }

  SystemDiagnosticsState _snapshot() => SystemDiagnosticsState(
    categories: List<DiagnosticCategoryState>.unmodifiable(_categories),
    isRunning: _isRunning,
    lastRunAt: _lastRunAt,
  );

  /// 幂等：正在跑就直接 return。
  Future<void> runAll() async {
    if (_isRunning) return;
    _isRunning = true;
    _categories = _buildInitialCategories(status: DiagnosticItemStatus.probing);
    _publish();

    // Stage A + Stage B 完全并发（独立项互不依赖）。
    final mediaLibraryFuture = _probeMediaLibrary();
    final javdbFuture = _probeMetadataProvider(_javdbItemKey);
    final joyTagFuture = _probeJoyTag();

    final mediaLibrary = await mediaLibraryFuture;
    _replaceItem('基础资源', mediaLibrary);
    _publish();

    // Stage C：媒体库不通 → 索引器 blocked。
    if (mediaLibrary.status != DiagnosticItemStatus.healthy) {
      _replaceCategoryItems('下载与检索链', <DiagnosticItemState>[
        DiagnosticItemState.blocked(
          kind: DiagnosticItemKind.indexer,
          itemKey: _indexerItemKey,
          displayName: '索引器',
          blockedByLabel: '媒体库',
        ),
      ]);
    } else {
      final indexerItem = await _probeIndexer();
      _replaceCategoryItems('下载与检索链', <DiagnosticItemState>[indexerItem]);
    }
    _publish();

    // 收 stage B。
    final javdb = await javdbFuture;
    _replaceCategoryItems('外部数据源', <DiagnosticItemState>[javdb]);

    final joyTag = await joyTagFuture;
    _replaceCategoryItems('智能能力', <DiagnosticItemState>[joyTag]);

    _isRunning = false;
    _lastRunAt = DateTime.now();
    _publish();
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
    } catch (error) {
      // 请求本身失败 ≠ 没配媒体库，用另一份 hint，否则会误导用户去建媒体库。
      return _fromHint(
        kind: DiagnosticItemKind.mediaLibrary,
        itemKey: _mediaLibraryItemKey,
        displayName: '媒体库',
        status: DiagnosticItemStatus.unhealthy,
        hint: mediaLibraryProbeFailedHint,
        summary: _shortenError(apiErrorMessage(error, fallback: '读取媒体库列表失败')),
      );
    }
  }

  Future<DiagnosticItemState> _probeIndexer() async {
    try {
      final settings = await _indexerSettingsApi.getSettings();
      final clients = await _downloadClientsApi.getClients();
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
          hint: indexerHints[hintKey] ?? indexerHints['torznab-request-error']!,
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
        hint: indexerHints['torznab-request-error']!,
        summary: '索引器配置或连通性检测失败',
      );
    }
  }

  /// 后端 `/status/metadata-providers/{provider}/test` 目前只支持 JavDB。
  Future<DiagnosticItemState> _probeMetadataProvider(String provider) async {
    const displayName = 'JavDB';
    const kind = DiagnosticItemKind.javdb;
    final hints = javdbHints;
    try {
      final result = await _statusApi.testMetadataProvider(provider);
      // 后端已经量过耗时（含内部重试），比前端在 await 两端掐表准。
      if (result.healthy) {
        return DiagnosticItemState.healthy(
          kind: kind,
          itemKey: provider,
          displayName: displayName,
          elapsedMs: result.elapsedMs,
          summary: _metadataProviderHealthySummary(result),
        );
      }
      final hintKey = resolveMetadataProviderHintKey(result.error);
      return _fromHint(
        kind: kind,
        itemKey: provider,
        displayName: displayName,
        status: DiagnosticItemStatus.unhealthy,
        hint: hints[hintKey]!,
        elapsedMs: result.elapsedMs,
        summary: _metadataProviderErrorSummary(result),
      );
    } catch (error) {
      // 后端探测端点本身挂了：这不是 JavDB 站点的问题，不能套站点文案。
      return _fromHint(
        kind: kind,
        itemKey: provider,
        displayName: displayName,
        status: DiagnosticItemStatus.unhealthy,
        hint: hints['probe-request-failed']!,
        summary: _shortenError(
          apiErrorMessage(error, fallback: '$displayName 探测请求失败'),
        ),
      );
    }
  }

  Future<DiagnosticItemState> _probeJoyTag() async {
    final started = DateTime.now();
    final StatusImageSearchDto status;
    try {
      status = await _statusApi.getImageSearchStatus();
    } catch (error) {
      return _fromHint(
        kind: DiagnosticItemKind.joyTag,
        itemKey: _joyTagItemKey,
        displayName: 'JoyTag 推理',
        status: DiagnosticItemStatus.unhealthy,
        hint: joyTagHints['status-unavailable']!,
        summary: _shortenError(apiErrorMessage(error, fallback: '检测请求失败')),
      );
    }
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
      // 后端带了失败原因，直接透出去比"模型未就绪"有用。
      summary: _shortenError(status.joyTag.error ?? '模型未就绪'),
    );
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
          make(DiagnosticItemKind.indexer, _indexerItemKey, '索引器'),
        ],
      ),
      DiagnosticCategoryState(
        label: '外部数据源',
        icon: Icons.public,
        items: <DiagnosticItemState>[
          make(DiagnosticItemKind.javdb, _javdbItemKey, 'JavDB'),
        ],
      ),
      DiagnosticCategoryState(
        label: '智能能力',
        icon: Icons.psychology_outlined,
        items: <DiagnosticItemState>[
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

  String _indexerSummary(String hintKey, IndexerSettingsDto settings) {
    switch (hintKey) {
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
        : 'Torznab 连通性测试失败';
  }

  String _shortenError(String message) {
    final trimmed = message.trim();
    if (trimmed.length <= 40) return trimmed;
    return '${trimmed.substring(0, 40)}…';
  }

  /// 状态短句优先用后端 message，退回 type，再退回 [fallback]。
  ///
  /// type 是内部标识，对用户几乎没信息量，只在没有 message 时才拿它顶着。
  String _errorSummary(
    String? message,
    String? type, {
    required String fallback,
  }) {
    if (message != null && message.trim().isNotEmpty) {
      return _shortenError(message);
    }
    if (type != null && type.trim().isNotEmpty) return type.trim();
    return fallback;
  }

  /// healthy 时把后端返回的实证数据摆出来，让"绿"是可验证的而不是一句"连通正常"。
  String _metadataProviderHealthySummary(StatusMetadataProviderTestDto result) {
    final number = result.movieNumber;
    return number.isEmpty ? '连通正常' : '$number 抓取成功';
  }

  String _metadataProviderErrorSummary(StatusMetadataProviderTestDto result) {
    final error = result.error;
    if (error == null) return '接口返回不健康';
    // not_found 的 message 里已经含番号，直接用；其余带上探测番号做定位。
    return _errorSummary(
      error.message,
      error.type,
      fallback: result.movieNumber.isEmpty
          ? '探测失败'
          : '${result.movieNumber} 探测失败',
    );
  }
}
