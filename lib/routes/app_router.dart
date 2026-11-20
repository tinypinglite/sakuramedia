import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/app_tooltip_navigator_observer.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/routes_desktop.dart';
import 'package:sakuramedia/routes/routes_mobile.dart';

GoRouter buildAppRouter(AppPlatform platform, SessionStore sessionStore) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  switch (platform) {
    case AppPlatform.desktop:
      return buildDesktopRouter(sessionStore: sessionStore);
    case AppPlatform.mobile:
      return buildMobileRouter(sessionStore: sessionStore);
  }
}

GoRouter buildDesktopRouter({required SessionStore sessionStore}) {
  return _buildRouter(
    sessionStore: sessionStore,
    navigatorKey: desktopRootNavigatorKey,
    routes: buildDesktopRouteTree(),
    rootRedirectPath: desktopOverviewPath,
  );
}

GoRouter buildMobileRouter({required SessionStore sessionStore}) {
  return _buildRouter(
    sessionStore: sessionStore,
    navigatorKey: mobileRootNavigatorKey,
    routes: buildMobileRouteTree(),
    rootRedirectPath: mobileOverviewPath,
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
    observers: <NavigatorObserver>[AppTooltipNavigatorObserver()],
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
