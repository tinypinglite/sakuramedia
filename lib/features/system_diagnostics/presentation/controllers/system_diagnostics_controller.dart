import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/api/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/api/metadata_sources_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/metadata_source_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/metadata_sources_api_provider.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
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
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/metadata_source_hints.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

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
///   Stage B（独立探针，与 A 并行）：元数据源、嵌入服务。
///   Stage C（依赖 A）：索引器 —— 静态校验、绑定核对和真实搜索测试。
///
/// 单项 try/catch 隔离，任何一项抛异常不影响整体流水推进。
@riverpod
class SystemDiagnostics extends _$SystemDiagnostics {
  late final MediaLibrariesApi _mediaLibrariesApi;
  late final MetadataSourcesApi _metadataSourcesApi;
  late final PluginsApi _pluginsApi;
  late final DownloadClientsApi _downloadClientsApi;
  late final IndexerSettingsApi _indexerSettingsApi;
  late final StatusApi _statusApi;
  var _disposed = false;

  @override
  SystemDiagnosticsState build(SystemDiagnosticsHost host) {
    _mediaLibrariesApi = ref.read(mediaLibrariesApiProvider);
    _metadataSourcesApi = ref.read(metadataSourcesApiProvider);
    _pluginsApi = ref.read(pluginsApiProvider);
    _downloadClientsApi = ref.read(downloadClientsApiProvider);
    _indexerSettingsApi = ref.read(indexerSettingsApiProvider);
    _statusApi = ref.read(statusApiProvider);
    ref.onDispose(() => _disposed = true);
    _categories = _buildInitialCategories(
      l10n: ref.read(appLocalizationsProvider),
    );
    return _snapshot();
  }

  static const String _mediaLibraryItemKey = 'media-library';
  static const String _metadataSourcesItemKey = 'metadata-sources';
  static const String _indexerItemKey = 'indexer';
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
    final l10n = ref.read(appLocalizationsProvider);
    _isRunning = true;
    _categories = _buildInitialCategories(
      l10n: l10n,
      status: DiagnosticItemStatus.probing,
    );
    _publish();

    // Stage A + Stage B 完全并发（独立项互不依赖）。
    final mediaLibraryFuture = _probeMediaLibrary(l10n);
    final metadataSourcesFuture = _probeMetadataSources(l10n);
    final joyTagFuture = _probeJoyTag(l10n);

    final mediaLibrary = await mediaLibraryFuture;
    _replaceItem(l10n.diagnosticCategoryBasicResources, mediaLibrary);
    _publish();

    // Stage C：媒体库不通 → 索引器 blocked。
    if (mediaLibrary.status != DiagnosticItemStatus.healthy) {
      _replaceCategoryItems(
        l10n.diagnosticCategoryDownloadAndIndexing,
        <DiagnosticItemState>[
          DiagnosticItemState.blocked(
            kind: DiagnosticItemKind.indexer,
            itemKey: _indexerItemKey,
            displayName: l10n.diagnosticItemIndexer,
            blockedByLabel: l10n.diagnosticItemMediaLibrary,
            summary: l10n.diagnosticBlockedWaiting(
              l10n.diagnosticItemMediaLibrary,
            ),
          ),
        ],
      );
    } else {
      final indexerItem = await _probeIndexer(l10n);
      _replaceCategoryItems(
        l10n.diagnosticCategoryDownloadAndIndexing,
        <DiagnosticItemState>[indexerItem],
      );
    }
    _publish();

    // 收 stage B。
    await metadataSourcesFuture;
    final joyTag = await joyTagFuture;
    _replaceCategoryItems(
      l10n.diagnosticCategoryIntelligence,
      <DiagnosticItemState>[joyTag],
    );

    _isRunning = false;
    _lastRunAt = DateTime.now();
    _publish();
  }

  // --------- 单项探针 ---------

  Future<DiagnosticItemState> _probeMediaLibrary(AppLocalizations l10n) async {
    final started = DateTime.now();
    try {
      final libraries = await _mediaLibrariesApi.getLibraries();
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      if (libraries.isEmpty) {
        return _fromHint(
          kind: DiagnosticItemKind.mediaLibrary,
          itemKey: _mediaLibraryItemKey,
          displayName: l10n.diagnosticItemMediaLibrary,
          status: DiagnosticItemStatus.unhealthy,
          hint: mediaLibraryEmptyHint(l10n),
          elapsedMs: elapsed,
          summary: l10n.diagnosticMediaLibraryNoneConfigured,
        );
      }
      return DiagnosticItemState.healthy(
        kind: DiagnosticItemKind.mediaLibrary,
        itemKey: _mediaLibraryItemKey,
        displayName: l10n.diagnosticItemMediaLibrary,
        elapsedMs: elapsed,
        summary: _mediaLibrarySummary(libraries, l10n),
      );
    } catch (error) {
      // 请求本身失败 ≠ 没配媒体库，用另一份 hint，否则会误导用户去建媒体库。
      return _fromHint(
        kind: DiagnosticItemKind.mediaLibrary,
        itemKey: _mediaLibraryItemKey,
        displayName: l10n.diagnosticItemMediaLibrary,
        status: DiagnosticItemStatus.unhealthy,
        hint: mediaLibraryProbeFailedHint(l10n),
        summary: _shortenError(
          ref.apiErrorMessage(
            error,
            fallback: l10n.diagnosticErrorMediaLibraryLoadFailed,
          ),
        ),
      );
    }
  }

  /// 元数据源列表决定本次要跑哪些插件；列表本身失败和“没有启用插件”是
  /// 两种不同状态，不能混成同一个错误。
  Future<void> _probeMetadataSources(AppLocalizations l10n) async {
    final started = DateTime.now();
    final List<MetadataSourceDto> sources;
    try {
      sources = await _metadataSourcesApi.list();
    } catch (error) {
      _replaceCategoryItems(
        l10n.diagnosticCategoryMetadataSources,
        <DiagnosticItemState>[
          _fromHint(
            kind: DiagnosticItemKind.metadataSource,
            itemKey: _metadataSourcesItemKey,
            displayName: l10n.diagnosticItemMetadataSources,
            status: DiagnosticItemStatus.unhealthy,
            hint: metadataSourcesProbeFailedHint(l10n),
            elapsedMs: DateTime.now().difference(started).inMilliseconds,
            summary: _shortenError(
              ref.apiErrorMessage(
                error,
                fallback: l10n.diagnosticErrorMetadataSourcesLoadFailed,
              ),
            ),
          ),
        ],
      );
      _publish();
      return;
    }

    final usableSources = sources
        .where((source) => source.pluginId.trim().isNotEmpty)
        .toList(growable: false);
    if (usableSources.isEmpty) {
      _replaceCategoryItems(
        l10n.diagnosticCategoryMetadataSources,
        <DiagnosticItemState>[
          _fromHint(
            kind: DiagnosticItemKind.metadataSource,
            itemKey: _metadataSourcesItemKey,
            displayName: l10n.diagnosticItemMetadataSources,
            status: DiagnosticItemStatus.warning,
            hint: metadataSourcesEmptyHint(l10n),
            summary: l10n.diagnosticMetadataSourcesEmptySummary,
          ),
        ],
      );
      _publish();
      return;
    }

    _replaceCategoryItems(
      l10n.diagnosticCategoryMetadataSources,
      <DiagnosticItemState>[
        for (final source in usableSources)
          DiagnosticItemState.probing(
            kind: DiagnosticItemKind.metadataSource,
            itemKey: _metadataSourceItemKey(source),
            displayName: _metadataSourceName(source),
          ),
      ],
    );
    _publish();

    await Future.wait<void>(
      usableSources.map((source) async {
        final item = await _probeMetadataSource(source, l10n);
        _replaceItem(l10n.diagnosticCategoryMetadataSources, item);
        _publish();
      }),
    );
  }

  Future<DiagnosticItemState> _probeMetadataSource(
    MetadataSourceDto source,
    AppLocalizations l10n,
  ) async {
    final started = DateTime.now();
    final itemKey = _metadataSourceItemKey(source);
    final displayName = _metadataSourceName(source);
    try {
      final result = await _pluginsApi.testCapability(
        source.pluginId,
        PluginTestCapability.metadata,
      );
      final elapsedMs = result.durationMs > 0
          ? result.durationMs
          : DateTime.now().difference(started).inMilliseconds;
      switch (result.status) {
        case PluginTestStatus.ok:
          final metadata = result.metadata;
          if (metadata == null) {
            return _fromHint(
              kind: DiagnosticItemKind.metadataSource,
              itemKey: itemKey,
              displayName: displayName,
              status: DiagnosticItemStatus.unhealthy,
              hint: metadataSourceFailedHint(l10n),
              elapsedMs: elapsedMs,
              summary: l10n.diagnosticMetadataSourceFailedSummary,
            );
          }
          return DiagnosticItemState.healthy(
            kind: DiagnosticItemKind.metadataSource,
            itemKey: itemKey,
            displayName: displayName,
            elapsedMs: elapsedMs,
            summary: l10n.diagnosticMetadataSourceSummary(
              metadata.title.trim().isEmpty ? displayName : metadata.title,
              metadata.actorCount,
              metadata.tagCount,
              metadata.imageCount,
            ),
          );
        case PluginTestStatus.empty:
          return _fromHint(
            kind: DiagnosticItemKind.metadataSource,
            itemKey: itemKey,
            displayName: displayName,
            status: DiagnosticItemStatus.warning,
            hint: metadataSourceEmptyHint(l10n),
            elapsedMs: elapsedMs,
            summary: l10n.diagnosticMetadataSourceEmptySummary(
              result.movieNumber.trim().isEmpty
                  ? l10n.diagnosticItemMetadataSources
                  : result.movieNumber,
            ),
          );
        case PluginTestStatus.failed:
          final message = result.errorMessage?.trim() ?? '';
          return _fromHint(
            kind: DiagnosticItemKind.metadataSource,
            itemKey: itemKey,
            displayName: displayName,
            status: DiagnosticItemStatus.unhealthy,
            hint: metadataSourceFailedHint(l10n),
            elapsedMs: elapsedMs,
            summary: message.isEmpty
                ? l10n.diagnosticMetadataSourceFailedSummary
                : _shortenError(message),
          );
      }
    } catch (error) {
      return _fromHint(
        kind: DiagnosticItemKind.metadataSource,
        itemKey: itemKey,
        displayName: displayName,
        status: DiagnosticItemStatus.unhealthy,
        hint: metadataSourceRequestFailedHint(l10n),
        elapsedMs: DateTime.now().difference(started).inMilliseconds,
        summary: _shortenError(
          ref.apiErrorMessage(
            error,
            fallback: l10n.diagnosticCheckRequestFailed,
          ),
        ),
      );
    }
  }

  String _metadataSourceItemKey(MetadataSourceDto source) =>
      'metadata-source-${source.pluginId.trim()}';

  String _metadataSourceName(MetadataSourceDto source) {
    final displayName = source.displayName.trim();
    return displayName.isEmpty ? source.pluginId.trim() : displayName;
  }

  Future<DiagnosticItemState> _probeIndexer(AppLocalizations l10n) async {
    try {
      final settings = await _indexerSettingsApi.getSettings();
      final clients = await _downloadClientsApi.getClients();
      final hintKey = resolveIndexerConfigHintKey(
        settings: settings,
        existingClients: clients,
      );
      final hints = indexerHints(l10n);
      if (hintKey != null) {
        return _fromHint(
          kind: DiagnosticItemKind.indexer,
          itemKey: _indexerItemKey,
          displayName: l10n.diagnosticItemIndexer,
          status: DiagnosticItemStatus.unhealthy,
          hint: hints[hintKey] ?? hints['torznab-request-error']!,
          summary: _indexerSummary(hintKey, settings, l10n),
        );
      }

      final result = await _indexerSettingsApi.testConnection();
      if (result.healthy) {
        return DiagnosticItemState.healthy(
          kind: DiagnosticItemKind.indexer,
          itemKey: _indexerItemKey,
          displayName: l10n.diagnosticItemIndexer,
          elapsedMs: result.elapsedMs,
          summary: _indexerConnectionSummary(result, l10n),
        );
      }
      final connectionHintKey = resolveIndexerConnectionHintKey(
        result.error?.type,
      );
      return _fromHint(
        kind: DiagnosticItemKind.indexer,
        itemKey: _indexerItemKey,
        displayName: l10n.diagnosticItemIndexer,
        status: DiagnosticItemStatus.unhealthy,
        hint: hints[connectionHintKey]!,
        elapsedMs: result.elapsedMs,
        summary: _indexerConnectionErrorSummary(result, l10n),
      );
    } catch (_) {
      return _fromHint(
        kind: DiagnosticItemKind.indexer,
        itemKey: _indexerItemKey,
        displayName: l10n.diagnosticItemIndexer,
        status: DiagnosticItemStatus.unhealthy,
        hint: indexerHints(l10n)['torznab-request-error']!,
        summary: l10n.diagnosticIndexerConfigOrConnectionFailed,
      );
    }
  }

  Future<DiagnosticItemState> _probeJoyTag(AppLocalizations l10n) async {
    final started = DateTime.now();
    final StatusImageSearchDto status;
    try {
      status = await _statusApi.getImageSearchStatus();
    } catch (error) {
      return _fromHint(
        kind: DiagnosticItemKind.joyTag,
        itemKey: _joyTagItemKey,
        displayName: l10n.diagnosticItemEmbeddingService,
        status: DiagnosticItemStatus.unhealthy,
        hint: joyTagHints(l10n)['status-unavailable']!,
        summary: _shortenError(
          ref.apiErrorMessage(
            error,
            fallback: l10n.diagnosticCheckRequestFailed,
          ),
        ),
      );
    }
    if (!status.enabled)
      return DiagnosticItemState.disabled(
        kind: DiagnosticItemKind.joyTag,
        itemKey: _joyTagItemKey,
        displayName: l10n.diagnosticItemEmbeddingService,
        summary: l10n.diagnosticEmbeddingDisabledSummary,
      );
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    if (status.embeddingService.healthy) {
      final spaceId = status.embeddingService.spaceId;
      final dimension = status.embeddingService.dimension;
      return DiagnosticItemState.healthy(
        kind: DiagnosticItemKind.joyTag,
        itemKey: _joyTagItemKey,
        displayName: l10n.diagnosticItemEmbeddingService,
        elapsedMs: elapsed,
        summary: spaceId == null || spaceId.isEmpty
            ? l10n.diagnosticEmbeddingHealthySummary
            : dimension == null
            ? l10n.diagnosticEmbeddingSpace(spaceId)
            : l10n.diagnosticEmbeddingSpaceWithDimension(spaceId, dimension),
      );
    }
    return _fromHint(
      kind: DiagnosticItemKind.joyTag,
      itemKey: _joyTagItemKey,
      displayName: l10n.diagnosticItemEmbeddingService,
      status: DiagnosticItemStatus.unhealthy,
      hint: joyTagHints(l10n)['unhealthy']!,
      elapsedMs: elapsed,
      // 后端带了失败原因，直接透出去比"模型未就绪"有用。
      summary: _shortenError(
        status.embeddingService.error ?? l10n.diagnosticEmbeddingModelNotReady,
      ),
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
    required AppLocalizations l10n,
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
        label: l10n.diagnosticCategoryBasicResources,
        icon: Icons.folder_special_outlined,
        items: <DiagnosticItemState>[
          make(
            DiagnosticItemKind.mediaLibrary,
            _mediaLibraryItemKey,
            l10n.diagnosticItemMediaLibrary,
          ),
        ],
      ),
      DiagnosticCategoryState(
        label: l10n.diagnosticCategoryMetadataSources,
        icon: Icons.travel_explore_rounded,
        items: <DiagnosticItemState>[
          make(
            DiagnosticItemKind.metadataSource,
            _metadataSourcesItemKey,
            l10n.diagnosticItemMetadataSources,
          ),
        ],
      ),
      DiagnosticCategoryState(
        label: l10n.diagnosticCategoryDownloadAndIndexing,
        icon: Icons.download_outlined,
        items: <DiagnosticItemState>[
          make(
            DiagnosticItemKind.indexer,
            _indexerItemKey,
            l10n.diagnosticItemIndexer,
          ),
        ],
      ),
      DiagnosticCategoryState(
        label: l10n.diagnosticCategoryIntelligence,
        icon: Icons.psychology_outlined,
        items: <DiagnosticItemState>[
          make(
            DiagnosticItemKind.joyTag,
            _joyTagItemKey,
            l10n.diagnosticItemEmbeddingService,
          ),
        ],
      ),
    ];
  }

  String _mediaLibrarySummary(
    List<MediaLibraryDto> libraries,
    AppLocalizations l10n,
  ) {
    if (libraries.length == 1) {
      return l10n.diagnosticMediaLibraryOneAvailable(libraries.first.name);
    }
    return l10n.diagnosticMediaLibraryAvailable(libraries.length.toString());
  }

  String _indexerSummary(
    String hintKey,
    IndexerSettingsDto settings,
    AppLocalizations l10n,
  ) {
    switch (hintKey) {
      case 'entries-empty':
        return l10n.diagnosticIndexerNoneConfigured;
      case 'entry-url-invalid':
        return l10n.diagnosticIndexerInvalidUrl;
      case 'entry-client-missing':
        return l10n.diagnosticIndexerClientMissing;
      case 'entry-client-stale':
        return l10n.diagnosticIndexerClientStale;
      default:
        return l10n.diagnosticIndexerConfigIssue;
    }
  }

  String _indexerConnectionSummary(
    IndexerConnectionTestResultDto result,
    AppLocalizations l10n,
  ) {
    if (result.resultCount == 0) {
      return l10n.diagnosticIndexerConnectedNoResults(
        result.indexersChecked.toString(),
      );
    }
    return l10n.diagnosticIndexerConnectedWithResults(
      result.indexersChecked.toString(),
      result.resultCount.toString(),
    );
  }

  String _indexerConnectionErrorSummary(
    IndexerConnectionTestResultDto result,
    AppLocalizations l10n,
  ) {
    final message = result.error?.message ?? '';
    if (message.trim().isNotEmpty) {
      return _shortenError(message);
    }
    return result.error?.type == 'no_indexers_configured'
        ? l10n.diagnosticIndexerNoneSaved
        : l10n.diagnosticTorznabTestFailed;
  }

  String _shortenError(String message) {
    final trimmed = message.trim();
    if (trimmed.length <= 40) return trimmed;
    return '${trimmed.substring(0, 40)}…';
  }
}
