import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/auth/presentation/login_page.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';

final AppRouteDefinition desktopLoginRoute = AppRouteDefinition(
  id: AppRouteId.desktopLogin,
  name: 'login',
  platform: AppPlatform.desktop,
  path: loginPath,
  scope: AppRouteScope.outsideShell,
  pageBuilder: (context, state) =>
      const LoginPage(platform: AppPlatform.desktop),
  title: (l10n, [_]) => l10n.appTitle,
);

final AppRouteDefinition mobileLoginRoute = AppRouteDefinition(
  id: AppRouteId.mobileLogin,
  name: 'login',
  platform: AppPlatform.mobile,
  path: loginPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.material,
  pageBuilder: (context, state) =>
      const LoginPage(platform: AppPlatform.mobile),
  title: (l10n, [_]) => l10n.appTitle,
);
