import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 索引器（Torznab）先校验静态配置，再进行真实搜索连通性检测。
///
/// 「索引器」在配置页分类列表里的稳定 itemKey（见 `configuration_page.dart`）。
const DiagnosticFixTarget _indexerTarget =
    DiagnosticFixTarget.configurationTabKey('configuration-tab-indexers');

/// `entries-empty`（前端读配置发现没条目）与 `no_indexers_configured`（后端发起
/// 搜索时发现没条目）在用户眼里是同一件事，共用一条文案。
DiagnosticHint _noIndexersHint(AppLocalizations l10n) => DiagnosticHint(
  cause: l10n.diagnosticHintIndexerEmptyCause,
  fixHint: l10n.diagnosticHintIndexerEmptyFix,
  fixTarget: _indexerTarget,
);

Map<String, DiagnosticHint> indexerHints(AppLocalizations l10n) =>
    <String, DiagnosticHint>{
      'entries-empty': _noIndexersHint(l10n),
      'entry-url-invalid': DiagnosticHint(
        cause: l10n.diagnosticHintIndexerInvalidUrlCause,
        fixHint: l10n.diagnosticHintIndexerInvalidUrlFix,
        fixTarget: _indexerTarget,
      ),
      'entry-client-missing': DiagnosticHint(
        cause: l10n.diagnosticHintIndexerClientMissingCause,
        fixHint: l10n.diagnosticHintIndexerClientMissingFix,
        fixTarget: _indexerTarget,
      ),
      'entry-client-stale': DiagnosticHint(
        cause: l10n.diagnosticHintIndexerClientStaleCause,
        fixHint: l10n.diagnosticHintIndexerClientStaleFix,
        fixTarget: _indexerTarget,
      ),
      'no-indexers-configured': _noIndexersHint(l10n),
      'torznab-request-error': DiagnosticHint(
        cause: l10n.diagnosticHintIndexerTestFailedCause,
        fixHint: l10n.diagnosticHintIndexerTestFailedFix,
        fixTarget: _indexerTarget,
      ),
    };

/// 索引器静态校验结果。`null` 表示可继续执行在线连通性检测。
///
/// 规则按顺序判定，命中第一条就返回。
String? resolveIndexerConfigHintKey({
  required IndexerSettingsDto settings,
  required List<DownloadClientDto> existingClients,
}) {
  if (settings.indexers.isEmpty) return 'entries-empty';
  final existingIds = existingClients.map((c) => c.id).toSet();
  for (final entry in settings.indexers) {
    if (entry.url.trim().isEmpty || !_isHttpUrl(entry.url)) {
      return 'entry-url-invalid';
    }
    if (entry.downloadClients.isEmpty) {
      return 'entry-client-missing';
    }
    if (!entry.downloadClientIds.every(existingIds.contains)) {
      return 'entry-client-stale';
    }
  }
  return null;
}

String resolveIndexerConnectionHintKey(String? errorType) {
  switch (errorType?.trim()) {
    case 'no_indexers_configured':
      return 'no-indexers-configured';
    case 'torznab_request_error':
    default:
      return 'torznab-request-error';
  }
}

bool _isHttpUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
}
