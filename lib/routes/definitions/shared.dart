import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/cast/presentation/pages/cast_remote_page.dart';
import 'package:sakuramedia/routes/app_route.dart';

final AppRouteDefinition desktopCastRemoteRoute = AppRouteDefinition(
  id: AppRouteId.desktopCastRemote,
  name: 'desktop-cast-remote',
  platform: AppPlatform.desktop,
  path: '/desktop/cast/remote',
  scope: AppRouteScope.outsideShell,
  pageBuilder: (context, state) => const CastRemotePage(),
  title: (l10n, [_]) => l10n.castPickerTitle,
);

final AppRouteDefinition mobileCastRemoteRoute = AppRouteDefinition(
  id: AppRouteId.mobileCastRemote,
  name: 'mobile-cast-remote',
  platform: AppPlatform.mobile,
  path: '/mobile/cast/remote',
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  pageBuilder: (context, state) => const CastRemotePage(),
  title: (l10n, [_]) => l10n.castPickerTitle,
);
