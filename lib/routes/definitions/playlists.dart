import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/desktop/playlist_detail_page.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/desktop/playlists_page.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/mobile/playlist_detail_page.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/shared/system_playlist_page.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';

final AppRouteDefinition desktopPlaylistsRoute = AppRouteDefinition(
  id: AppRouteId.desktopPlaylists,
  name: 'desktop-playlists',
  platform: AppPlatform.desktop,
  path: desktopPlaylistsPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopPlaylistsPage(),
  title: (l10n, [_]) => l10n.routePlaylistsTitle,
  nav: AppNavDestination(
    groupId: 'playlists',
    order: 7,
    icon: Icons.playlist_play_outlined,
    description: (l10n) => l10n.routeNavPlaylistsDescription,
    sectionId: 'browse',
  ),
);

final AppRouteDefinition desktopPlaylistDetailRoute = AppRouteDefinition(
  id: AppRouteId.desktopPlaylistDetail,
  name: 'desktop-playlist-detail',
  platform: AppPlatform.desktop,
  path: '$desktopPlaylistsPath/:playlistId',
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => DesktopPlaylistDetailPage(
    playlistId: int.parse(state.pathParameters['playlistId']!),
  ),
  title: (l10n, [_]) => l10n.routePlaylistDetailsTitle,
  backTarget: (state) => desktopPlaylistsPath,
);

final AppRouteDefinition desktopFavoritesRoute = AppRouteDefinition(
  id: AppRouteId.desktopFavorites,
  name: 'desktop-favorites',
  platform: AppPlatform.desktop,
  path: desktopFavoritesPath,
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => const SystemPlaylistPage(
    kind: PlaylistKind.favorites,
    mobile: false,
    fallbackPath: desktopFavoritesPath,
  ),
  title: (l10n, [_]) => l10n.routeFavoritesTitle,
  backTarget: (state) => desktopOverviewPath,
  nav: AppNavDestination(
    groupId: 'favorites',
    order: 8,
    icon: Icons.favorite_border_rounded,
    activeIcon: Icons.favorite_rounded,
    description: (l10n) => l10n.routeNavFavoritesDescription,
    sectionId: 'browse',
    switchMode: AppPrimarySwitchMode.push,
  ),
);

final AppRouteDefinition desktopRecentlyPlayedRoute = AppRouteDefinition(
  id: AppRouteId.desktopRecentlyPlayed,
  name: 'desktop-recently-played',
  platform: AppPlatform.desktop,
  path: desktopRecentlyPlayedPath,
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => const SystemPlaylistPage(
    kind: PlaylistKind.recentlyPlayed,
    mobile: false,
    fallbackPath: desktopRecentlyPlayedPath,
  ),
  title: (l10n, [_]) => l10n.routeRecentlyPlayedTitle,
  backTarget: (state) => desktopOverviewPath,
  nav: AppNavDestination(
    groupId: 'recently-played',
    order: 9,
    icon: Icons.play_circle_outline_rounded,
    description: (l10n) => l10n.routeNavRecentlyPlayedDescription,
    sectionId: 'browse',
    switchMode: AppPrimarySwitchMode.push,
  ),
);

final AppRouteDefinition mobilePlaylistDetailRoute = AppRouteDefinition(
  id: AppRouteId.mobilePlaylistDetail,
  name: 'mobile-playlist-detail',
  platform: AppPlatform.mobile,
  path: '$mobileOverviewPath/playlists/:playlistId',
  scope: AppRouteScope.branchChild,
  parentId: AppRouteId.mobileOverview,
  useRootNavigator: true,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => MobilePlaylistDetailPage(
    playlistId: int.parse(state.pathParameters['playlistId']!),
  ),
  title: (l10n, [_]) => l10n.routePlaylistDetailsTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileFavoritesRoute = AppRouteDefinition(
  id: AppRouteId.mobileFavorites,
  name: 'mobile-favorites',
  platform: AppPlatform.mobile,
  path: mobileFavoritesPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) =>
      const SystemPlaylistPage(kind: PlaylistKind.favorites, mobile: true),
  title: (l10n, [_]) => l10n.routeFavoritesTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileRecentlyPlayedRoute = AppRouteDefinition(
  id: AppRouteId.mobileRecentlyPlayed,
  name: 'mobile-recently-played',
  platform: AppPlatform.mobile,
  path: mobileRecentlyPlayedPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) =>
      const SystemPlaylistPage(kind: PlaylistKind.recentlyPlayed, mobile: true),
  title: (l10n, [_]) => l10n.routeRecentlyPlayedTitle,
  backTarget: (state) => mobileOverviewPath,
);
