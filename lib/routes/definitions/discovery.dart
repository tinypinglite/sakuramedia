import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/discovery/presentation/desktop_discover_page.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/desktop/discover_moments_page.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/desktop/discover_movies_page.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/desktop/hot_actress_releases_page.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/mobile/discover_moments_page.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/mobile/discover_movies_page.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/mobile/hot_actress_releases_page.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/desktop/rankings_page.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/mobile/rankings_page.dart';
import 'package:sakuramedia/features/subscriptions/presentation/pages/desktop/follow_page.dart';
import 'package:sakuramedia/features/subscriptions/presentation/pages/mobile/follow_page.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';

final AppRouteDefinition desktopDiscoverRoute = AppRouteDefinition(
  id: AppRouteId.desktopDiscover,
  name: 'desktop-discover',
  platform: AppPlatform.desktop,
  path: desktopDiscoverPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopDiscoverPage(),
  title: (l10n, [_]) => l10n.routeDiscoverTitle,
  nav: AppNavDestination(
    groupId: 'discover',
    order: 1,
    icon: Icons.travel_explore_outlined,
    description: (l10n) => l10n.routeNavDiscoverDescription,
    sectionId: 'browse',
  ),
);

final AppRouteDefinition desktopDiscoverMoviesRoute = AppRouteDefinition(
  id: AppRouteId.desktopDiscoverMovies,
  name: 'desktop-discover-movies',
  platform: AppPlatform.desktop,
  path: desktopDiscoverMoviesPath,
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => const DesktopDiscoverMoviesPage(),
  title: (l10n, [_]) => l10n.routeRecommendedMoviesTitle,
  backTarget: (state) => desktopDiscoverPath,
);

final AppRouteDefinition desktopDiscoverMomentsRoute = AppRouteDefinition(
  id: AppRouteId.desktopDiscoverMoments,
  name: 'desktop-discover-moments',
  platform: AppPlatform.desktop,
  path: desktopDiscoverMomentsPath,
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => const DesktopDiscoverMomentsPage(),
  title: (l10n, [_]) => l10n.routeRecommendedMomentsTitle,
  backTarget: (state) => desktopDiscoverPath,
);

final AppRouteDefinition desktopHotActressReleasesRoute = AppRouteDefinition(
  id: AppRouteId.desktopHotActressReleases,
  name: 'desktop-hot-actress-releases',
  platform: AppPlatform.desktop,
  path: desktopHotActressReleasesPath,
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => const DesktopHotActressReleasesPage(),
  title: (l10n, [_]) => l10n.routePopularNewReleasesTitle,
  backTarget: (state) => desktopDiscoverPath,
);

final AppRouteDefinition desktopFollowRoute = AppRouteDefinition(
  id: AppRouteId.desktopFollow,
  name: 'desktop-follow',
  platform: AppPlatform.desktop,
  path: desktopFollowPath,
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => const DesktopFollowPage(),
  title: (l10n, [_]) => l10n.routeNewActorReleasesTitle,
  backTarget: (state) => desktopDiscoverPath,
);

final AppRouteDefinition desktopRankingsRoute = AppRouteDefinition(
  id: AppRouteId.desktopRankings,
  name: 'desktop-rankings',
  platform: AppPlatform.desktop,
  path: desktopRankingsPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopRankingsPage(),
  title: (l10n, [_]) => l10n.routeRankingsTitle,
  nav: AppNavDestination(
    groupId: 'rankings',
    order: 13,
    icon: Icons.local_fire_department_outlined,
    description: (l10n) => l10n.routeNavRankingsDescription,
    sectionId: 'browse',
  ),
);

final AppRouteDefinition mobileRankingsRoute = AppRouteDefinition(
  id: AppRouteId.mobileRankings,
  name: 'mobile-rankings',
  platform: AppPlatform.mobile,
  path: mobileRankingsPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const MobileRankingsPage(),
  title: (l10n, [_]) => l10n.routeRankingsBoardTitle,
  nav: AppNavDestination(
    groupId: 'rankings',
    order: 3,
    icon: Icons.local_fire_department_outlined,
    activeIcon: Icons.local_fire_department,
    description: (l10n) => l10n.routeNavMobileRankingsDescription,
  ),
);

final AppRouteDefinition mobileFollowRoute = AppRouteDefinition(
  id: AppRouteId.mobileFollow,
  name: 'mobile-follow',
  platform: AppPlatform.mobile,
  path: mobileFollowPath,
  scope: AppRouteScope.branchChild,
  parentId: AppRouteId.mobileOverview,
  useRootNavigator: true,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileFollowPage(),
  title: (l10n, [_]) => l10n.routeNewActorReleasesTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileDiscoverMoviesRoute = AppRouteDefinition(
  id: AppRouteId.mobileDiscoverMovies,
  name: 'mobile-discover-movies',
  platform: AppPlatform.mobile,
  path: mobileDiscoverMoviesPath,
  scope: AppRouteScope.branchChild,
  parentId: AppRouteId.mobileOverview,
  useRootNavigator: true,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileDiscoverMoviesPage(),
  title: (l10n, [_]) => l10n.routeRecommendedMoviesTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileDiscoverMomentsRoute = AppRouteDefinition(
  id: AppRouteId.mobileDiscoverMoments,
  name: 'mobile-discover-moments',
  platform: AppPlatform.mobile,
  path: mobileDiscoverMomentsPath,
  scope: AppRouteScope.branchChild,
  parentId: AppRouteId.mobileOverview,
  useRootNavigator: true,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileDiscoverMomentsPage(),
  title: (l10n, [_]) => l10n.routeRecommendedMomentsTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileHotActressReleasesRoute = AppRouteDefinition(
  id: AppRouteId.mobileHotActressReleases,
  name: 'mobile-hot-actress-releases',
  platform: AppPlatform.mobile,
  path: mobileHotActressReleasesPath,
  scope: AppRouteScope.branchChild,
  parentId: AppRouteId.mobileOverview,
  useRootNavigator: true,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileHotActressReleasesPage(),
  title: (l10n, [_]) => l10n.routePopularNewReleasesTitle,
  backTarget: (state) => mobileOverviewPath,
);
