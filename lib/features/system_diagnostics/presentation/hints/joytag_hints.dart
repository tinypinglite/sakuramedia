import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// JoyTag 推理服务部署在后端侧，前端没有可配置入口，所以 fixTarget 一律留空。
///
/// 注：后端 `/status/image-search` 的 `healthy` 是嵌入服务与向量库（Qdrant）的 AND，
/// 这里只取嵌入服务一节——向量库不做独立诊断项。
Map<String, DiagnosticHint> joyTagHints(AppLocalizations l10n) =>
    <String, DiagnosticHint>{
      'unhealthy': DiagnosticHint(
        cause: l10n.diagnosticHintJoyTagUnhealthyCause,
        fixHint: l10n.diagnosticHintJoyTagUnhealthyFix,
      ),
      'status-unavailable': DiagnosticHint(
        cause: l10n.diagnosticHintProbeRequestFailedCause,
        fixHint: l10n.diagnosticHintBackendCheckRetryFix,
      ),
    };
