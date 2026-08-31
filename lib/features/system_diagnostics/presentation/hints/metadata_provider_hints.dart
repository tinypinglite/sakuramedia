import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';

/// JavDB 元数据源诊断 hint。
///
/// - 外部站点请求统一跟随容器环境变量 `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` 分流
///   （httpx `trust_env` 默认开启），由部署方自行决定哪些域名走代理、哪些直连。
/// - JavDB 站点访问依托「高级设置 · JavDB 域名」自身的直连/反代能力。
///
/// key 与后端 [MetadataProviderErrorType] 的三个取值一一对应，外加一个前端侧的
/// `probe-request-failed`（调 `/status/metadata-providers/{p}/test` 本身就失败了）。

const DiagnosticHint _probeRequestFailedHint = DiagnosticHint(
  cause: '检测请求没完成，后端没有响应。',
  fixHint: '确认后端正常后重新检测。',
);

/// JavDB 侧**一律不给 fixTarget**：能改的只有「高级设置 · JavDB API 域名」，而 wiki
/// `config.md` 明确写着这个字段不建议随便改。真正的修法在路由器/透明代理那一侧
/// （见 wiki「常见问题 · 代理配置」），SakuraMedia 里没有对应开关，指过去等于误导。
const Map<String, DiagnosticHint> javdbHints = <String, DiagnosticHint>{
  MetadataProviderErrorType.notFound: DiagnosticHint(
    cause: 'JavDB 打得开，但搜不到测试用的番号。',
    fixHint: '先重新检测一次。还是失败就是 JavDB 改版了，需要等适配。',
  ),
  MetadataProviderErrorType.requestError: DiagnosticHint(
    cause: '连不上 JavDB。',
    fixHint:
        '代理改由部署侧环境变量分流：若配置了 HTTP_PROXY，需在 NO_PROXY 排除 '
        'JavDB 相关域名，或让透明代理规则放行直连，详见 wiki「常见问题 · 代理配置」。',
  ),
  MetadataProviderErrorType.unexpected: DiagnosticHint(
    cause: 'JavDB 抓取时出错了。',
    fixHint: '确认后端日志后重新检测。',
  ),
  'probe-request-failed': _probeRequestFailedHint,
};

/// 按后端 `error.type` 分派 hint key。
///
/// [error] 为 null（healthy=false 但没带 error，理论上不会出现）或 type 不认识时，
/// 归到 `unexpected_error`。
String resolveMetadataProviderHintKey(
  StatusMetadataProviderTestErrorDto? error,
) {
  return switch (error?.type) {
    MetadataProviderErrorType.notFound => MetadataProviderErrorType.notFound,
    MetadataProviderErrorType.requestError =>
      MetadataProviderErrorType.requestError,
    _ => MetadataProviderErrorType.unexpected,
  };
}
