import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/overview/presentation/providers/mobile_overview_tab_index_provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/features/account/presentation/pages/mobile/account_security_page.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actor_detail_page.dart';
import 'package:sakuramedia/features/activity/presentation/pages/mobile/activity_page.dart';
import 'package:sakuramedia/features/activity/presentation/pages/mobile/notifications_page.dart';
import 'package:sakuramedia/features/downloads/presentation/pages/mobile/download_tasks_page.dart';
import 'package:sakuramedia/features/auth/presentation/login_page.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/mobile/discover_moments_page.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/mobile/discover_movies_page.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/mobile/hot_actress_releases_page.dart';
import 'package:sakuramedia/features/image_search/presentation/pages/mobile/image_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_draft_store_provider.dart';
import 'package:sakuramedia/features/media/presentation/pages/mobile/media_management_page.dart';
import 'package:sakuramedia/features/media_import/presentation/pages/shared/media_import_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/appearance_settings_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_downloaders_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_download_selection_policy_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_indexers_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_media_libraries_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_media_tags_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_system_maintenance_page.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/mobile/mobile_plugin_market_page.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/mobile/mobile_plugins_page.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/mobile/clip_collection_detail_page.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/mobile/clip_collection_play_page.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/mobile/clip_collections_page.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/mobile/moment_collection_detail_page.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/mobile/moment_collections_page.dart';
import 'package:sakuramedia/features/external_player/presentation/pages/mobile/external_player_settings_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_collection_detail_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_collection_play_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_collections_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_player_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_thumbnail_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_detail_page.dart';
import 'package:sakuramedia/features/cast/presentation/pages/cast_remote_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_player_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/series_movies_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/latest_movies_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/recently_subscribed_movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/rated_movies_page.dart';
import 'package:sakuramedia/features/recent_views/presentation/pages/mobile/recent_views_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/system_overview_page.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/mobile/playlist_detail_page.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/mobile/system_playlist_page.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/search/presentation/pages/mobile/catalog_search_page.dart';
import 'package:sakuramedia/features/subscriptions/presentation/pages/mobile/follow_page.dart';
import 'package:sakuramedia/features/subscriptions/presentation/pages/mobile/movie_subscriptions_page.dart';
import 'package:sakuramedia/features/tags/presentation/pages/mobile/tags_page.dart';
import 'package:sakuramedia/routes/app_route_helpers.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_shell.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';
import 'package:sakuramedia/widgets/shell/mobile/mobile_overview_drawer.dart';

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
  String title(AppLocalizations l10n) => l10n.routeSearchTitle;

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
    this.mode = 'image',
  });

  final String? draftId;
  final String? currentMovieNumber;
  final String currentMovieScope;
  final String mode;

  @override
  String get pageName => 'mobile-image-search';

  @override
  String title(AppLocalizations l10n) => l10n.routeImageSearchTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  String get location => buildRouteLocation(
    path: mobileImageSearchPath,
    queryParameters: <String, String?>{
      if (draftId != null) 'draftId': draftId,
      if (currentMovieNumber != null) 'currentMovieNumber': currentMovieNumber,
      if (currentMovieScope != 'all') 'currentMovieScope': currentMovieScope,
      if (mode != 'image') 'mode': mode,
    },
  );

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    final resolvedDraftId = resolveStringQueryParameter(
      state,
      names: const <String>['draftId', 'draft-id'],
      fallback: draftId,
    );
    final draft = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(imageSearchDraftStoreProvider).get(resolvedDraftId);
    return MobileImageSearchPage(
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
      initialInputKind: parseImageSearchInputKind(
        resolveStringQueryParameter(
              state,
              names: const <String>['mode'],
              fallback: mode,
            ) ??
            mode,
      ),
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
  String title(AppLocalizations l10n) => l10n.routeSearchTitle;

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
  String title(AppLocalizations l10n) => l10n.configTabMediaLibraries;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileMediaLibrariesPage();
  }
}

@TypedGoRoute<MobileSettingsMediaTagsRouteData>(
  path: mobileSettingsMediaTagsPath,
)
class MobileSettingsMediaTagsRouteData extends _MobileSubpageRouteData
    with $MobileSettingsMediaTagsRouteData {
  const MobileSettingsMediaTagsRouteData();

  @override
  String get pageName => 'mobile-settings-media-tags';

  @override
  String title(AppLocalizations l10n) => l10n.configTabMediaTags;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileMediaTagsPage();
  }
}

@TypedGoRoute<MobileSettingsPluginsRouteData>(path: mobileSettingsPluginsPath)
class MobileSettingsPluginsRouteData extends _MobileSubpageRouteData
    with $MobileSettingsPluginsRouteData {
  const MobileSettingsPluginsRouteData();

  @override
  String get pageName => 'mobile-settings-plugins';

  @override
  String title(AppLocalizations l10n) => l10n.configTabPlugins;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobilePluginsPage();
  }
}

@TypedGoRoute<MobileSettingsPluginMarketRouteData>(
  path: mobileSettingsPluginMarketPath,
)
class MobileSettingsPluginMarketRouteData extends _MobileSubpageRouteData
    with $MobileSettingsPluginMarketRouteData {
  const MobileSettingsPluginMarketRouteData();

  @override
  String get pageName => 'mobile-settings-plugin-market';

  @override
  String title(AppLocalizations l10n) => l10n.pluginMarketTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobilePluginMarketPage();
  }
}

@TypedGoRoute<MobileLatestMoviesRouteData>(path: mobileLatestMoviesPath)
class MobileLatestMoviesRouteData extends _MobileSubpageRouteData
    with $MobileLatestMoviesRouteData {
  const MobileLatestMoviesRouteData();

  @override
  String get pageName => 'mobile-latest-movies';

  @override
  String title(AppLocalizations l10n) => l10n.routeLatestAddedTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileLatestMoviesPage();
  }
}

@TypedGoRoute<MobileRecentlySubscribedMoviesRouteData>(
  path: mobileRecentlySubscribedMoviesPath,
)
class MobileRecentlySubscribedMoviesRouteData extends _MobileSubpageRouteData
    with $MobileRecentlySubscribedMoviesRouteData {
  const MobileRecentlySubscribedMoviesRouteData();

  @override
  String get pageName => 'mobile-recently-subscribed-movies';

  @override
  String title(AppLocalizations l10n) => l10n.routeRecentlySubscribedTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileRecentlySubscribedMoviesPage();
  }
}

@TypedGoRoute<MobileRecentViewsRouteData>(path: mobileRecentViewsPath)
class MobileRecentViewsRouteData extends _MobileSubpageRouteData
    with $MobileRecentViewsRouteData {
  const MobileRecentViewsRouteData();

  @override
  String get pageName => 'mobile-recent-views';

  @override
  String title(AppLocalizations l10n) => l10n.routeRecentViewsTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileRecentViewsPage();
  }
}

@TypedGoRoute<MobileFavoritesRouteData>(path: mobileFavoritesPath)
class MobileFavoritesRouteData extends _MobileSubpageRouteData
    with $MobileFavoritesRouteData {
  const MobileFavoritesRouteData();

  @override
  String get pageName => 'mobile-favorites';

  @override
  String title(AppLocalizations l10n) => l10n.routeFavoritesTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileSystemPlaylistPage(kind: PlaylistKind.favorites);
  }
}

@TypedGoRoute<MobileRecentlyPlayedRouteData>(path: mobileRecentlyPlayedPath)
class MobileRecentlyPlayedRouteData extends _MobileSubpageRouteData
    with $MobileRecentlyPlayedRouteData {
  const MobileRecentlyPlayedRouteData();

  @override
  String get pageName => 'mobile-recently-played';

  @override
  String title(AppLocalizations l10n) => l10n.routeRecentlyPlayedTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileSystemPlaylistPage(kind: PlaylistKind.recentlyPlayed);
  }
}

@TypedGoRoute<MobileRatedMoviesRouteData>(path: mobileRatingsPath)
class MobileRatedMoviesRouteData extends _MobileSubpageRouteData
    with $MobileRatedMoviesRouteData {
  const MobileRatedMoviesRouteData();

  @override
  String get pageName => 'mobile-rated-movies';

  @override
  String title(AppLocalizations l10n) => l10n.routeRatingsTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileRatedMoviesPage();
  }
}

@TypedGoRoute<MobileSystemOverviewRouteData>(path: mobileSystemOverviewPath)
class MobileSystemOverviewRouteData extends _MobileSubpageRouteData
    with $MobileSystemOverviewRouteData {
  const MobileSystemOverviewRouteData();

  @override
  String get pageName => 'mobile-system-overview';

  @override
  String title(AppLocalizations l10n) => l10n.routeOverviewTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileSystemOverviewPage();
  }
}

@TypedGoRoute<MobileMediaImportRouteData>(path: mobileMediaImportPath)
class MobileMediaImportRouteData extends _MobileSubpageRouteData
    with $MobileMediaImportRouteData {
  const MobileMediaImportRouteData();

  @override
  String get pageName => 'mobile-media-import';

  @override
  String title(AppLocalizations l10n) => l10n.routeMediaImportTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MediaImportPage();
  }
}

@TypedGoRoute<MobileActivityRouteData>(path: mobileActivityPath)
class MobileActivityRouteData extends _MobileSubpageRouteData
    with $MobileActivityRouteData {
  const MobileActivityRouteData();

  @override
  String get pageName => 'mobile-activity';

  @override
  String title(AppLocalizations l10n) => l10n.routeTaskCenterTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileActivityPage();
  }
}

@TypedGoRoute<MobileDownloadTasksRouteData>(path: mobileDownloadTasksPath)
class MobileDownloadTasksRouteData extends _MobileSubpageRouteData
    with $MobileDownloadTasksRouteData {
  const MobileDownloadTasksRouteData({this.downloadMovieNumber});

  /// 打开下载任务页后按番号过滤的意图；走 query 参数，普通入口不携带。
  final String? downloadMovieNumber;

  @override
  String get pageName => 'mobile-download-tasks';

  @override
  String title(AppLocalizations l10n) => l10n.routeDownloadTasksTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    // query 解析由生成的 `_fromState` 完成（kebab-case），这里只转发。
    return MobileDownloadTasksPage(
      initialDownloadMovieNumber: downloadMovieNumber,
    );
  }
}

@TypedGoRoute<MobileNotificationsRouteData>(path: mobileNotificationsPath)
class MobileNotificationsRouteData extends _MobileSubpageRouteData
    with $MobileNotificationsRouteData {
  const MobileNotificationsRouteData();

  @override
  String get pageName => 'mobile-notifications';

  @override
  String title(AppLocalizations l10n) => l10n.routeMessagesTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileNotificationsPage();
  }
}

@TypedGoRoute<MobileMediaManagementRouteData>(path: mobileMediaManagementPath)
class MobileMediaManagementRouteData extends _MobileSubpageRouteData
    with $MobileMediaManagementRouteData {
  const MobileMediaManagementRouteData();

  @override
  String get pageName => 'mobile-media-management';

  @override
  String title(AppLocalizations l10n) => l10n.routeMediaManagementTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileMediaManagementPage();
  }
}

@TypedGoRoute<MobileMovieSubscriptionsRouteData>(
  path: mobileMovieSubscriptionsPath,
)
class MobileMovieSubscriptionsRouteData extends _MobileSubpageRouteData
    with $MobileMovieSubscriptionsRouteData {
  const MobileMovieSubscriptionsRouteData();

  @override
  String get pageName => 'mobile-movie-subscriptions';

  @override
  String title(AppLocalizations l10n) => l10n.routeSubscriptionManagementTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileMovieSubscriptionsPage();
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
  String title(AppLocalizations l10n) => l10n.configTabDownloadClients;

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
  String title(AppLocalizations l10n) => l10n.configTabIndexers;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileIndexersPage();
  }
}

@TypedGoRoute<MobileSettingsDownloadSelectionRouteData>(
  path: mobileSettingsDownloadSelectionPath,
)
class MobileSettingsDownloadSelectionRouteData extends _MobileSubpageRouteData
    with $MobileSettingsDownloadSelectionRouteData {
  const MobileSettingsDownloadSelectionRouteData();

  @override
  String get pageName => 'mobile-settings-download-selection';

  @override
  String title(AppLocalizations l10n) => l10n.configTabDownloadSelection;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  EdgeInsetsGeometry get bodyPadding => AppPageInsets.zero;

  @override
  bool get autoHideAppBar => false;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileDownloadSelectionPolicyPage();
  }
}

@TypedGoRoute<MobileSettingsSystemMaintenanceRouteData>(
  path: mobileSettingsSystemMaintenancePath,
)
class MobileSettingsSystemMaintenanceRouteData extends _MobileSubpageRouteData
    with $MobileSettingsSystemMaintenanceRouteData {
  const MobileSettingsSystemMaintenanceRouteData();

  @override
  String get pageName => 'mobile-settings-system-maintenance';

  @override
  String title(AppLocalizations l10n) => l10n.configTabSystemMaintenance;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileSystemMaintenancePage();
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
  String title(AppLocalizations l10n) => l10n.configTabExternalPlayer;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileExternalPlayerSettingsPage();
  }
}

@TypedGoRoute<MobileSettingsAppearanceRouteData>(
  path: mobileSettingsAppearancePath,
)
class MobileSettingsAppearanceRouteData extends _MobileSubpageRouteData
    with $MobileSettingsAppearanceRouteData {
  const MobileSettingsAppearanceRouteData();

  @override
  String get pageName => 'mobile-settings-appearance';

  @override
  String title(AppLocalizations l10n) => l10n.configTabAppearance;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileAppearanceSettingsPage();
  }
}

@TypedGoRoute<MobileSettingsAccountSecurityRouteData>(
  path: mobileSettingsAccountSecurityPath,
)
class MobileSettingsAccountSecurityRouteData extends _MobileSubpageRouteData
    with $MobileSettingsAccountSecurityRouteData {
  const MobileSettingsAccountSecurityRouteData();

  @override
  String get pageName => 'mobile-settings-account-security';

  @override
  String title(AppLocalizations l10n) => l10n.configTabAccountSecurity;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  EdgeInsetsGeometry get bodyPadding => AppPageInsets.zero;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileAccountSecurityPage();
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
    this.mergedLibraryId,
    this.positionSeconds,
  });

  final String movieNumber;
  final int? mediaId;
  final int? mergedLibraryId;
  final int? positionSeconds;

  @override
  String get pageName => 'mobile-movie-player';

  @override
  String get location => buildRouteLocation(
    path: '$mobileMoviesPath/${Uri.encodeComponent(movieNumber)}/player',
    queryParameters: <String, String?>{
      if (mediaId != null) 'mediaId': '$mediaId',
      if (mergedLibraryId != null) 'mergedLibraryId': '$mergedLibraryId',
      if (positionSeconds != null) 'positionSeconds': '$positionSeconds',
    },
  );

  @override
  Widget buildCupertino(BuildContext context, GoRouterState state) {
    // 兼容 typed route 新参数名与现有 URL 中的旧参数名。
    return MobileMoviePlayerPage(
      movieNumber: movieNumber,
      mergedLibraryId: resolveIntQueryParameter(
        state,
        names: const <String>['mergedLibraryId', 'merged-library-id'],
        fallback: mergedLibraryId,
      ),
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

@TypedGoRoute<MobileCastRemoteRouteData>(path: '/mobile/cast/remote')
class MobileCastRemoteRouteData extends _MobileCupertinoRouteData
    with $MobileCastRemoteRouteData {
  const MobileCastRemoteRouteData();

  @override
  String get pageName => 'mobile-cast-remote';

  @override
  String get location => buildRouteLocation(
    path: '/mobile/cast/remote',
    queryParameters: const <String, String?>{},
  );

  @override
  Widget buildCupertino(BuildContext context, GoRouterState state) {
    return const CastRemotePage();
  }
}

@TypedGoRoute<MobileVideoPlayerRouteData>(
  path: '/mobile/library/videos/:videoId/player',
)
class MobileVideoPlayerRouteData extends _MobileCupertinoRouteData
    with $MobileVideoPlayerRouteData {
  const MobileVideoPlayerRouteData({
    required this.videoId,
    this.positionSeconds,
  });

  final int videoId;
  final int? positionSeconds;

  @override
  String get pageName => 'mobile-video-player';

  @override
  String get location => buildRouteLocation(
    path: '/mobile/library/videos/$videoId/player',
    queryParameters: <String, String?>{
      if (positionSeconds != null) 'positionSeconds': '$positionSeconds',
    },
  );

  @override
  Widget buildCupertino(BuildContext context, GoRouterState state) {
    return MobileVideoPlayerPage(
      videoId: videoId,
      initialPositionSeconds: resolveIntQueryParameter(
        state,
        names: const <String>['positionSeconds', 'position-seconds'],
        fallback: positionSeconds,
      ),
    );
  }
}

@TypedGoRoute<MobileVideoThumbnailRouteData>(
  path: '/mobile/library/videos/:videoId/thumbnails',
)
class MobileVideoThumbnailRouteData extends _MobileSubpageRouteData
    with $MobileVideoThumbnailRouteData {
  const MobileVideoThumbnailRouteData({required this.videoId});

  final int videoId;

  @override
  String get pageName => 'mobile-video-thumbnails';

  @override
  String title(AppLocalizations l10n) => l10n.routeThumbnailsTitle;

  @override
  String get defaultLocation => mobilePornboxPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobileVideoThumbnailPage(videoId: videoId);
  }
}

@TypedGoRoute<MobileTagsRouteData>(path: mobileTagsPath)
class MobileTagsRouteData extends _MobileSubpageRouteData
    with $MobileTagsRouteData {
  const MobileTagsRouteData();

  @override
  String get pageName => 'mobile-tags';

  @override
  String title(AppLocalizations l10n) => l10n.routeTagsTitle;

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
  String title(AppLocalizations l10n) => l10n.routeTagsTitle;

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
  String title(AppLocalizations l10n) => l10n.routeClipCollectionsTitle;

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
  String title(AppLocalizations l10n) => l10n.routeCollectionsTitle;

  @override
  String get defaultLocation => mobileClipCollectionsPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobileClipCollectionDetailPage(collectionId: collectionId);
  }
}

@TypedGoRoute<MobileMomentCollectionsRouteData>(
  path: mobileMomentCollectionsPath,
)
class MobileMomentCollectionsRouteData extends _MobileSubpageRouteData
    with $MobileMomentCollectionsRouteData {
  const MobileMomentCollectionsRouteData();

  @override
  String get pageName => 'mobile-moment-collections';

  @override
  String title(AppLocalizations l10n) => l10n.routeMomentCollectionsTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileMomentCollectionsPage();
  }
}

@TypedGoRoute<MobileMomentCollectionDetailRouteData>(
  path: '$mobileMomentCollectionsPath/:collectionId',
)
class MobileMomentCollectionDetailRouteData extends _MobileSubpageRouteData
    with $MobileMomentCollectionDetailRouteData {
  const MobileMomentCollectionDetailRouteData({required this.collectionId});

  final int collectionId;

  @override
  String get pageName => 'mobile-moment-collection-detail';

  @override
  String title(AppLocalizations l10n) => l10n.routeCollectionsTitle;

  @override
  String get defaultLocation => mobileMomentCollectionsPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobileMomentCollectionDetailPage(collectionId: collectionId);
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
  String title(AppLocalizations l10n) => l10n.routeVideoCollectionsTitle;

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
  String title(AppLocalizations l10n) => l10n.routeCollectionsTitle;

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
            TypedGoRoute<MobileFollowRouteData>(path: 'discover/follow'),
            TypedGoRoute<MobileDiscoverMoviesRouteData>(
              path: 'discover/movies',
            ),
            TypedGoRoute<MobileDiscoverMomentsRouteData>(
              path: 'discover/moments',
            ),
            TypedGoRoute<MobileHotActressReleasesRouteData>(
              path: 'discover/hot-actress-releases',
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
    return _MobileRootShellScope(
      state: state,
      navigationShell: navigationShell,
    );
  }
}

/// 概览分支在底栏 / shell branch 列表中的序号。
///
/// 分支顺序由 `@TypedStatefulShellRoute` 的 branch 列表与 [mobileNavGroups] **两处
/// 独立维护**,硬编码 `0` 会在调序时静默把抽屉挂到错误分支上(不报错、不破测试),
/// 所以这里按路径反查。两处顺序若失配,`AppMobileShell` 的底栏高亮同样会错——那是
/// 更早就该暴露的问题,这里兜底回退到 0。
final int _overviewBranchIndex = () {
  final paths = mobileRouteSpecs
      .map((spec) => spec.path)
      .toList(growable: false);
  final index = paths.indexOf(mobileOverviewPath);
  return index < 0 ? 0 : index;
}();

/// 移动壳作用域。
///
/// tab 序号由 `mobileOverviewTabIndexProvider`(autoDispose 的 `@riverpod`
/// int Notifier)承载:首页在子树里经 notifier 上报,壳在这里 `ref.watch`
/// 读回来决定是否放开
/// 左边缘侧滑。**刻意不放 `app.dart` 的全局 providers**——它是纯移动端的
/// UI 手势状态,放全局会让桌面端白背一份、让每个 pump 移动路由的测试都得
/// 手动注入(漏注入时静默降级成"侧滑永久关闭"),也会和那批跨页 mutation
/// 广播 notifier 混淆语义。autoDispose 随壳挂载而新建、随壳销毁而释放。
class _MobileRootShellScope extends ConsumerStatefulWidget {
  const _MobileRootShellScope({
    required this.state,
    required this.navigationShell,
  });

  final GoRouterState state;
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_MobileRootShellScope> createState() =>
      _MobileRootShellScopeState();
}

class _MobileRootShellScopeState extends ConsumerState<_MobileRootShellScope> {
  // tab 序号已迁 mobileOverviewTabIndexProvider（autoDispose）：随壳 watch
  // 而创建、壳与首页 reporter 都不在时释放，作用域语义与旧局部 provider 一致。
  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final currentPath = widget.state.uri.path;
    // 按 branch 而非精确路径判定:概览分支内进子页时 drawer 也要保持存在。
    // 首页顶栏菜单按钮靠 Scaffold.maybeOf 取 ScaffoldState,而该 API 走
    // findAncestorStateOfType、不建立依赖——drawer 由 null 变为非 null 不会让
    // 保活的首页子树重建,按钮会锁死在禁用态("有时点不动")。
    final enableOverviewDrawer =
        navigationShell.currentIndex == _overviewBranchIndex;
    // 侧滑打开的门槛比 drawer 挂载更严,两个条件缺一不可:
    // ① 停在概览根路由——子页(播放列表详情等)盖的是 body,壳的边缘拖拽区仍在
    //    最上层,不排除的话在子页侧滑会拉出首页抽屉;
    // ② 首页停在第一个 tab——边缘拖拽区覆盖多宽,下面的 TabBarView 就有多宽收不
    //    到手势(实测),只有第一个 tab 右滑本就无处可去,让出来才不损失切页手势。
    final enableOverviewDrawerDrag =
        enableOverviewDrawer &&
        currentPath == mobileOverviewPath &&
        ref.watch(mobileOverviewTabIndexProvider) == 0;
    // 导航文案跟着语言走：订阅当前语言后重新解析分组，底栏与抽屉的标题随之更新。
    final navGroups = mobileNavGroups(ref.watch(appLocalizationsProvider));
    return AppMobileShell(
      currentPath: currentPath,
      navGroups: navGroups,
      currentIndex: navigationShell.currentIndex,
      drawer: enableOverviewDrawer
          ? MobileOverviewDrawer(
              hostContext: context,
              onMenuSelected: (key) =>
                  _handleOverviewDrawerSelection(context, key),
            )
          : null,
      drawerEnableOpenDragGesture: enableOverviewDrawerDrag,
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

/// 概览抽屉菜单 key → 路由 / 动作的映射。
///
/// UI 与菜单项定义在 `widgets/shell/mobile/mobile_overview_drawer.dart`，
/// 壳只负责把 key 映射到具体路由，避免组件层反向依赖路由表。
void _handleOverviewDrawerSelection(BuildContext hostContext, String key) {
  switch (key) {
    case 'overview':
      const MobileSystemOverviewRouteData().push(hostContext);
      return;
    case 'favorites':
      const MobileFavoritesRouteData().push(hostContext);
      return;
    case 'recently-played':
      const MobileRecentlyPlayedRouteData().push(hostContext);
      return;
    case 'recent-views':
      const MobileRecentViewsRouteData().push(hostContext);
      return;
    case 'ratings':
      const MobileRatedMoviesRouteData().push(hostContext);
      return;
    case 'notifications':
      const MobileNotificationsRouteData().push(hostContext);
      return;
    case 'tags':
      const MobileTagsRouteData().push(hostContext);
      return;
    case 'media-libraries':
      const MobileSettingsMediaLibrariesRouteData().push(hostContext);
      return;
    case 'media-tags':
      const MobileSettingsMediaTagsRouteData().push(hostContext);
      return;
    case 'downloaders':
      const MobileSettingsDownloadersRouteData().push(hostContext);
      return;
    case 'indexers':
      const MobileSettingsIndexersRouteData().push(hostContext);
      return;
    case 'download-selection':
      const MobileSettingsDownloadSelectionRouteData().push(hostContext);
      return;
    case 'media-management':
      const MobileMediaManagementRouteData().push(hostContext);
      return;
    case 'media-import':
      const MobileMediaImportRouteData().push(hostContext);
      return;
    case 'download-tasks':
      const MobileDownloadTasksRouteData().push(hostContext);
      return;
    case 'activity':
      const MobileActivityRouteData().push(hostContext);
      return;
    case 'movie-subscriptions':
      const MobileMovieSubscriptionsRouteData().push(hostContext);
      return;
    case 'system-maintenance':
      const MobileSettingsSystemMaintenanceRouteData().push(hostContext);
      return;
    case 'plugins':
      const MobileSettingsPluginsRouteData().push(hostContext);
      return;
    case 'external-player':
      const MobileSettingsExternalPlayerRouteData().push(hostContext);
      return;
    case 'appearance':
      const MobileSettingsAppearanceRouteData().push(hostContext);
      return;
    case 'account-security':
      const MobileSettingsAccountSecurityRouteData().push(hostContext);
      return;
    case 'logout':
      hostContext.logOut();
      return;
    default:
      return;
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
  String title(AppLocalizations l10n) => l10n.routePlaylistDetailsTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return MobilePlaylistDetailPage(playlistId: playlistId);
  }
}

class MobileFollowRouteData extends _MobileSubpageRouteData
    with $MobileFollowRouteData {
  const MobileFollowRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      mobileRootNavigatorKey;

  @override
  String get pageName => 'mobile-follow';

  @override
  String title(AppLocalizations l10n) => l10n.routeNewActorReleasesTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileFollowPage();
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
  String title(AppLocalizations l10n) => l10n.routeRecommendedMoviesTitle;

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
  String title(AppLocalizations l10n) => l10n.routeRecommendedMomentsTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileDiscoverMomentsPage();
  }
}

class MobileHotActressReleasesRouteData extends _MobileSubpageRouteData
    with $MobileHotActressReleasesRouteData {
  const MobileHotActressReleasesRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      mobileRootNavigatorKey;

  @override
  String get pageName => 'mobile-hot-actress-releases';

  @override
  String title(AppLocalizations l10n) => l10n.routePopularNewReleasesTitle;

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const MobileHotActressReleasesPage();
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
  String title(AppLocalizations l10n) => l10n.routeSeriesMoviesTitle;

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
  String title(AppLocalizations l10n) => l10n.routeMovieDetailsTitle;

  @override
  String get defaultLocation => mobileMoviesPath;

  @override
  bool get immersive => true;

  @override
  EdgeInsetsGeometry get bodyPadding => AppPageInsets.zero;

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
  String title(AppLocalizations l10n) => l10n.routeActorDetailsTitle;

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

  /// 子页标题；按当前语言返回，由调用方传入当前语言的 [AppLocalizations]。
  String title(AppLocalizations l10n);

  String get defaultLocation;
  EdgeInsetsGeometry get bodyPadding => AppPageInsets.compactStandard;
  bool get immersive => false;

  /// 子页是否随滚动收起 AppBar。默认全局开启；个别需要常驻的子页
  /// 覆盖为 false。immersive 子页收起的是悬浮返回栏，正文不位移。
  bool get autoHideAppBar => true;

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
      child: _LocalizedMobileSubpageShell(
        title: title,
        defaultLocation: defaultLocation,
        currentPath: state.uri.path,
        bodyPadding: bodyPadding,
        immersive: immersive,
        autoHideAppBar: autoHideAppBar,
        child: buildSubpage(context, state),
      ),
    );
  }
}

/// 子页壳：标题在 build 时按当前语言求值。
///
/// 路由的 `buildPage` 只跑一次，直接在那一层把标题算成字符串会在切换语言后
/// 留下旧文案；这里依赖 [Localizations] 重建，语言一变标题就跟着换。
class _LocalizedMobileSubpageShell extends StatelessWidget {
  const _LocalizedMobileSubpageShell({
    required this.title,
    required this.defaultLocation,
    required this.currentPath,
    required this.bodyPadding,
    required this.immersive,
    required this.autoHideAppBar,
    required this.child,
  });

  final String Function(AppLocalizations l10n) title;
  final String defaultLocation;
  final String currentPath;
  final EdgeInsetsGeometry bodyPadding;
  final bool immersive;
  final bool autoHideAppBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppMobileSubpageShell(
      title: title(AppLocalizations.of(context)),
      defaultLocation: defaultLocation,
      currentPath: currentPath,
      bodyPadding: bodyPadding,
      immersive: immersive,
      autoHideAppBar: autoHideAppBar,
      child: child,
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
