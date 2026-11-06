import 'package:flutter/foundation.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

@immutable
class AppVersionInfoState {
  const AppVersionInfoState({
    this.frontendVersion = '',
    this.backendVersion = '',
  });

  static const AppVersionInfoState initial = AppVersionInfoState();

  final String frontendVersion;
  final String backendVersion;

  String get frontendVersionLabel => _versionOrPlaceholder(frontendVersion);
  String get backendVersionLabel => _versionOrPlaceholder(backendVersion);

  /// 版本信息 tooltip；按当前语言渲染。
  String tooltipLabelFor(AppLocalizations l10n) =>
      l10n.appVersionTooltip(frontendVersionLabel, backendVersionLabel);
}

String _versionOrPlaceholder(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '--' : trimmed;
}
