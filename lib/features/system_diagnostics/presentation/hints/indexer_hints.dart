import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';

/// 索引器（Jackett）先校验静态配置，再进行真实搜索连通性检测。
const Map<String, DiagnosticHint> indexerHints = <String, DiagnosticHint>{
  'type-missing': DiagnosticHint(
    cause: '还没有选择索引器类型（Jackett/Prowlarr 等）。',
    fixHint: '打开「索引器」页，选择当前部署的索引器类型并填 API Key。',
    impact: '影片详情投递下载、以及索引器搜索通道都不可用。',
    fixTarget: DiagnosticFixTarget.configurationTab(3),
  ),
  'api-key-missing': DiagnosticHint(
    cause: '索引器 API Key 还是空的。',
    fixHint: '登录 Jackett 面板顶部会显示 API Key，复制回来填进「索引器」页；如果换 Jackett 实例了也要重新配。',
    impact: '所有 Jackett 相关搜索会立刻 401 失败。',
    fixTarget: DiagnosticFixTarget.configurationTab(3),
  ),
  'entries-empty': DiagnosticHint(
    cause: '没有配置任何索引器条目，Jackett 有 API Key 但没接任何 tracker。',
    fixHint: '在「索引器」页添加至少一个 tracker（PT 站或公开索引器），并绑定一个下载器。',
    impact: '影片详情里点搜索会一直返回空结果，不管本地还是联网。',
    fixTarget: DiagnosticFixTarget.configurationTab(3),
  ),
  'entry-url-invalid': DiagnosticHint(
    cause: '有索引器条目的 URL 是空的或不是合法 HTTP(S) 地址。',
    fixHint: '在「索引器」页检查每一条 entry 的 URL，重新复制 Jackett 的 tracker 链接。',
    impact: '带非法 URL 的 tracker 会在搜索时抛异常，可能顺带拖垮同一批的其它搜索。',
    fixTarget: DiagnosticFixTarget.configurationTab(3),
  ),
  'entry-client-missing': DiagnosticHint(
    cause: '有索引器条目没绑定下载器（downloadClientId 为空 / 为 0）。',
    fixHint: '打开「索引器」页，对没有绑定下载器的 entry 选择一个下载器。',
    impact: '这些 entry 搜到的磁力无法派发到 qBittorrent，用户点下载会 400。',
    fixTarget: DiagnosticFixTarget.configurationTab(3),
  ),
  'entry-client-stale': DiagnosticHint(
    cause: '有索引器条目绑定的下载器已被删除，还留着悬空的 downloadClientId。',
    fixHint: '打开「索引器」页，把这些 entry 重新绑定到一个存在的下载器。',
    impact: '这些 entry 搜到的磁力无法派发，用户点下载会因下载器不存在直接失败。',
    fixTarget: DiagnosticFixTarget.configurationTab(3),
  ),
  'no-indexers-configured': DiagnosticHint(
    cause: '服务器上尚未保存任何索引器条目，无法向 Jackett 发起真实搜索。',
    fixHint: '在「索引器」页添加至少一个 tracker 并保存配置后，再重新测试。',
    impact: '影片详情中的索引器搜索没有可用来源，无法返回下载候选。',
    fixTarget: DiagnosticFixTarget.configurationTab(3),
  ),
  'jackett-request-error': DiagnosticHint(
    cause: 'Jackett 未能完成本次真实 Torznab 搜索，可能是服务不可达、API Key 无效或索引器地址异常。',
    fixHint:
        '检查 Jackett 服务地址与网络连通性，确认 API Key 有效，并核对每个 tracker 的 Torznab 地址后重新测试。',
    impact: '影片详情的索引器搜索会失败，无法获取可投递到下载器的候选资源。',
    fixTarget: DiagnosticFixTarget.configurationTab(3),
  ),
};

/// 索引器静态校验结果。`null` 表示可继续执行在线连通性检测。
///
/// 规则按顺序判定，命中第一条就返回。
String? resolveIndexerConfigHintKey({
  required IndexerSettingsDto settings,
  required List<DownloadClientDto> existingClients,
}) {
  if (settings.type.trim().isEmpty) return 'type-missing';
  if (settings.apiKey.trim().isEmpty) return 'api-key-missing';
  if (settings.indexers.isEmpty) return 'entries-empty';
  final existingIds = existingClients.map((c) => c.id).toSet();
  for (final entry in settings.indexers) {
    if (entry.url.trim().isEmpty || !_isHttpUrl(entry.url)) {
      return 'entry-url-invalid';
    }
    if (entry.downloadClientId <= 0) {
      return 'entry-client-missing';
    }
    if (!existingIds.contains(entry.downloadClientId)) {
      return 'entry-client-stale';
    }
  }
  return null;
}

String resolveIndexerConnectionHintKey(String? errorType) {
  switch (errorType?.trim()) {
    case 'no_indexers_configured':
      return 'no-indexers-configured';
    case 'jackett_request_error':
    default:
      return 'jackett-request-error';
  }
}

bool _isHttpUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
}
