import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';

/// 下载器诊断的 hint 表。
///
/// 后端 `DownloadClientService` 发出的 error type 是**封闭集合**（见
/// [DownloaderErrorType]），所以分派一律走精确匹配，不做 `type.contains(...)`
/// 的模糊猜测——那样写出来的分支后端永远不会命中。
///
/// 唯一的例外是 qBittorrent：后端把「认证失败」和「连不上」都塞进同一个
/// `qbittorrent_request_error`，只能靠 message（`str(qbittorrent-api 异常)`）
/// 做**尽力而为**的二次细分，命中不了就落回通用文案。这一层是有意的启发式，
/// 不是协议约定，见 [_refineQbittorrentHintKey]。

/// 「媒体库」「下载器」在配置页分类列表里的索引（`desktop_configuration_page.dart`）。
const DiagnosticFixTarget _mediaLibraryTarget =
    DiagnosticFixTarget.configurationTab(1);
const DiagnosticFixTarget _downloaderTarget =
    DiagnosticFixTarget.configurationTab(2);

/// 后端下载器诊断 `error.type` 的全部取值。
abstract final class DownloaderErrorType {
  /// qB 连通性：`QBittorrentClientError` 的统一出口（登录失败与网络失败都在这）。
  static const String qbittorrentRequestError = 'qbittorrent_request_error';

  /// cloud115：所挂媒体库的 cookies 已失效。
  static const String cloud115CookiesInvalid = 'cloud115_cookies_invalid';

  /// cloud115：上游暂时不可用 / 探活本身失败。
  static const String cloud115UpstreamError = 'cloud115_upstream_error';

  /// 存储探测：`local_root_path` 不存在或不是目录。
  static const String localRootNotAccessible = 'local_root_path_not_accessible';

  /// 存储探测：qB 在 `client_save_path` 下看不到后端写的哨兵文件。
  static const String sentinelNotVisible = 'sentinel_not_visible_to_qb';

  /// 存储探测：本地文件系统操作报错（OSError）。
  static const String filesystemError = 'filesystem_error';

  /// 存储探测：硬链接建立失败。
  static const String hardlinkNotSupported = 'hardlink_not_supported';
}

const DiagnosticHint _probeRequestFailedHint = DiagnosticHint(
  cause: '检测请求没完成，后端没有响应。',
  fixHint: '确认后端正常后重新检测。',
);

const Map<String, DiagnosticHint> downloaderConnectivityHints =
    <String, DiagnosticHint>{
      'qbittorrent-auth-error': DiagnosticHint(
        cause: 'qBittorrent 不认这个账号密码。',
        fixHint: '在「下载器」页重新填一次账号密码。',
        fixTarget: _downloaderTarget,
      ),
      'qbittorrent-network-error': DiagnosticHint(
        cause: '连不上 qBittorrent。',
        fixHint: '检查「下载器」页的地址和端口。',
        fixTarget: _downloaderTarget,
      ),
      DownloaderErrorType.qbittorrentRequestError: DiagnosticHint(
        cause: 'qBittorrent 没有正常响应。',
        fixHint: '点「查看诊断详情」看具体报错。',
        fixTarget: _downloaderTarget,
      ),
      DownloaderErrorType.cloud115CookiesInvalid: DiagnosticHint(
        cause: '115 的登录已经失效。',
        fixHint: '在「媒体库」页给对应的 115 媒体库重新扫码登录。',
        fixTarget: _mediaLibraryTarget,
      ),
      DownloaderErrorType.cloud115UpstreamError: DiagnosticHint(
        cause: '115 没有正常响应。',
        fixHint: '稍后重试，或者重新扫码登录 115。',
        fixTarget: _mediaLibraryTarget,
      ),
      'unknown': DiagnosticHint(
        cause: '下载器返回了无法识别的错误。',
        fixHint: '点「查看诊断详情」看具体报错。',
        fixTarget: _downloaderTarget,
      ),
      'probe-request-failed': _probeRequestFailedHint,
    };

const Map<String, DiagnosticHint> downloaderStorageHints =
    <String, DiagnosticHint>{
      DownloaderErrorType.localRootNotAccessible: DiagnosticHint(
        cause: '后端找不到「本地访问路径」这个目录。',
        fixHint: '检查「下载器」页的「本地访问路径」，确认这个目录挂给了后端。',
        fixTarget: _downloaderTarget,
      ),
      DownloaderErrorType.sentinelNotVisible: DiagnosticHint(
        cause: 'qBittorrent 下载到的目录，后端找不到。',
        fixHint: '检查「下载器」页那两个路径，要指向同一个文件夹。',
        fixTarget: _downloaderTarget,
      ),
      DownloaderErrorType.qbittorrentRequestError: DiagnosticHint(
        cause: '检查目录的时候 qBittorrent 没有响应。',
        fixHint: '先让上面的「连通性」通过。qBittorrent 版本太旧也可能不支持，建议升到 5.x。',
        fixTarget: _downloaderTarget,
      ),
      DownloaderErrorType.filesystemError: DiagnosticHint(
        cause: '后端在「本地访问路径」里写不了文件。',
        fixHint: '检查这个目录的读写权限，确认不是只读挂载。',
        fixTarget: _downloaderTarget,
      ),
      DownloaderErrorType.hardlinkNotSupported: DiagnosticHint(
        cause: '下载目录和媒体库不在同一块盘上。',
        fixHint: '把它们放到同一块盘上。详见 wiki「快速开始 · 媒体目录怎么挂才能正确硬链接」。',
        fixTarget: _downloaderTarget,
      ),
      'unknown': DiagnosticHint(
        cause: '检查目录时返回了无法识别的错误。',
        fixHint: '点「查看诊断详情」看具体报错。',
        fixTarget: _downloaderTarget,
      ),
      'probe-request-failed': _probeRequestFailedHint,
    };

/// 连通性 hint key：先按后端 `error.type` 精确分派，qB 那一类再做尽力细分。
String resolveDownloaderConnectivityHintKey(
  DownloadClientDiagnosticErrorDto? error,
) {
  if (error == null) return 'unknown';
  return switch (error.type) {
    DownloaderErrorType.cloud115CookiesInvalid =>
      DownloaderErrorType.cloud115CookiesInvalid,
    DownloaderErrorType.cloud115UpstreamError =>
      DownloaderErrorType.cloud115UpstreamError,
    DownloaderErrorType.qbittorrentRequestError => _refineQbittorrentHintKey(
      error.message,
    ),
    _ => 'unknown',
  };
}

/// qB 只有一个 error type，只能从 `str(qbittorrent-api 异常)` 里尽力猜是认证还是网络。
///
/// **这是启发式，不是协议**：措辞取决于第三方库版本，猜不中就返回通用的
/// `qbittorrent_request_error`，它的文案会引导用户自己去看报文原文。
String _refineQbittorrentHintKey(String message) {
  final normalized = message.toLowerCase();
  const authMarkers = <String>[
    'login',
    'unauthorized',
    'forbidden',
    '401',
    '403',
  ];
  const networkMarkers = <String>[
    'connection',
    'connect',
    'timed out',
    'timeout',
    'no route',
    'unreachable',
    'name or service not known',
    'max retries exceeded',
  ];
  if (authMarkers.any(normalized.contains)) {
    return 'qbittorrent-auth-error';
  }
  if (networkMarkers.any(normalized.contains)) {
    return 'qbittorrent-network-error';
  }
  return DownloaderErrorType.qbittorrentRequestError;
}

/// 存储 hint key。
///
/// 优先级：目录映射失败 > 硬链接不支持 > unknown。后端在 mapping 失败时会把
/// hardlink 标成 `skipped`，所以必须先判 mapping，否则会拿一个没跑过的硬链接结果下结论。
String resolveDownloaderStorageHintKey(
  DownloadClientStorageTestResultDto result,
) {
  final mapping = result.directoryMapping;
  final mappingHealthy =
      mapping.status.toLowerCase() == 'ok' &&
      mapping.error == null &&
      mapping.sentinelVisibleToQb;
  if (!mappingHealthy) {
    final type = mapping.error?.type ?? '';
    return downloaderStorageHints.containsKey(type) ? type : 'unknown';
  }
  if (!result.hardlink.supported) {
    return DownloaderErrorType.hardlinkNotSupported;
  }
  return 'unknown';
}
