import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_routes.dart' as desktop_routes;
import 'package:sakuramedia/routes/mobile_routes.dart' as mobile_routes;

GoRouter buildAppRouter(AppPlatform platform, SessionStore sessionStore) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  switch (platform) {
    case AppPlatform.desktop:
      return buildDesktopRouter(sessionStore: sessionStore);
    case AppPlatform.mobile:
      return buildMobileRouter(sessionStore: sessionStore);
    case AppPlatform.web:
      return buildWebRouter(sessionStore: sessionStore);
  }
}

GoRouter buildDesktopRouter({required SessionStore sessionStore}) {
  desktop_routes.currentDesktopRoutePlatform = AppPlatform.desktop;
  return _buildRouter(
    sessionStore: sessionStore,
    navigatorKey: desktop_routes.desktopRootNavigatorKey,
    routes: desktop_routes.$appRoutes,
    rootRedirectPath: desktopOverviewPath,
  );
}

GoRouter buildMobileRouter({required SessionStore sessionStore}) {
  mobile_routes.currentMobileRoutePlatform = AppPlatform.mobile;
  return _buildRouter(
    sessionStore: sessionStore,
    navigatorKey: mobile_routes.mobileRootNavigatorKey,
    routes: mobile_routes.$appRoutes,
    rootRedirectPath: mobileOverviewPath,
  );
}

GoRouter buildWebRouter({required SessionStore sessionStore}) {
  desktop_routes.currentDesktopRoutePlatform = AppPlatform.web;
  return _buildRouter(
    sessionStore: sessionStore,
    navigatorKey: desktop_routes.desktopRootNavigatorKey,
    routes: desktop_routes.$appRoutes,
    rootRedirectPath: desktopOverviewPath,
  );
}

GoRouter _buildRouter({
  required SessionStore sessionStore,
  required GlobalKey<NavigatorState> navigatorKey,
  required List<RouteBase> routes,
  required String rootRedirectPath,
}) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    refreshListenable: sessionStore,
    routes: routes,
    redirect: (context, state) {
      final path = state.uri.path;
      final hasSession = sessionStore.hasSession;
      final isLoginPage = path == loginPath;

      if (!hasSession && !isLoginPage) {
        return loginPath;
      }
      if (hasSession && isLoginPage) {
        return rootRedirectPath;
      }
      if (path == '/') {
        return hasSession ? rootRedirectPath : loginPath;
      }
      return null;
    },
  );
}
