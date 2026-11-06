import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/actors/presentation/pages/desktop/actor_detail_page.dart';
import 'package:sakuramedia/features/actors/presentation/pages/desktop/actors_page.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actor_detail_page.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actors_page.dart';
import 'package:sakuramedia/features/tags/presentation/pages/desktop/tags_page.dart';
import 'package:sakuramedia/features/tags/presentation/pages/mobile/tags_page.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';

final AppRouteDefinition desktopActorsRoute = AppRouteDefinition(
  id: AppRouteId.desktopActors,
  name: 'desktop-actors',
  platform: AppPlatform.desktop,
  path: desktopActorsPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopActorsPage(),
  title: (l10n, [_]) => l10n.routeActorsTitle,
  nav: AppNavDestination(
    groupId: 'actors',
    order: 3,
    icon: Icons.face_retouching_natural_outlined,
    description: (l10n) => l10n.routeNavActorsDescription,
    sectionId: 'browse',
  ),
);

final AppRouteDefinition desktopTagsRoute = AppRouteDefinition(
  id: AppRouteId.desktopTags,
  name: 'desktop-tags',
  platform: AppPlatform.desktop,
  path: desktopTagsPath,
  scope: AppRouteScope.branchRoot,
  showTopBar: false,
  pageBuilder: (context, state) => const DesktopTagsPage(),
  title: (l10n, [_]) => l10n.routeTagsTitle,
  nav: AppNavDestination(
    groupId: 'tags',
    order: 4,
    icon: Icons.sell_outlined,
    description: (l10n) => l10n.routeNavTagsDescription,
    sectionId: 'browse',
  ),
);

final AppRouteDefinition desktopActorDetailRoute = AppRouteDefinition(
  id: AppRouteId.desktopActorDetail,
  name: 'desktop-actor-detail',
  platform: AppPlatform.desktop,
  path: '$desktopActorsPath/:actorId',
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => DesktopActorDetailPage(
    actorId: int.parse(state.pathParameters['actorId']!),
  ),
  title: (l10n, [_]) => l10n.routeActorDetailsTitle,
  backTarget: (state) => desktopActorsPath,
);

final AppRouteDefinition desktopTagMoviesRoute = AppRouteDefinition(
  id: AppRouteId.desktopTagMovies,
  name: 'desktop-tag-movies',
  platform: AppPlatform.desktop,
  path: '$desktopTagsPath/:tagId',
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) =>
      DesktopTagsPage(initialTagId: int.parse(state.pathParameters['tagId']!)),
  title: (l10n, [_]) => l10n.routeTagsTitle,
  backTarget: (state) => desktopTagsPath,
);

final AppRouteDefinition mobileActorsRoute = AppRouteDefinition(
  id: AppRouteId.mobileActors,
  name: 'mobile-actors',
  platform: AppPlatform.mobile,
  path: mobileActorsPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const MobileActorsPage(),
  title: (l10n, [_]) => l10n.routeActorsTitle,
  nav: AppNavDestination(
    groupId: 'actors',
    order: 2,
    icon: Icons.face_4_outlined,
    activeIcon: Icons.face_4,
    description: (l10n) => l10n.routeNavMobileActorsDescription,
  ),
);

final AppRouteDefinition mobileActorDetailRoute = AppRouteDefinition(
  id: AppRouteId.mobileActorDetail,
  name: 'mobile-actor-detail',
  platform: AppPlatform.mobile,
  path: '$mobileActorsPath/:actorId',
  scope: AppRouteScope.branchChild,
  parentId: AppRouteId.mobileActors,
  useRootNavigator: true,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => MobileActorDetailPage(
    actorId: int.parse(state.pathParameters['actorId']!),
  ),
  title: (l10n, [_]) => l10n.routeActorDetailsTitle,
  backTarget: (state) => mobileActorsPath,
);

final AppRouteDefinition mobileTagsRoute = AppRouteDefinition(
  id: AppRouteId.mobileTags,
  name: 'mobile-tags',
  platform: AppPlatform.mobile,
  path: mobileTagsPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileTagsPage(),
  title: (l10n, [_]) => l10n.routeTagsTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileTagMoviesRoute = AppRouteDefinition(
  id: AppRouteId.mobileTagMovies,
  name: 'mobile-tag-movies',
  platform: AppPlatform.mobile,
  path: '$mobileTagsPath/:tagId',
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) =>
      MobileTagsPage(initialTagId: int.parse(state.pathParameters['tagId']!)),
  title: (l10n, [_]) => l10n.routeTagsTitle,
  backTarget: (state) => mobileTagsPath,
);
