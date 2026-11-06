import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/desktop/clip_collection_detail_page.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/desktop/clip_collection_play_page.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/desktop/clip_collections_page.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/mobile/clip_collection_detail_page.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/mobile/clip_collection_play_page.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/mobile/clip_collections_page.dart';
import 'package:sakuramedia/features/clips/presentation/pages/desktop/clips_page.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/desktop/moment_collection_detail_page.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/desktop/moment_collections_page.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/mobile/moment_collection_detail_page.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/mobile/moment_collections_page.dart';
import 'package:sakuramedia/features/moments/presentation/pages/desktop/moments_page.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/definitions/query_params.dart';

final AppRouteDefinition desktopClipsRoute = AppRouteDefinition(
  id: AppRouteId.desktopClips,
  name: 'desktop-clips',
  platform: AppPlatform.desktop,
  path: desktopClipsPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopClipsPage(),
  title: (l10n, [_]) => l10n.routeClipsTitle,
  nav: AppNavDestination(
    groupId: 'clips',
    order: 6,
    icon: Icons.content_cut_outlined,
    description: (l10n) => l10n.routeNavClipsDescription,
    sectionId: 'browse',
  ),
);

final AppRouteDefinition desktopMomentsRoute = AppRouteDefinition(
  id: AppRouteId.desktopMoments,
  name: 'desktop-moments',
  platform: AppPlatform.desktop,
  path: desktopMomentsPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopMomentsPage(),
  title: (l10n, [_]) => l10n.routeMomentsTitle,
  nav: AppNavDestination(
    groupId: 'moments',
    order: 5,
    icon: Icons.auto_awesome_motion_outlined,
    description: (l10n) => l10n.routeNavMomentsDescription,
    sectionId: 'browse',
  ),
);

final AppRouteDefinition desktopClipCollectionsRoute = AppRouteDefinition(
  id: AppRouteId.desktopClipCollections,
  name: 'desktop-clip-collections',
  platform: AppPlatform.desktop,
  path: desktopClipCollectionsPath,
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => const DesktopClipCollectionsPage(),
  title: (l10n, [_]) => l10n.routeClipCollectionsTitle,
  backTarget: (state) => desktopClipsPath,
);

final AppRouteDefinition desktopClipCollectionDetailRoute = AppRouteDefinition(
  id: AppRouteId.desktopClipCollectionDetail,
  name: 'desktop-clip-collection-detail',
  platform: AppPlatform.desktop,
  path: '$desktopClipCollectionsPath/:collectionId',
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => DesktopClipCollectionDetailPage(
    collectionId: int.parse(state.pathParameters['collectionId']!),
  ),
  title: (l10n, [_]) => l10n.routeCollectionDetailsTitle,
  backTarget: (state) => desktopClipCollectionsPath,
);

final AppRouteDefinition desktopClipCollectionPlayRoute = AppRouteDefinition(
  id: AppRouteId.desktopClipCollectionPlay,
  name: 'desktop-clip-collection-play',
  platform: AppPlatform.desktop,
  path: '$desktopClipCollectionsPath/:collectionId/play',
  scope: AppRouteScope.outsideShell,
  queryParameters: startIndexQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(startIndexQueryParameters, state);
    return DesktopClipCollectionPlayPage(
      collectionId: int.parse(state.pathParameters['collectionId']!),
      startIndex: query.integer('startIndex') ?? 0,
    );
  },
  title: (l10n, [_]) => l10n.routeClipCollectionsTitle,
);

final AppRouteDefinition desktopMomentCollectionsRoute = AppRouteDefinition(
  id: AppRouteId.desktopMomentCollections,
  name: 'desktop-moment-collections',
  platform: AppPlatform.desktop,
  path: desktopMomentCollectionsPath,
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => const DesktopMomentCollectionsPage(),
  title: (l10n, [_]) => l10n.routeMomentCollectionsTitle,
  backTarget: (state) => desktopMomentsPath,
);

final AppRouteDefinition desktopMomentCollectionDetailRoute =
    AppRouteDefinition(
      id: AppRouteId.desktopMomentCollectionDetail,
      name: 'desktop-moment-collection-detail',
      platform: AppPlatform.desktop,
      path: '$desktopMomentCollectionsPath/:collectionId',
      scope: AppRouteScope.shellLevel,
      pageBuilder: (context, state) => DesktopMomentCollectionDetailPage(
        collectionId: int.parse(state.pathParameters['collectionId']!),
      ),
      title: (l10n, [_]) => l10n.routeCollectionDetailsTitle,
      backTarget: (state) => desktopMomentCollectionsPath,
    );

final AppRouteDefinition mobileClipCollectionsRoute = AppRouteDefinition(
  id: AppRouteId.mobileClipCollections,
  name: 'mobile-clip-collections',
  platform: AppPlatform.mobile,
  path: mobileClipCollectionsPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileClipCollectionsPage(),
  title: (l10n, [_]) => l10n.routeClipCollectionsTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileClipCollectionDetailRoute = AppRouteDefinition(
  id: AppRouteId.mobileClipCollectionDetail,
  name: 'mobile-clip-collection-detail',
  platform: AppPlatform.mobile,
  path: '$mobileClipCollectionsPath/:collectionId',
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => MobileClipCollectionDetailPage(
    collectionId: int.parse(state.pathParameters['collectionId']!),
  ),
  title: (l10n, [_]) => l10n.routeCollectionsTitle,
  backTarget: (state) => mobileClipCollectionsPath,
);

final AppRouteDefinition mobileClipCollectionPlayRoute = AppRouteDefinition(
  id: AppRouteId.mobileClipCollectionPlay,
  name: 'mobile-clip-collection-play',
  platform: AppPlatform.mobile,
  path: '$mobileClipCollectionsPath/:collectionId/play',
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  queryParameters: startIndexQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(startIndexQueryParameters, state);
    return MobileClipCollectionPlayPage(
      collectionId: int.parse(state.pathParameters['collectionId']!),
      startIndex: query.integer('startIndex') ?? 0,
    );
  },
  title: (l10n, [_]) => l10n.routeClipCollectionsTitle,
);

final AppRouteDefinition mobileMomentCollectionsRoute = AppRouteDefinition(
  id: AppRouteId.mobileMomentCollections,
  name: 'mobile-moment-collections',
  platform: AppPlatform.mobile,
  path: mobileMomentCollectionsPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileMomentCollectionsPage(),
  title: (l10n, [_]) => l10n.routeMomentCollectionsTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileMomentCollectionDetailRoute = AppRouteDefinition(
  id: AppRouteId.mobileMomentCollectionDetail,
  name: 'mobile-moment-collection-detail',
  platform: AppPlatform.mobile,
  path: '$mobileMomentCollectionsPath/:collectionId',
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => MobileMomentCollectionDetailPage(
    collectionId: int.parse(state.pathParameters['collectionId']!),
  ),
  title: (l10n, [_]) => l10n.routeCollectionsTitle,
  backTarget: (state) => mobileMomentCollectionsPath,
);
