import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_registry.dart';

@immutable
class DesktopTopBarConfig {
  const DesktopTopBarConfig({
    required this.title,
    required this.fallbackPath,
    required this.isBackEnabled,
  });

  final String title;
  final String? fallbackPath;
  final bool isBackEnabled;
}

DesktopTopBarConfig resolveDesktopTopBarConfig({
  required GoRouterState state,
  required AppLocalizations l10n,
}) {
  final definition = appRoutes.forState(AppPlatform.desktop, state);
  final fallbackPath = AppRouteExtra.fallbackPathOf(
    state.extra,
    platform: AppPlatform.desktop,
  );
  final backTarget = definition?.backTarget?.call(state);
  return DesktopTopBarConfig(
    title: definition?.title(l10n, state) ?? state.uri.path,
    fallbackPath: fallbackPath ?? backTarget,
    isBackEnabled: fallbackPath != null || backTarget != null,
  );
}
