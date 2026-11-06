import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_collection_play_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_collection_detail_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_collections_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_list_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_player_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_thumbnail_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/pornbox_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_collection_play_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_collection_detail_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_collections_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_player_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_thumbnail_page.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/definitions/query_params.dart';

final AppRouteDefinition desktopVideosRoute = AppRouteDefinition(
  id: AppRouteId.desktopVideos,
  name: 'desktop-videos',
  platform: AppPlatform.desktop,
  path: desktopVideosPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopVideoListPage(),
  title: (l10n, [_]) => l10n.routeVideosTitle,
  nav: AppNavDestination(
    groupId: 'videos',
    order: 12,
    icon: Icons.video_library_outlined,
    description: (l10n) => l10n.routeNavVideosDescription,
    sectionId: 'browse',
  ),
);

final AppRouteDefinition desktopVideoPlayerRoute = AppRouteDefinition(
  id: AppRouteId.desktopVideoPlayer,
  name: 'desktop-video-player',
  platform: AppPlatform.desktop,
  path: '$desktopVideosPath/:videoId/player',
  scope: AppRouteScope.outsideShell,
  queryParameters: videoPlaybackQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(videoPlaybackQueryParameters, state);
    return DesktopVideoPlayerPage(
      videoId: int.parse(state.pathParameters['videoId']!),
      initialPositionSeconds: query.integer('positionSeconds'),
      fallbackPath:
          AppRouteExtra.fallbackPathOf(
            state.extra,
            platform: AppPlatform.desktop,
          ) ??
          desktopVideosPath,
    );
  },
  title: (l10n, [_]) => l10n.routeVideoDetailsTitle,
);

final AppRouteDefinition desktopVideoCollectionsRoute = AppRouteDefinition(
  id: AppRouteId.desktopVideoCollections,
  name: 'desktop-video-collections',
  platform: AppPlatform.desktop,
  path: desktopVideoCollectionsPath,
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => const DesktopVideoCollectionsPage(),
  title: (l10n, [_]) => l10n.routeVideoCollectionsTitle,
  backTarget: (state) => desktopVideosPath,
);

final AppRouteDefinition desktopVideoCollectionDetailRoute = AppRouteDefinition(
  id: AppRouteId.desktopVideoCollectionDetail,
  name: 'desktop-video-collection-detail',
  platform: AppPlatform.desktop,
  path: '$desktopVideoCollectionsPath/:collectionId',
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => DesktopVideoCollectionDetailPage(
    collectionId: int.parse(state.pathParameters['collectionId']!),
  ),
  title: (l10n, [_]) => l10n.routeCollectionDetailsTitle,
  backTarget: (state) => desktopVideoCollectionsPath,
);

final AppRouteDefinition desktopVideoCollectionPlayRoute = AppRouteDefinition(
  id: AppRouteId.desktopVideoCollectionPlay,
  name: 'desktop-video-collection-play',
  platform: AppPlatform.desktop,
  path: '$desktopVideoCollectionsPath/:collectionId/play',
  scope: AppRouteScope.outsideShell,
  queryParameters: collectionPlayQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(collectionPlayQueryParameters, state);
    return DesktopVideoCollectionPlayPage(
      collectionId: int.parse(state.pathParameters['collectionId']!),
      startIndex: query.integer('startIndex') ?? 0,
      sort: query.string('sort'),
    );
  },
  title: (l10n, [_]) => l10n.routeCollectionDetailsTitle,
);

final AppRouteDefinition desktopVideoThumbnailRoute = AppRouteDefinition(
  id: AppRouteId.desktopVideoThumbnail,
  name: 'desktop-video-thumbnails',
  platform: AppPlatform.desktop,
  path: '$desktopVideosPath/:videoId/thumbnails',
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => DesktopVideoThumbnailPage(
    videoId: int.parse(state.pathParameters['videoId']!),
  ),
  title: (l10n, [_]) => l10n.routeThumbnailsTitle,
  backTarget: (state) => desktopVideosPath,
);

final AppRouteDefinition mobilePornboxRoute = AppRouteDefinition(
  id: AppRouteId.mobilePornbox,
  name: 'mobile-pornbox',
  platform: AppPlatform.mobile,
  path: mobilePornboxPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const MobilePornboxPage(),
  title: (l10n, [_]) => l10n.routeVideosTitle,
  nav: AppNavDestination(
    groupId: 'pornbox',
    order: 4,
    icon: Icons.video_library_outlined,
    activeIcon: Icons.video_library,
    description: (l10n) => l10n.routeNavMobileVideosDescription,
  ),
);

final AppRouteDefinition mobileVideoPlayerRoute = AppRouteDefinition(
  id: AppRouteId.mobileVideoPlayer,
  name: 'mobile-video-player',
  platform: AppPlatform.mobile,
  path: '$mobileVideosPath/:videoId/player',
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  queryParameters: videoPlaybackQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(videoPlaybackQueryParameters, state);
    return MobileVideoPlayerPage(
      videoId: int.parse(state.pathParameters['videoId']!),
      initialPositionSeconds: query.integer('positionSeconds'),
    );
  },
  title: (l10n, [_]) => l10n.routeVideosTitle,
);

final AppRouteDefinition mobileVideoThumbnailRoute = AppRouteDefinition(
  id: AppRouteId.mobileVideoThumbnail,
  name: 'mobile-video-thumbnails',
  platform: AppPlatform.mobile,
  path: '$mobileVideosPath/:videoId/thumbnails',
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => MobileVideoThumbnailPage(
    videoId: int.parse(state.pathParameters['videoId']!),
  ),
  title: (l10n, [_]) => l10n.routeThumbnailsTitle,
  backTarget: (state) => mobilePornboxPath,
);

final AppRouteDefinition mobileVideoCollectionsRoute = AppRouteDefinition(
  id: AppRouteId.mobileVideoCollections,
  name: 'mobile-video-collections',
  platform: AppPlatform.mobile,
  path: mobileVideoCollectionsPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileVideoCollectionsPage(),
  title: (l10n, [_]) => l10n.routeVideoCollectionsTitle,
  backTarget: (state) => mobilePornboxPath,
);

final AppRouteDefinition mobileVideoCollectionDetailRoute = AppRouteDefinition(
  id: AppRouteId.mobileVideoCollectionDetail,
  name: 'mobile-video-collection-detail',
  platform: AppPlatform.mobile,
  path: '$mobileVideoCollectionsPath/:collectionId',
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => MobileVideoCollectionDetailPage(
    collectionId: int.parse(state.pathParameters['collectionId']!),
  ),
  title: (l10n, [_]) => l10n.routeCollectionsTitle,
  backTarget: (state) => mobileVideoCollectionsPath,
);

final AppRouteDefinition mobileVideoCollectionPlayRoute = AppRouteDefinition(
  id: AppRouteId.mobileVideoCollectionPlay,
  name: 'mobile-video-collection-play',
  platform: AppPlatform.mobile,
  path: '$mobileVideoCollectionsPath/:collectionId/play',
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  queryParameters: collectionPlayQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(collectionPlayQueryParameters, state);
    return MobileVideoCollectionPlayPage(
      collectionId: int.parse(state.pathParameters['collectionId']!),
      startIndex: query.integer('startIndex') ?? 0,
      sort: query.string('sort'),
    );
  },
  title: (l10n, [_]) => l10n.routeCollectionDetailsTitle,
);
