import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/app_version_info_controller.dart';
import 'package:sakuramedia/features/account/presentation/mobile_change_password_page.dart';
import 'package:sakuramedia/features/account/presentation/mobile_change_username_page.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actor_detail_page.dart';
import 'package:sakuramedia/features/activity/presentation/mobile_notifications_page.dart';
import 'package:sakuramedia/features/activity/presentation/notification_center_controller.dart';
import 'package:sakuramedia/features/auth/presentation/login_page.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/discovery/presentation/discovery_recommendation_list_pages.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_downloaders_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_indexers_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_media_libraries_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/llm_settings_page.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/mobile/clip_collection_detail_page.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/mobile/clip_collection_play_page.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/mobile/clip_collections_page.dart';
import 'package:sakuramedia/features/external_player/presentation/mobile_external_player_settings_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_collection_detail_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_collection_play_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_collections_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_detail_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_player_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/series_movies_page.dart';
import 'package:sakuramedia/features/overview/presentation/mobile_system_overview_page.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/mobile/playlists_page.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/mobile/playlist_detail_page.dart';
import 'package:sakuramedia/features/search/presentation/mobile_catalog_search_page.dart';
import 'package:sakuramedia/features/tags/presentation/mobile_tags_page.dart';
import 'package:sakuramedia/routes/app_route_helpers.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_shell.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

part 'mobile_routes.g.dart';

final GlobalKey<NavigatorState> mobileRootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'mobile-root-navigator');
final GlobalKey<NavigatorState> mobileOverviewNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'mobile-overview-navigator');
final GlobalKey<NavigatorState> mobileMoviesNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'mobile-movies-navigator');
final GlobalKey<NavigatorState> mobileActorsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'mobile-actors-navigator');
final GlobalKey<NavigatorState> mobileRankingsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'mobile-rankings-navigator');
final GlobalKey<NavigatorState> mobilePornboxNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'mobile-pornbox-navigator');
AppPlatform currentMobileRoutePlatform = AppPlatform.mobile;

@TypedGoRoute<MobileLoginRouteData>(path: loginPath)
class MobileLoginRouteData extends GoRouteData with $MobileLoginRouteData {
  const MobileLoginRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return LoginPage(platform: currentMobileRoutePlatform);
  }

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    return MaterialPage<void>(
      key: state.pageKey,
      name: 'login',
      child: build(context, state),
    );
  }
}

@TypedGoRoute<MobileSearchRouteData>(path: mobileSearchPath)
class MobileSearchRouteData extends _MobileSubpageRouteData
    with $MobileSearchRouteData {
  const MobileSearchRouteData({this.useOnlineSearch = false});

  final bool useOnlineSearch;

  @override
  String get pageName => 'mobile-search-empty';

  @override
  String get title => '搜索';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  String get location => buildRouteLocation(
    path: mobileSearchPath,
    queryParameters: <String, String?>{
      if (useOnlineSearch) 'useOnlineSearch': '$useOnlineSearch',
    },
  );

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobileCatalogSearchPage(
      initialQuery: '',
      initialUseOnlineSearch: resolveBoolQueryParameter(
        state,
        names: const <String>['useOnlineSearch', 'use-online-search'],
        fallback: useOnlineSearch,
      ),
    );
  }
}

// 以图搜图必须先于 `:query` 声明，避免 `/mobile/search/image` 被吞成普通搜索。
@TypedGoRoute<MobileImageSearchRouteData>(path: mobileImageSearchPath)
class MobileImageSearchRouteData extends _MobileSubpageRouteData
    with $MobileImageSearchRouteData {
  const MobileImageSearchRouteData({
    this.draftId,
    this.currentMovieNumber,
    this.currentMovieScope = 'all',
  });

  final String? draftId;
  final String? currentMovieNumber;
  final String currentMovieScope;

  @override
  String get pageName => 'mobile-image-search';

  @override
  String get title => '以图搜图';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  String get location => buildRouteLocation(
    path: mobileImageSearchPath,
    queryParameters: <String, String?>{
      if (draftId != null) 'draftId': draftId,
      if (currentMovieNumber != null) 'currentMovieNumber': currentMovieNumber,
      if (currentMovieScope != 'all') 'currentMovieScope': currentMovieScope,
    },
  );

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    final resolvedDraftId = resolveStringQueryParameter(
      state,
      names: const <String>['draftId', 'draft-id'],
      fallback: draftId,
    );
    final draft = context.read<ImageSearchDraftStore>().get(resolvedDraftId);
    return DesktopImageSearchPage(
      initialFileName: draft?.fileName,
      initialFileBytes: draft?.bytes,
      initialMimeType: draft?.mimeType,
      currentMovieNumber: resolveStringQueryParameter(
        state,
        names: const <String>['currentMovieNumber', 'current-movie-number'],
        fallback: currentMovieNumber,
      ),
      initialCurrentMovieScope: parseImageSearchCurrentMovieScope(
        resolveStringQueryParameter(
              state,
              names: const <String>['currentMovieScope', 'current-movie-scope'],
              fallback: currentMovieScope,
            ) ??
            currentMovieScope,
      ),
      imagePicker: pickMobileImageSearchFile,
      onSearchSimilar: (context, item) async {
        final imageUrl = item.image.resolvedUrl;
        final fileName =
            'image_search_${item.movieNumber}_${item.thumbnailId}.${guessImageFileExtension(imageUrl)}';
        try {
          final imageBytes = await context.read<ApiClient>().getBytes(imageUrl);
          if (!context.mounted) {
            return false;
          }
          final nextDraftId = context.read<ImageSearchDraftStore>().save(
            fileName: fileName,
            bytes: imageBytes,
            mimeType: guessImageMimeType(fileName),
          );
          await MobileImageSearchRouteData(
            draftId: nextDraftId,
            currentMovieNumber: item.movieNumber,
          ).push<bool>(context);
          return true;
        } catch (error) {
          if (context.mounted) {
            showToast(apiErrorMessage(error, fallback: '读取结果图片失败，请稍后重试'));
          }
          return false;
        }
      },
      onOpenPlayer: (context, item) {
        MobileMoviePlayerRouteData(
          movieNumber: item.movieNumber,
          mediaId: item.mediaId > 0 ? item.mediaId : null,
          positionSeconds: item.offsetSeconds,
        ).push(context);
      },
      onOpenMovieDetail: (context, item) {
        MobileMovieDetailRouteData(movieNumber: item.movieNumber).push(context);
      },
      resultPreviewPresentation:
          ImageSearchResultPreviewPresentation.bottomDrawer,
    );
  }
}

@TypedGoRoute<MobileSearchQueryRouteData>(path: '$mobileSearchPath/:query')
class MobileSearchQueryRouteData extends _MobileSubpageRouteData
    with $MobileSearchQueryRouteData {
  const MobileSearchQueryRouteData({
    required this.query,
    this.useOnlineSearch = false,
  });

  final String query;
  final bool useOnlineSearch;

  @override
  String get pageName => 'mobile-search';

  @override
  String get title => '搜索';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  String get location => buildRouteLocation(
    path: '$mobileSearchPath/${Uri.encodeComponent(query)}',
    queryParameters: <String, String?>{
      if (useOnlineSearch) 'useOnlineSearch': '$useOnlineSearch',
    },
  );

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobileCatalogSearchPage(
      initialQuery: query,
      initialUseOnlineSearch: resolveBoolQueryParameter(
        state,
        names: const <String>['useOnlineSearch', 'use-online-search'],
        fallback: useOnlineSearch,
      ),
    );
  }
}

@TypedGoRoute<MobileSettingsMediaLibrariesRouteData>(
  path: mobileSettingsMediaLibrariesPath,
)
class MobileSettingsMediaLibrariesRouteData extends _MobileSubpageRouteData
    with $MobileSettingsMediaLibrariesRouteData {
  const MobileSettingsMediaLibrariesRouteData();

  @override
  String get pageName => 'mobile-settings-media-libraries';

  @override
  String get title => '媒体库';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileMediaLibrariesPage();
  }
}


@TypedGoRoute<MobileSystemOverviewRouteData>(path: mobileSystemOverviewPath)
class MobileSystemOverviewRouteData extends _MobileSubpageRouteData
    with $MobileSystemOverviewRouteData {
  const MobileSystemOverviewRouteData();

  @override
  String get pageName => 'mobile-system-overview';

  @override
  String get title => '概览';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileSystemOverviewPage();
  }
}

@TypedGoRoute<MobileNotificationsRouteData>(path: mobileNotificationsPath)
class MobileNotificationsRouteData extends _MobileSubpageRouteData
    with $MobileNotificationsRouteData {
  const MobileNotificationsRouteData();

  @override
  String get pageName => 'mobile-notifications';

  @override
  String get title => '消息';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileNotificationsPage();
  }
}

@TypedGoRoute<MobileSettingsDownloadersRouteData>(
  path: mobileSettingsDownloadersPath,
)
class MobileSettingsDownloadersRouteData extends _MobileSubpageRouteData
    with $MobileSettingsDownloadersRouteData {
  const MobileSettingsDownloadersRouteData();

  @override
  String get pageName => 'mobile-settings-downloaders';

  @override
  String get title => '下载器';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileDownloadersPage();
  }
}

@TypedGoRoute<MobileSettingsIndexersRouteData>(path: mobileSettingsIndexersPath)
class MobileSettingsIndexersRouteData extends _MobileSubpageRouteData
    with $MobileSettingsIndexersRouteData {
  const MobileSettingsIndexersRouteData();

  @override
  String get pageName => 'mobile-settings-indexers';

  @override
  String get title => '索引器';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileIndexersPage();
  }
}

@TypedGoRoute<MobileSettingsLlmRouteData>(path: mobileSettingsLlmPath)
class MobileSettingsLlmRouteData extends _MobileSubpageRouteData
    with $MobileSettingsLlmRouteData {
  const MobileSettingsLlmRouteData();

  @override
  String get pageName => 'mobile-settings-llm';

  @override
  String get title => 'LLM 配置';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const LlmSettingsPage();
  }
}

@TypedGoRoute<MobileSettingsPlaylistsRouteData>(
  path: mobileSettingsPlaylistsPath,
)
class MobileSettingsPlaylistsRouteData extends _MobileSubpageRouteData
    with $MobileSettingsPlaylistsRouteData {
  const MobileSettingsPlaylistsRouteData();

  @override
  String get pageName => 'mobile-settings-playlists';

  @override
  String get title => '播放列表';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobilePlaylistsPage();
  }
}

@TypedGoRoute<MobileSettingsExternalPlayerRouteData>(
  path: mobileSettingsExternalPlayerPath,
)
class MobileSettingsExternalPlayerRouteData extends _MobileSubpageRouteData
    with $MobileSettingsExternalPlayerRouteData {
  const MobileSettingsExternalPlayerRouteData();

  @override
  String get pageName => 'mobile-settings-external-player';

  @override
  String get title => '外部播放器';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileExternalPlayerSettingsPage();
  }
}

@TypedGoRoute<MobileSettingsUsernameRouteData>(path: mobileSettingsUsernamePath)
class MobileSettingsUsernameRouteData extends _MobileSubpageRouteData
    with $MobileSettingsUsernameRouteData {
  const MobileSettingsUsernameRouteData();

  @override
  String get pageName => 'mobile-settings-username';

  @override
  String get title => '修改用户名';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  EdgeInsetsGeometry get bodyPadding => AppPageInsets.zero;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileChangeUsernamePage();
  }
}

@TypedGoRoute<MobileSettingsPasswordRouteData>(path: mobileSettingsPasswordPath)
class MobileSettingsPasswordRouteData extends _MobileSubpageRouteData
    with $MobileSettingsPasswordRouteData {
  const MobileSettingsPasswordRouteData();

  @override
  String get pageName => 'mobile-settings-password';

  @override
  String get title => '修改密码';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  EdgeInsetsGeometry get bodyPadding => AppPageInsets.zero;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileChangePasswordPage();
  }
}

@TypedGoRoute<MobileMoviePlayerRouteData>(
  path: '/mobile/library/movies/:movieNumber/player',
)
class MobileMoviePlayerRouteData extends _MobileCupertinoRouteData
    with $MobileMoviePlayerRouteData {
  const MobileMoviePlayerRouteData({
    required this.movieNumber,
    this.mediaId,
    this.positionSeconds,
  });

  final String movieNumber;
  final int? mediaId;
  final int? positionSeconds;

  @override
  String get pageName => 'mobile-movie-player';

  @override
  String get location => buildRouteLocation(
    path: '$mobileMoviesPath/${Uri.encodeComponent(movieNumber)}/player',
    queryParameters: <String, String?>{
      if (mediaId != null) 'mediaId': '$mediaId',
      if (positionSeconds != null) 'positionSeconds': '$positionSeconds',
    },
  );

  @override
  Widget buildCupertino(BuildContext context, GoRouterState state) {
    // 兼容 typed route 新参数名与现有 URL 中的旧参数名。
    return MobileMoviePlayerPage(
      movieNumber: movieNumber,
      initialMediaId: resolveIntQueryParameter(
        state,
        names: const <String>['mediaId', 'media-id'],
        fallback: mediaId,
      ),
      initialPositionSeconds: resolveIntQueryParameter(
        state,
        names: const <String>['positionSeconds', 'position-seconds'],
        fallback: positionSeconds,
      ),
    );
  }
}

@TypedGoRoute<MobileTagsRouteData>(path: mobileTagsPath)
class MobileTagsRouteData extends _MobileSubpageRouteData
    with $MobileTagsRouteData {
  const MobileTagsRouteData();

  @override
  String get pageName => 'mobile-tags';

  @override
  String get title => '标签';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileTagsPage();
  }
}

@TypedGoRoute<MobileTagMoviesRouteData>(path: '$mobileTagsPath/:tagId')
class MobileTagMoviesRouteData extends _MobileSubpageRouteData
    with $MobileTagMoviesRouteData {
  const MobileTagMoviesRouteData({required this.tagId});

  final int tagId;

  @override
  String get pageName => 'mobile-tag-movies';

  @override
  String get title => '标签';

  @override
  String get defaultLocation => mobileTagsPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobileTagsPage(initialTagId: tagId);
  }
}

@TypedGoRoute<MobileClipCollectionsRouteData>(path: mobileClipCollectionsPath)
class MobileClipCollectionsRouteData extends _MobileSubpageRouteData
    with $MobileClipCollectionsRouteData {
  const MobileClipCollectionsRouteData();

  @override
  String get pageName => 'mobile-clip-collections';

  @override
  String get title => '切片合集';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileClipCollectionsPage();
  }
}

@TypedGoRoute<MobileClipCollectionDetailRouteData>(
  path: '$mobileClipCollectionsPath/:collectionId',
)
class MobileClipCollectionDetailRouteData extends _MobileSubpageRouteData
    with $MobileClipCollectionDetailRouteData {
  const MobileClipCollectionDetailRouteData({required this.collectionId});

  final int collectionId;

  @override
  String get pageName => 'mobile-clip-collection-detail';

  @override
  String get title => '合集';

  @override
  String get defaultLocation => mobileClipCollectionsPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobileClipCollectionDetailPage(collectionId: collectionId);
  }
}

@TypedGoRoute<MobileClipCollectionPlayRouteData>(
  path: '$mobileClipCollectionsPath/:collectionId/play',
)
class MobileClipCollectionPlayRouteData extends _MobileCupertinoRouteData
    with $MobileClipCollectionPlayRouteData {
  const MobileClipCollectionPlayRouteData({
    required this.collectionId,
    this.startIndex = 0,
  });

  final int collectionId;
  final int startIndex;

  @override
  String get pageName => 'mobile-clip-collection-play';

  @override
  String get location => buildRouteLocation(
    path: '$mobileClipCollectionsPath/$collectionId/play',
    queryParameters: <String, String?>{
      if (startIndex > 0) 'startIndex': '$startIndex',
    },
  );

  @override
  Widget buildCupertino(BuildContext context, GoRouterState state) {
    return MobileClipCollectionPlayPage(
      collectionId: collectionId,
      startIndex:
          resolveIntQueryParameter(
            state,
            names: const <String>['startIndex', 'start-index'],
            fallback: startIndex,
          ) ??
          0,
    );
  }
}

@TypedGoRoute<MobileVideoCollectionsRouteData>(path: mobileVideoCollectionsPath)
class MobileVideoCollectionsRouteData extends _MobileSubpageRouteData
    with $MobileVideoCollectionsRouteData {
  const MobileVideoCollectionsRouteData();

  @override
  String get pageName => 'mobile-video-collections';

  @override
  String get title => '视频合集';

  @override
  String get defaultLocation => mobilePornboxPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileVideoCollectionsPage();
  }
}

@TypedGoRoute<MobileVideoCollectionDetailRouteData>(
  path: '$mobileVideoCollectionsPath/:collectionId',
)
class MobileVideoCollectionDetailRouteData extends _MobileSubpageRouteData
    with $MobileVideoCollectionDetailRouteData {
  const MobileVideoCollectionDetailRouteData({required this.collectionId});

  final int collectionId;

  @override
  String get pageName => 'mobile-video-collection-detail';

  @override
  String get title => '合集';

  @override
  String get defaultLocation => mobileVideoCollectionsPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobileVideoCollectionDetailPage(collectionId: collectionId);
  }
}

@TypedGoRoute<MobileVideoCollectionPlayRouteData>(
  path: '$mobileVideoCollectionsPath/:collectionId/play',
)
class MobileVideoCollectionPlayRouteData extends _MobileCupertinoRouteData
    with $MobileVideoCollectionPlayRouteData {
  const MobileVideoCollectionPlayRouteData({
    required this.collectionId,
    this.startIndex = 0,
    this.sort,
  });

  final int collectionId;
  final int startIndex;
  final String? sort;

  @override
  String get pageName => 'mobile-video-collection-play';

  @override
  String get location => buildRouteLocation(
    path: '$mobileVideoCollectionsPath/$collectionId/play',
    queryParameters: <String, String?>{
      if (startIndex > 0) 'startIndex': '$startIndex',
      if (sort != null && sort!.isNotEmpty) 'sort': sort,
    },
  );

  @override
  Widget buildCupertino(BuildContext context, GoRouterState state) {
    return MobileVideoCollectionPlayPage(
      collectionId: collectionId,
      startIndex:
          resolveIntQueryParameter(
            state,
            names: const <String>['startIndex', 'start-index'],
            fallback: startIndex,
          ) ??
          0,
      sort: resolveStringQueryParameter(
        state,
        names: const <String>['sort'],
        fallback: sort,
      ),
    );
  }
}

@TypedStatefulShellRoute<MobileRootShellRouteData>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<MobileOverviewBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<MobileOverviewRouteData>(
          path: mobileOverviewPath,
          routes: <TypedRoute<RouteData>>[
            TypedGoRoute<MobileDiscoverMoviesRouteData>(
              path: 'discover/movies',
            ),
            TypedGoRoute<MobileDiscoverMomentsRouteData>(
              path: 'discover/moments',
            ),
            TypedGoRoute<MobilePlaylistDetailRouteData>(
              path: 'playlists/:playlistId',
            ),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<MobileMoviesBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<MobileMoviesRouteData>(
          path: mobileMoviesPath,
          routes: <TypedRoute<RouteData>>[
            TypedGoRoute<MobileMovieSeriesRouteData>(path: 'series/:seriesId'),
            TypedGoRoute<MobileMovieDetailRouteData>(path: ':movieNumber'),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<MobileActorsBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<MobileActorsRouteData>(
          path: mobileActorsPath,
          routes: <TypedRoute<RouteData>>[
            TypedGoRoute<MobileActorDetailRouteData>(path: ':actorId'),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<MobileRankingsBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<MobileRankingsRouteData>(path: mobileRankingsPath),
      ],
    ),
    TypedStatefulShellBranch<MobilePornboxBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<MobilePornboxRouteData>(path: mobilePornboxPath),
      ],
    ),
  ],
)
class MobileRootShellRouteData extends StatefulShellRouteData {
  const MobileRootShellRouteData();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    final enableOverviewDrawer = state.uri.path == mobileOverviewPath;
    return AppMobileShell(
      currentPath: state.uri.path,
      navGroups: mobileNavGroups,
      currentIndex: navigationShell.currentIndex,
      drawer:
          enableOverviewDrawer
              ? _MobileOverviewDrawer(hostContext: context)
              : null,
      drawerEnableOpenDragGesture: enableOverviewDrawer,
      onDestinationSelected: (index) {
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
      },
      child: navigationShell,
    );
  }
}

class _MobileOverviewDrawer extends StatelessWidget {
  const _MobileOverviewDrawer({required this.hostContext});

  final BuildContext hostContext;

  static const _MobileOverviewDrawerMenuItem _overviewItem =
      _MobileOverviewDrawerMenuItem(
        key: 'overview',
        icon: Icons.space_dashboard_outlined,
        label: '概览',
      );

  static const _MobileOverviewDrawerMenuItem _tagsItem =
      _MobileOverviewDrawerMenuItem(
        key: 'tags',
        icon: Icons.sell_outlined,
        label: '标签',
      );

  static const List<_MobileOverviewDrawerMenuItem> _libraryItems =
      <_MobileOverviewDrawerMenuItem>[
        _MobileOverviewDrawerMenuItem(
          key: 'media-libraries',
          icon: Icons.video_library_outlined,
          label: '媒体库',
        ),
        _MobileOverviewDrawerMenuItem(
          key: 'downloaders',
          icon: Icons.download_outlined,
          label: '下载器',
        ),
        _MobileOverviewDrawerMenuItem(
          key: 'indexers',
          icon: Icons.travel_explore_outlined,
          label: '索引器',
        ),
        _MobileOverviewDrawerMenuItem(
          key: 'llm',
          icon: Icons.auto_awesome_outlined,
          label: 'LLM 配置',
        ),
      ];

  static const _MobileOverviewDrawerMenuItem _playlistsItem =
      _MobileOverviewDrawerMenuItem(
        key: 'playlists',
        icon: Icons.playlist_play_outlined,
        label: '播放列表',
      );

  static const _MobileOverviewDrawerMenuItem _externalPlayerItem =
      _MobileOverviewDrawerMenuItem(
        key: 'external-player',
        icon: Icons.open_in_new_rounded,
        label: '外部播放器',
      );

  // 调用外部播放器仅在 Android 原生实现，其它平台不展示该入口。
  static bool get _supportsExternalPlayer =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _MobileOverviewDrawerMenuItem _usernameItem =
      _MobileOverviewDrawerMenuItem(
        key: 'username',
        icon: Icons.person_outline_rounded,
        label: '修改用户名',
      );

  static const _MobileOverviewDrawerMenuItem _passwordItem =
      _MobileOverviewDrawerMenuItem(
        key: 'password',
        icon: Icons.lock_outline_rounded,
        label: '修改密码',
      );

  @override
  Widget build(BuildContext context) {
    final spacing = hostContext.appSpacing;
    final unreadCount = _watchNotificationUnreadCount(context) ?? 0;

    return Drawer(
      key: const Key('mobile-overview-drawer'),
      backgroundColor: hostContext.appColors.surfacePage,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.lg,
            spacing.lg,
            spacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MobileOverviewDrawerSection(
                        key: const Key(
                          'mobile-overview-drawer-overview-section',
                        ),
                        items: <Widget>[
                          _buildMenuEntry(
                            context: context,
                            item: _overviewItem,
                          ),
                        ],
                      ),
                      SizedBox(height: spacing.md),
                      _MobileOverviewDrawerSection(
                        key: const Key(
                          'mobile-overview-drawer-notifications-section',
                        ),
                        items: <Widget>[
                          _MobileOverviewDrawerItem(
                            key: const Key(
                              'mobile-overview-drawer-notifications',
                            ),
                            icon: Icons.notifications_none_rounded,
                            label: '消息',
                            trailing: unreadCount > 0
                                ? AppBadge(
                                    key: const Key(
                                      'mobile-overview-drawer-notifications-badge',
                                    ),
                                    label: unreadCount > 99
                                        ? '99+'
                                        : '$unreadCount',
                                    tone: AppBadgeTone.error,
                                    size: AppBadgeSize.compact,
                                  )
                                : null,
                            onTap: () {
                              Navigator.of(context).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!hostContext.mounted) {
                                  return;
                                }
                                const MobileNotificationsRouteData().push(
                                  hostContext,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: spacing.md),
                      _MobileOverviewDrawerSection(
                        key: const Key('mobile-overview-drawer-tags-section'),
                        items: <Widget>[
                          _buildMenuEntry(context: context, item: _tagsItem),
                        ],
                      ),
                      SizedBox(height: spacing.md),
                      if (_supportsExternalPlayer) ...[
                        _MobileOverviewDrawerSection(
                          key: const Key(
                            'mobile-overview-drawer-external-player-section',
                          ),
                          items: <Widget>[
                            _buildMenuEntry(
                              context: context,
                              item: _externalPlayerItem,
                            ),
                          ],
                        ),
                        SizedBox(height: spacing.md),
                      ],
                      _MobileOverviewDrawerSection(
                        key: const Key(
                          'mobile-overview-drawer-library-section',
                        ),
                        items: _libraryItems
                            .map(
                              (item) =>
                                  _buildMenuEntry(context: context, item: item),
                            )
                            .toList(growable: false),
                      ),
                      SizedBox(height: spacing.md),
                      _MobileOverviewDrawerSection(
                        key: const Key(
                          'mobile-overview-drawer-playlists-section',
                        ),
                        items: <Widget>[
                          _buildMenuEntry(
                            context: context,
                            item: _playlistsItem,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.md),
              _MobileOverviewDrawerSection(
                key: const Key('mobile-overview-drawer-account-section'),
                items: <Widget>[
                  _buildMenuEntry(context: context, item: _usernameItem),
                  _buildMenuEntry(context: context, item: _passwordItem),
                ],
              ),
              SizedBox(height: spacing.md),
              const _MobileDrawerVersionCard(),
              SizedBox(height: spacing.md),
              _MobileOverviewDrawerSection(
                key: const Key('mobile-overview-drawer-bottom-actions'),
                items: <Widget>[
                  _MobileOverviewDrawerItem(
                    key: const Key('mobile-overview-drawer-logout'),
                    icon: Icons.logout_rounded,
                    label: '退出登录',
                    onTap: () {
                      Navigator.of(context).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!hostContext.mounted) {
                          return;
                        }
                        hostContext.logOut();
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuEntry({
    required BuildContext context,
    required _MobileOverviewDrawerMenuItem item,
  }) {
    return _MobileOverviewDrawerItem(
      key: Key('mobile-overview-drawer-${item.key}'),
      icon: item.icon,
      label: item.label,
      onTap: () {
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!hostContext.mounted) {
            return;
          }
          _pushMenuRoute(item.key);
        });
      },
    );
  }

  void _pushMenuRoute(String key) {
    switch (key) {
      case 'overview':
        const MobileSystemOverviewRouteData().push(hostContext);
        return;
      case 'tags':
        const MobileTagsRouteData().push(hostContext);
        return;
      case 'media-libraries':
        const MobileSettingsMediaLibrariesRouteData().push(hostContext);
        return;
      case 'downloaders':
        const MobileSettingsDownloadersRouteData().push(hostContext);
        return;
      case 'indexers':
        const MobileSettingsIndexersRouteData().push(hostContext);
        return;
      case 'llm':
        const MobileSettingsLlmRouteData().push(hostContext);
        return;
      case 'playlists':
        const MobileSettingsPlaylistsRouteData().push(hostContext);
        return;
      case 'external-player':
        const MobileSettingsExternalPlayerRouteData().push(hostContext);
        return;
      case 'username':
        const MobileSettingsUsernameRouteData().push(hostContext);
        return;
      case 'password':
        const MobileSettingsPasswordRouteData().push(hostContext);
        return;
      default:
        return;
    }
  }
}

class _MobileDrawerVersionCard extends StatefulWidget {
  const _MobileDrawerVersionCard();

  @override
  State<_MobileDrawerVersionCard> createState() =>
      _MobileDrawerVersionCardState();
}

class _MobileDrawerVersionCardState extends State<_MobileDrawerVersionCard> {
  AppVersionInfoController? _loadedController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = _readVersionInfoController(context);
    if (controller == null || identical(controller, _loadedController)) {
      return;
    }
    _loadedController = controller;
    unawaited(controller.load());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _watchVersionInfoController(context);
    final frontendVersion = controller?.frontendVersionLabel ?? '--';
    final backendVersion = controller?.backendVersionLabel ?? '--';
    final spacing = context.appSpacing;

    return Container(
      key: const Key('mobile-overview-drawer-version-card'),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
      ),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '版本与服务',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              Text(
                '自动同步',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          _MobileDrawerVersionRow(label: '客户端', value: frontendVersion),
          SizedBox(height: spacing.xs),
          _MobileDrawerVersionRow(label: '服务端', value: backendVersion),
        ],
      ),
    );
  }
}

class _MobileDrawerVersionRow extends StatelessWidget {
  const _MobileDrawerVersionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(width: context.appSpacing.md),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.medium,
              tone: AppTextTone.primary,
            ),
          ),
        ),
      ],
    );
  }
}

int? _watchNotificationUnreadCount(BuildContext context) {
  try {
    return context.watch<NotificationCenterController>().unreadCount;
  } on ProviderNotFoundException {
    return null;
  }
}

AppVersionInfoController? _readVersionInfoController(BuildContext context) {
  try {
    return context.read<AppVersionInfoController>();
  } on ProviderNotFoundException {
    return null;
  }
}

AppVersionInfoController? _watchVersionInfoController(BuildContext context) {
  try {
    return context.watch<AppVersionInfoController>();
  } on ProviderNotFoundException {
    return null;
  }
}

class _MobileOverviewDrawerSection extends StatelessWidget {
  const _MobileOverviewDrawerSection({super.key, required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.xs),
        child: Column(
          children: items
              .expand((item) {
                final itemIndex = items.indexOf(item);
                return <Widget>[
                  item,
                  if (itemIndex < items.length - 1)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        start:
                            spacing.md +
                            componentTokens.iconSizeXl +
                            spacing.sm +
                            spacing.md,
                        end: spacing.md,
                      ),
                      child: Divider(
                        height: spacing.xs,
                        thickness: 1,
                        color: colors.borderSubtle.withValues(alpha: 0.56),
                      ),
                    ),
                ];
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _MobileOverviewDrawerMenuItem {
  const _MobileOverviewDrawerMenuItem({
    required this.key,
    required this.icon,
    required this.label,
  });

  final String key;
  final IconData icon;
  final String label;
}

class _MobileOverviewDrawerItem extends StatelessWidget {
  const _MobileOverviewDrawerItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.appRadius.lgBorder,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: componentTokens.iconSizeXl + spacing.sm,
                height: componentTokens.iconSizeXl + spacing.sm,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: context.appRadius.smBorder,
                ),
                child: Icon(
                  icon,
                  size: componentTokens.iconSizeMd,
                  color: context.appTextPalette.primary,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Text(
                  label,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: spacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MobileOverviewBranchData extends StatefulShellBranchData {
  const MobileOverviewBranchData();

  static final GlobalKey<NavigatorState> $navigatorKey =
      mobileOverviewNavigatorKey;
}

class MobileMoviesBranchData extends StatefulShellBranchData {
  const MobileMoviesBranchData();

  static final GlobalKey<NavigatorState> $navigatorKey =
      mobileMoviesNavigatorKey;
}

class MobileActorsBranchData extends StatefulShellBranchData {
  const MobileActorsBranchData();

  static final GlobalKey<NavigatorState> $navigatorKey =
      mobileActorsNavigatorKey;
}

class MobileRankingsBranchData extends StatefulShellBranchData {
  const MobileRankingsBranchData();

  static final GlobalKey<NavigatorState> $navigatorKey =
      mobileRankingsNavigatorKey;
}

class MobilePornboxBranchData extends StatefulShellBranchData {
  const MobilePornboxBranchData();

  static final GlobalKey<NavigatorState> $navigatorKey =
      mobilePornboxNavigatorKey;
}

class MobileOverviewRouteData extends _MobilePrimarySpecRouteData
    with $MobileOverviewRouteData {
  const MobileOverviewRouteData() : super(mobileOverviewPath);
}

class MobileMoviesRouteData extends _MobilePrimarySpecRouteData
    with $MobileMoviesRouteData {
  const MobileMoviesRouteData() : super(mobileMoviesPath);
}

class MobileActorsRouteData extends _MobilePrimarySpecRouteData
    with $MobileActorsRouteData {
  const MobileActorsRouteData() : super(mobileActorsPath);
}

class MobileRankingsRouteData extends _MobilePrimarySpecRouteData
    with $MobileRankingsRouteData {
  const MobileRankingsRouteData() : super(mobileRankingsPath);
}

class MobilePornboxRouteData extends _MobilePrimarySpecRouteData
    with $MobilePornboxRouteData {
  const MobilePornboxRouteData() : super(mobilePornboxPath);
}

class MobilePlaylistDetailRouteData extends _MobileSubpageRouteData
    with $MobilePlaylistDetailRouteData {
  const MobilePlaylistDetailRouteData({required this.playlistId});

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      mobileRootNavigatorKey;

  final int playlistId;

  @override
  String get pageName => 'mobile-playlist-detail';

  @override
  String get title => '播放列表详情';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobilePlaylistDetailPage(playlistId: playlistId);
  }
}

class MobileDiscoverMoviesRouteData extends _MobileSubpageRouteData
    with $MobileDiscoverMoviesRouteData {
  const MobileDiscoverMoviesRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      mobileRootNavigatorKey;

  @override
  String get pageName => 'mobile-discover-movies';

  @override
  String get title => '推荐影片';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileDiscoverMoviesPage();
  }
}

class MobileDiscoverMomentsRouteData extends _MobileSubpageRouteData
    with $MobileDiscoverMomentsRouteData {
  const MobileDiscoverMomentsRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      mobileRootNavigatorKey;

  @override
  String get pageName => 'mobile-discover-moments';

  @override
  String get title => '推荐时刻';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileDiscoverMomentsPage();
  }
}

class MobileMovieSeriesRouteData extends _MobileSubpageRouteData
    with $MobileMovieSeriesRouteData {
  const MobileMovieSeriesRouteData({required this.seriesId, this.seriesName});

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      mobileRootNavigatorKey;

  final int seriesId;
  final String? seriesName;

  @override
  String get pageName => 'mobile-movie-series';

  @override
  String get title => '系列影片';

  @override
  String get defaultLocation => mobileMoviesPath;

  @override
  String get location => buildRouteLocation(
    path: '$mobileMovieSeriesPathPrefix/$seriesId',
    queryParameters: <String, String?>{
      if (seriesName != null && seriesName!.trim().isNotEmpty)
        'seriesName': seriesName!.trim(),
    },
  );

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobileSeriesMoviesPage(
      seriesId: seriesId,
      seriesName: resolveStringQueryParameter(
        state,
        names: const <String>['seriesName', 'series-name'],
        fallback: seriesName,
      ),
    );
  }
}

class MobileMovieDetailRouteData extends _MobileSubpageRouteData
    with $MobileMovieDetailRouteData {
  const MobileMovieDetailRouteData({required this.movieNumber});

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      mobileRootNavigatorKey;

  final String movieNumber;

  @override
  String get pageName => 'mobile-movie-detail';

  @override
  String get title => '影片详情';

  @override
  String get defaultLocation => mobileMoviesPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobileMovieDetailPage(movieNumber: movieNumber);
  }
}

class MobileActorDetailRouteData extends _MobileSubpageRouteData
    with $MobileActorDetailRouteData {
  const MobileActorDetailRouteData({required this.actorId});

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      mobileRootNavigatorKey;

  final int actorId;

  @override
  String get pageName => 'mobile-actor-detail';

  @override
  String get title => '女优详情';

  @override
  String get defaultLocation => mobileActorsPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobileActorDetailPage(actorId: actorId);
  }
}

abstract class _MobilePrimaryRouteData extends GoRouteData {
  const _MobilePrimaryRouteData();

  String get pageName;
  Widget buildPrimary(BuildContext context, GoRouterState state);

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return buildPrimary(context, state);
  }

  @override
  NoTransitionPage<void> buildPage(BuildContext context, GoRouterState state) {
    return NoTransitionPage<void>(
      key: state.pageKey,
      name: pageName,
      child: buildPrimary(context, state),
    );
  }
}

abstract class _MobileSubpageRouteData extends GoRouteData {
  const _MobileSubpageRouteData();

  String get pageName;
  String get title;
  String get defaultLocation;
  EdgeInsetsGeometry get bodyPadding => AppPageInsets.compactStandard;

  Widget buildSubpage(BuildContext context, GoRouterState state);

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return buildSubpage(context, state);
  }

  @override
  CupertinoPage<void> buildPage(BuildContext context, GoRouterState state) {
    return CupertinoPage<void>(
      key: state.pageKey,
      name: pageName,
      child: AppMobileSubpageShell(
        title: title,
        defaultLocation: defaultLocation,
        currentPath: state.uri.path,
        bodyPadding: bodyPadding,
        child: buildSubpage(context, state),
      ),
    );
  }
}

abstract class _MobileCupertinoRouteData extends GoRouteData {
  const _MobileCupertinoRouteData();

  String get pageName;
  Widget buildCupertino(BuildContext context, GoRouterState state);

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return buildCupertino(context, state);
  }

  @override
  CupertinoPage<void> buildPage(BuildContext context, GoRouterState state) {
    return CupertinoPage<void>(
      key: state.pageKey,
      name: pageName,
      child: buildCupertino(context, state),
    );
  }
}

abstract class _MobilePrimarySpecRouteData extends _MobilePrimaryRouteData {
  const _MobilePrimarySpecRouteData(this.path);

  final String path;

  @override
  String get pageName => routeSpecNameForPath(mobileRouteSpecs, path);

  @override
  Widget buildPrimary(BuildContext context, GoRouterState state) {
    return buildRouteSpecContent(mobileRouteSpecs, path, context);
  }
}
