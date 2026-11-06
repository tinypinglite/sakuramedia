import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/overview/presentation/pages/desktop/latest_movies_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/desktop/overview_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/desktop/recently_subscribed_movies_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/latest_movies_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/mobile_overview_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/recently_subscribed_movies_page.dart';
import 'package:sakuramedia/features/recent_views/presentation/pages/desktop/recent_views_page.dart';
import 'package:sakuramedia/features/recent_views/presentation/pages/mobile/recent_views_page.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';

final AppRouteDefinition desktopOverviewRoute = AppRouteDefinition(
  id: AppRouteId.desktopOverview,
  name: 'desktop-overview',
  platform: AppPlatform.desktop,
  path: desktopOverviewPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopOverviewPage(),
  title: (l10n, [_]) => l10n.routeOverviewTitle,
  nav: AppNavDestination(
    groupId: 'overview',
    order: 0,
    icon: Icons.space_dashboard_outlined,
    description: (l10n) => l10n.routeNavOverviewDescription,
  ),
);

final AppRouteDefinition desktopLatestMoviesRoute = AppRouteDefinition(
  id: AppRouteId.desktopLatestMovies,
  name: 'desktop-latest-movies',
  platform: AppPlatform.desktop,
  path: desktopLatestMoviesPath,
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => const DesktopLatestMoviesPage(),
  title: (l10n, [_]) => l10n.routeLatestAddedTitle,
  backTarget: (state) => desktopOverviewPath,
);

final AppRouteDefinition desktopRecentlySubscribedMoviesRoute =
    AppRouteDefinition(
      id: AppRouteId.desktopRecentlySubscribedMovies,
      name: 'desktop-recently-subscribed-movies',
      platform: AppPlatform.desktop,
      path: desktopRecentlySubscribedMoviesPath,
      scope: AppRouteScope.shellLevel,
      pageBuilder: (context, state) =>
          const DesktopRecentlySubscribedMoviesPage(),
      title: (l10n, [_]) => l10n.routeRecentlySubscribedTitle,
      backTarget: (state) => desktopOverviewPath,
    );

final AppRouteDefinition desktopRecentViewsRoute = AppRouteDefinition(
  id: AppRouteId.desktopRecentViews,
  name: 'desktop-recent-views',
  platform: AppPlatform.desktop,
  path: desktopRecentViewsPath,
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => const DesktopRecentViewsPage(),
  title: (l10n, [_]) => l10n.routeRecentViewsTitle,
  backTarget: (state) => desktopOverviewPath,
  nav: AppNavDestination(
    groupId: 'recent-views',
    order: 10,
    icon: Icons.visibility_outlined,
    activeIcon: Icons.visibility,
    description: (l10n) => l10n.routeNavRecentViewsDescription,
    sectionId: 'browse',
    switchMode: AppPrimarySwitchMode.push,
  ),
);

final AppRouteDefinition mobileOverviewRoute = AppRouteDefinition(
  id: AppRouteId.mobileOverview,
  name: 'mobile-overview',
  platform: AppPlatform.mobile,
  path: mobileOverviewPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const MobileOverviewPage(),
  title: (l10n, [_]) => l10n.routeOverviewTitle,
  nav: AppNavDestination(
    groupId: 'overview',
    order: 0,
    icon: Icons.pix_outlined,
    activeIcon: Icons.pix,
    description: (l10n) => l10n.routeNavMobileOverviewDescription,
  ),
);

final AppRouteDefinition mobileLatestMoviesRoute = AppRouteDefinition(
  id: AppRouteId.mobileLatestMovies,
  name: 'mobile-latest-movies',
  platform: AppPlatform.mobile,
  path: mobileLatestMoviesPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileLatestMoviesPage(),
  title: (l10n, [_]) => l10n.routeLatestAddedTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileRecentlySubscribedMoviesRoute =
    AppRouteDefinition(
      id: AppRouteId.mobileRecentlySubscribedMovies,
      name: 'mobile-recently-subscribed-movies',
      platform: AppPlatform.mobile,
      path: mobileRecentlySubscribedMoviesPath,
      scope: AppRouteScope.outsideShell,
      transition: AppRouteTransition.cupertino,
      subpageChrome: const AppSubpageChrome(glassChrome: true),
      pageBuilder: (context, state) =>
          const MobileRecentlySubscribedMoviesPage(),
      title: (l10n, [_]) => l10n.routeRecentlySubscribedTitle,
      backTarget: (state) => mobileOverviewPath,
    );

final AppRouteDefinition mobileRecentViewsRoute = AppRouteDefinition(
  id: AppRouteId.mobileRecentViews,
  name: 'mobile-recent-views',
  platform: AppPlatform.mobile,
  path: mobileRecentViewsPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileRecentViewsPage(),
  title: (l10n, [_]) => l10n.routeRecentViewsTitle,
  backTarget: (state) => mobileOverviewPath,
);
