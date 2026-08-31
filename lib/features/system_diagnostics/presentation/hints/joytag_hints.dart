import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';

/// JoyTag 推理服务部署在后端侧，前端没有可配置入口，所以 fixTarget 一律留空。
///
/// 注：后端 `/status/image-search` 的 `healthy` 是 joytag 与向量库（Qdrant）的 AND，
/// 这里只取 `joytag` 那一节——向量库不做独立诊断项。
const Map<String, DiagnosticHint> joyTagHints = <String, DiagnosticHint>{
  'unhealthy': DiagnosticHint(
    cause: 'JoyTag 推理服务没有响应。',
    fixHint: '在部署后端的机器上查看 joytag-infer 的日志。',
  ),
  'status-unavailable': DiagnosticHint(
    cause: '检测请求没完成，后端没有响应。',
    fixHint: '确认后端正常后重新检测。',
  ),
};
