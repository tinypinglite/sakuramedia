import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 媒体库这一层没有后端 error 映射：`GET /media-libraries` 只返回列表。
/// 因此只有两种失败态——**列表是空的**，和**列表压根没拉到**。两者原因完全不同，
/// 各自一份 hint，不能共用（否则接口 500 会被说成"还没有配置媒体库"）。

/// 「媒体库」在配置页分类列表里的稳定 itemKey（见 `configuration_page.dart`）。
const DiagnosticFixTarget _mediaLibraryTarget =
    DiagnosticFixTarget.configurationTabKey(
      'configuration-tab-media-libraries',
    );

DiagnosticHint mediaLibraryEmptyHint(AppLocalizations l10n) => DiagnosticHint(
  cause: l10n.diagnosticHintMediaLibraryEmptyCause,
  fixHint: l10n.diagnosticHintMediaLibraryEmptyFix,
  fixTarget: _mediaLibraryTarget,
);

/// 拉媒体库列表这个请求本身失败了（后端不可达、超时、5xx、或响应结构不对）。
DiagnosticHint mediaLibraryProbeFailedHint(AppLocalizations l10n) =>
    DiagnosticHint(
      cause: l10n.diagnosticHintMediaLibraryProbeFailedCause,
      fixHint: l10n.diagnosticHintBackendCheckRetryFix,
    );
