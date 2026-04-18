import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/mobile_actor_detail_page.dart';
import 'package:sakuramedia/features/auth/presentation/login_page.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/presentation/desktop_configuration_page.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/movies/presentation/mobile_movie_detail_page.dart';
import 'package:sakuramedia/features/movies/presentation/mobile_movie_player_page.dart';
import 'package:sakuramedia/features/playlists/presentation/mobile_playlist_detail_page.dart';
import 'package:sakuramedia/features/search/presentation/mobile_catalog_search_page.dart';
import 'package:sakuramedia/routes/app_route_helpers.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_mobile_shell.dart';
import 'package:sakuramedia/widgets/app_shell/app_mobile_subpage_shell.dart';

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
        final imageUrl =
            item.image.origin.trim().isNotEmpty
                ? item.image.origin.trim()
                : item.image.bestAvailableUrl;
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

@TypedGoRoute<MobileConfigurationRouteData>(path: mobileConfigurationPath)
class MobileConfigurationRouteData extends _MobileSubpageRouteData
    with $MobileConfigurationRouteData {
  const MobileConfigurationRouteData();

  @override
  String get pageName => 'mobile-configuration';

  @override
  String get title => '配置管理';

  @override
  String get defaultLocation => mobileOverviewPath;

  @override
  Widget buildSubpage(BuildContext context, GoRouterState state) {
    return const DesktopConfigurationPage();
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

@TypedStatefulShellRoute<MobileRootShellRouteData>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<MobileOverviewBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<MobileOverviewRouteData>(
          path: mobileOverviewPath,
          routes: <TypedRoute<RouteData>>[
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

  @override
  Widget build(BuildContext context) {
    final spacing = hostContext.appSpacing;
    final colors = hostContext.appColors;
    final textTheme = Theme.of(hostContext).textTheme;

    return Drawer(
      key: const Key('mobile-overview-drawer'),
      backgroundColor: colors.surfaceCard,
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
              Text('菜单', style: textTheme.titleMedium),
              SizedBox(height: spacing.md),
              Expanded(
                child: SingleChildScrollView(
                  child: _MobileOverviewDrawerItem(
                    key: const Key('mobile-overview-drawer-configuration'),
                    icon: Icons.settings_suggest_outlined,
                    label: '配置管理',
                    onTap: () {
                      Navigator.of(context).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!hostContext.mounted) {
                          return;
                        }
                        const MobileConfigurationRouteData().push(hostContext);
                      });
                    },
                  ),
                ),
              ),
              Container(
                key: const Key('mobile-overview-drawer-bottom-actions'),
                padding: EdgeInsets.only(top: spacing.md),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.divider)),
                ),
                child: _MobileOverviewDrawerItem(
                  key: const Key('mobile-overview-drawer-logout'),
                  icon: Icons.logout_rounded,
                  label: '退出登录',
                  onTap: () {
                    Navigator.of(context).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!hostContext.mounted) {
                        return;
                      }
                      hostContext.read<SessionStore>().clearSession();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileOverviewDrawerItem extends StatelessWidget {
  const _MobileOverviewDrawerItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.appRadius.mdBorder,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.textPrimary),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
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
