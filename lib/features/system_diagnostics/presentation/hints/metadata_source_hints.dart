import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 元数据插件的账号、配置和安装入口都在配置页「插件」分类。
const DiagnosticFixTarget _metadataPluginsTarget =
    DiagnosticFixTarget.configurationTabKey('configuration-tab-plugins');

DiagnosticHint metadataSourcesEmptyHint(AppLocalizations l10n) =>
    DiagnosticHint(
      cause: l10n.diagnosticHintMetadataSourcesEmptyCause,
      fixHint: l10n.diagnosticHintMetadataSourcesEmptyFix,
      fixTarget: _metadataPluginsTarget,
    );

DiagnosticHint metadataSourcesProbeFailedHint(AppLocalizations l10n) =>
    DiagnosticHint(
      cause: l10n.diagnosticHintMetadataSourcesProbeFailedCause,
      fixHint: l10n.diagnosticHintBackendCheckRetryFix,
    );

DiagnosticHint metadataSourceEmptyHint(AppLocalizations l10n) => DiagnosticHint(
  cause: l10n.diagnosticHintMetadataSourceEmptyCause,
  fixHint: l10n.diagnosticHintMetadataSourceEmptyFix,
  fixTarget: _metadataPluginsTarget,
);

DiagnosticHint metadataSourceFailedHint(AppLocalizations l10n) =>
    DiagnosticHint(
      cause: l10n.diagnosticHintMetadataSourceFailedCause,
      fixHint: l10n.diagnosticHintMetadataSourceFailedFix,
      fixTarget: _metadataPluginsTarget,
    );

DiagnosticHint metadataSourceRequestFailedHint(AppLocalizations l10n) =>
    DiagnosticHint(
      cause: l10n.diagnosticHintProbeRequestFailedCause,
      fixHint: l10n.diagnosticHintBackendCheckRetryFix,
    );
