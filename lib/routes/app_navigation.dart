import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/actors/presentation/pages/desktop/actors_page.dart';
import 'package:sakuramedia/features/activity/presentation/pages/desktop/activity_page.dart';
import 'package:sakuramedia/features/downloads/presentation/pages/desktop/download_tasks_page.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actors_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/configuration_page.dart';
import 'package:sakuramedia/features/discovery/presentation/desktop_discover_page.dart';
import 'package:sakuramedia/features/media/presentation/pages/desktop/media_management_page.dart';
import 'package:sakuramedia/features/media_import/presentation/pages/shared/media_import_page.dart';
import 'package:sakuramedia/features/activity/presentation/pages/desktop/notifications_page.dart';
import 'package:sakuramedia/features/moments/presentation/pages/desktop/moments_page.dart';
import 'package:sakuramedia/features/tags/presentation/pages/desktop/tags_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movies_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/desktop/overview_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/mobile_overview_page.dart';
import 'package:sakuramedia/features/clips/presentation/pages/desktop/clips_page.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/desktop/playlists_page.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/desktop/system_playlist_page.dart';
import 'package:sakuramedia/features/recent_views/presentation/pages/desktop/recent_views_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/rated_movies_page.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/desktop/rankings_page.dart';
import 'package:sakuramedia/features/subscriptions/presentation/pages/desktop/movie_subscriptions_page.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/mobile/rankings_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_list_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/pornbox_page.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';

export 'app_route_paths.dart';

/// 导航文案解析器：按当前语言求值。
///
/// seed 只描述结构（分组 / slug / 图标 / 文案），文案一律来自 ARB。切语言时
/// 重新求值即可，不需要另维护一张按语言分表的常量副本；直接引用生成的
/// getter 也让 key 拼写错误在编译期暴露，而不是渲染出裸 key。
typedef _NavTextResolver = String Function(AppLocalizations l10n);

final List<_NavSeed> _mobileNavSeeds = [
  _NavSeed(
    id: 'overview',
    label: (l10n) => l10n.routeOverviewTitle,
    icon: Icons.pix_outlined,
    items: [
      _NavItemSeed(
        slug: 'overview',
        label: (l10n) => l10n.routeOverviewTitle,
        icon: Icons.pix_outlined,
        activeIcon: Icons.pix,
        description: (l10n) => l10n.routeNavMobileOverviewDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'movies',
    label: (l10n) => l10n.routeMoviesTitle,
    icon: Icons.movie_outlined,
    items: [
      _NavItemSeed(
        slug: 'library/movies',
        label: (l10n) => l10n.routeMoviesTitle,
        icon: Icons.movie_outlined,
        activeIcon: Icons.movie,
        description: (l10n) => l10n.routeNavMobileMoviesDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'actors',
    label: (l10n) => l10n.routeActorsTitle,
    icon: Icons.face_4_outlined,
    items: [
      _NavItemSeed(
        slug: 'library/actors',
        label: (l10n) => l10n.routeActorsTitle,
        icon: Icons.face_4_outlined,
        activeIcon: Icons.face_4,
        description: (l10n) => l10n.routeNavMobileActorsDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'rankings',
    label: (l10n) => l10n.routeRankingsBoardTitle,
    icon: Icons.local_fire_department_outlined,
    items: [
      _NavItemSeed(
        slug: 'rankings',
        label: (l10n) => l10n.routeRankingsBoardTitle,
        icon: Icons.local_fire_department_outlined,
        activeIcon: Icons.local_fire_department,
        description: (l10n) => l10n.routeNavMobileRankingsDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'pornbox',
    label: (l10n) => l10n.routeVideosTitle,
    icon: Icons.video_library_outlined,
    items: [
      _NavItemSeed(
        slug: 'pornbox',
        label: (l10n) => l10n.routeVideosTitle,
        icon: Icons.video_library_outlined,
        activeIcon: Icons.video_library,
        description: (l10n) => l10n.routeNavMobileVideosDescription,
      ),
    ],
  ),
];

final List<_NavSeed> _desktopNavSeeds = [
  _NavSeed(
    id: 'overview',
    label: (l10n) => l10n.routeOverviewTitle,
    icon: Icons.space_dashboard_outlined,
    items: [
      _NavItemSeed(
        slug: 'overview',
        label: (l10n) => l10n.routeOverviewTitle,
        icon: Icons.space_dashboard_outlined,
        description: (l10n) => l10n.routeNavOverviewDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'discover',
    label: (l10n) => l10n.routeDiscoverTitle,
    icon: Icons.travel_explore_outlined,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/discover',
        label: (l10n) => l10n.routeDiscoverTitle,
        icon: Icons.travel_explore_outlined,
        description: (l10n) => l10n.routeNavDiscoverDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'movies',
    label: (l10n) => l10n.routeMoviesTitle,
    icon: Icons.movie_creation_outlined,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/movies',
        label: (l10n) => l10n.routeMoviesTitle,
        icon: Icons.movie_creation_outlined,
        description: (l10n) => l10n.routeNavMoviesDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'actors',
    label: (l10n) => l10n.routeActorsTitle,
    icon: Icons.face_retouching_natural_outlined,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/actors',
        label: (l10n) => l10n.routeActorsTitle,
        icon: Icons.face_retouching_natural_outlined,
        description: (l10n) => l10n.routeNavActorsDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'tags',
    label: (l10n) => l10n.routeTagsTitle,
    icon: Icons.sell_outlined,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/tags',
        label: (l10n) => l10n.routeTagsTitle,
        icon: Icons.sell_outlined,
        description: (l10n) => l10n.routeNavTagsDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'moments',
    label: (l10n) => l10n.routeMomentsTitle,
    icon: Icons.auto_awesome_motion_outlined,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/moments',
        label: (l10n) => l10n.routeMomentsTitle,
        icon: Icons.auto_awesome_motion_outlined,
        description: (l10n) => l10n.routeNavMomentsDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'clips',
    label: (l10n) => l10n.routeClipsTitle,
    icon: Icons.content_cut_outlined,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/clips',
        label: (l10n) => l10n.routeClipsTitle,
        icon: Icons.content_cut_outlined,
        description: (l10n) => l10n.routeNavClipsDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'playlists',
    label: (l10n) => l10n.routePlaylistsTitle,
    icon: Icons.playlist_play_outlined,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/playlists',
        label: (l10n) => l10n.routePlaylistsTitle,
        icon: Icons.playlist_play_outlined,
        description: (l10n) => l10n.routeNavPlaylistsDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'favorites',
    label: (l10n) => l10n.routeFavoritesTitle,
    icon: Icons.favorite_border_rounded,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/favorites',
        label: (l10n) => l10n.routeFavoritesTitle,
        icon: Icons.favorite_border_rounded,
        activeIcon: Icons.favorite_rounded,
        description: (l10n) => l10n.routeNavFavoritesDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'recently-played',
    label: (l10n) => l10n.routeRecentlyPlayedTitle,
    icon: Icons.play_circle_outline_rounded,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/recently-played',
        label: (l10n) => l10n.routeRecentlyPlayedTitle,
        icon: Icons.play_circle_outline_rounded,
        description: (l10n) => l10n.routeNavRecentlyPlayedDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'recent-views',
    label: (l10n) => l10n.routeRecentViewsTitle,
    icon: Icons.visibility_outlined,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/recent-views',
        label: (l10n) => l10n.routeRecentViewsTitle,
        icon: Icons.visibility_outlined,
        activeIcon: Icons.visibility,
        description: (l10n) => l10n.routeNavRecentViewsDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'ratings',
    label: (l10n) => l10n.routeRatingsTitle,
    icon: Icons.star_outline_rounded,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/ratings',
        label: (l10n) => l10n.routeRatingsTitle,
        icon: Icons.star_outline_rounded,
        activeIcon: Icons.star_rounded,
        description: (l10n) => l10n.routeNavRatingsDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'videos',
    label: (l10n) => l10n.routeVideosTitle,
    icon: Icons.video_library_outlined,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/videos',
        label: (l10n) => l10n.routeVideosTitle,
        icon: Icons.video_library_outlined,
        description: (l10n) => l10n.routeNavVideosDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'rankings',
    label: (l10n) => l10n.routeRankingsTitle,
    icon: Icons.local_fire_department_outlined,
    section: (l10n) => l10n.routeNavBrowseSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'library/rankings',
        label: (l10n) => l10n.routeRankingsTitle,
        icon: Icons.local_fire_department_outlined,
        description: (l10n) => l10n.routeNavRankingsDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'media',
    label: (l10n) => l10n.routeMediaManagementTitle,
    icon: Icons.video_settings_outlined,
    section: (l10n) => l10n.routeNavManageSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'system/media',
        label: (l10n) => l10n.routeMediaManagementTitle,
        icon: Icons.video_settings_outlined,
        description: (l10n) => l10n.routeNavMediaManagementDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'media-import',
    label: (l10n) => l10n.routeMediaImportTitle,
    icon: Icons.drive_folder_upload_outlined,
    section: (l10n) => l10n.routeNavManageSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'system/media-import',
        label: (l10n) => l10n.routeMediaImportTitle,
        icon: Icons.drive_folder_upload_outlined,
        description: (l10n) => l10n.routeNavMediaImportDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'download-tasks',
    label: (l10n) => l10n.routeDownloadTasksTitle,
    icon: Icons.download_for_offline_outlined,
    section: (l10n) => l10n.routeNavManageSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'system/download-tasks',
        label: (l10n) => l10n.routeDownloadTasksTitle,
        icon: Icons.download_for_offline_outlined,
        description: (l10n) => l10n.routeNavDownloadTasksDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'activity',
    label: (l10n) => l10n.routeTaskCenterTitle,
    icon: Icons.bolt_outlined,
    section: (l10n) => l10n.routeNavManageSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'system/activity',
        label: (l10n) => l10n.routeTaskCenterTitle,
        icon: Icons.bolt_outlined,
        description: (l10n) => l10n.routeNavTaskCenterDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'movie-subscriptions',
    label: (l10n) => l10n.routeSubscriptionManagementTitle,
    icon: Icons.bookmark_added_outlined,
    section: (l10n) => l10n.routeNavManageSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'system/movie-subscriptions',
        label: (l10n) => l10n.routeSubscriptionManagementTitle,
        icon: Icons.bookmark_added_outlined,
        description: (l10n) => l10n.routeNavSubscriptionManagementDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'notifications',
    label: (l10n) => l10n.routeNotificationsTitle,
    icon: Icons.notifications_none_outlined,
    section: (l10n) => l10n.routeNavManageSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'system/notifications',
        label: (l10n) => l10n.routeNotificationsTitle,
        icon: Icons.notifications_none_outlined,
        description: (l10n) => l10n.routeNavNotificationsDescription,
      ),
    ],
  ),
  _NavSeed(
    id: 'configuration',
    label: (l10n) => l10n.routeConfigurationTitle,
    icon: Icons.settings_suggest_outlined,
    section: (l10n) => l10n.routeNavManageSectionLabel,
    items: [
      _NavItemSeed(
        slug: 'system/configuration',
        label: (l10n) => l10n.routeConfigurationTitle,
        icon: Icons.settings_suggest_outlined,
        description: (l10n) => l10n.routeNavConfigurationDescription,
      ),
    ],
  ),
];

final Map<String, WidgetBuilder> _desktopRouteBuilders =
    <String, WidgetBuilder>{
      desktopOverviewPath: (_) => const DesktopOverviewPage(),
      desktopDiscoverPath: (_) => const DesktopDiscoverPage(),
      desktopMoviesPath: (_) => const DesktopMoviesPage(),
      desktopActorsPath: (_) => const DesktopActorsPage(),
      desktopTagsPath: (_) => const DesktopTagsPage(),
      desktopMomentsPath: (_) => const DesktopMomentsPage(),
      desktopPlaylistsPath: (_) => const DesktopPlaylistsPage(),
      desktopFavoritesPath: (_) => const DesktopSystemPlaylistPage(
        kind: PlaylistKind.favorites,
        fallbackPath: desktopFavoritesPath,
      ),
      desktopRecentlyPlayedPath: (_) => const DesktopSystemPlaylistPage(
        kind: PlaylistKind.recentlyPlayed,
        fallbackPath: desktopRecentlyPlayedPath,
      ),
      desktopRecentViewsPath: (_) => const DesktopRecentViewsPage(),
      desktopRatingsPath: (_) => const DesktopRatedMoviesPage(),
      desktopClipsPath: (_) => const DesktopClipsPage(),
      desktopVideosPath: (_) => const DesktopVideoListPage(),
      desktopRankingsPath: (_) => const DesktopRankingsPage(),
      desktopActivityPath: (_) => const DesktopActivityPage(),
      desktopDownloadTasksPath: (_) => const DesktopDownloadTasksPage(),
      desktopMediaPath: (_) => const DesktopMediaManagementPage(),
      desktopNotificationsPath: (_) => const DesktopNotificationsPage(),
      desktopConfigurationPath: (_) => const DesktopConfigurationPage(),
      desktopMediaImportPath: (_) => const MediaImportPage(),
      desktopMovieSubscriptionsPath: (_) =>
          const DesktopMovieSubscriptionsPage(),
    };

final Map<String, WidgetBuilder> _mobileRouteBuilders = <String, WidgetBuilder>{
  mobileOverviewPath: (_) => const MobileOverviewPage(),
  mobileMoviesPath: (_) => const MobileMoviesPage(),
  mobileActorsPath: (_) => const MobileActorsPage(),
  mobileRankingsPath: (_) => const MobileRankingsPage(),
  mobilePornboxPath: (_) => const MobilePornboxPage(),
};

/// 导航分组（侧边栏 / 底栏），文案按 [l10n] 当前语言渲染。
List<AppNavGroup> navGroupsForPlatform(
  AppPlatform platform, {
  required AppLocalizations l10n,
}) {
  final prefix = switch (platform) {
    AppPlatform.desktop => '/desktop',
    AppPlatform.mobile => '/mobile',
  };

  AppNavItem item({
    required String slug,
    required String label,
    required IconData icon,
    IconData? activeIcon,
    required String description,
  }) {
    return AppNavItem(
      name: '${platform.name}-$slug',
      label: label,
      path: '$prefix/$slug',
      icon: icon,
      activeIcon: activeIcon,
      description: description,
    );
  }

  final seeds = switch (platform) {
    AppPlatform.desktop => _desktopNavSeeds,
    AppPlatform.mobile => _mobileNavSeeds,
  };

  return seeds
      .map(
        (seed) => AppNavGroup(
          id: seed.id,
          label: seed.label(l10n),
          icon: seed.icon,
          isCollapsible: false,
          sectionLabel: seed.section?.call(l10n),
          items: seed.items
              .map(
                (seedItem) => item(
                  slug: seedItem.slug,
                  label: seedItem.label(l10n),
                  icon: seedItem.icon,
                  activeIcon: seedItem.activeIcon,
                  description: seedItem.description(l10n),
                ),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
}

/// 路由规格只描述结构（名称 / 路径 / 布局 / 构造器），不含文案；
/// 文案在 [navGroupsForPlatform] 与顶栏配置里按当前语言解析。
List<AppRouteSpec> routeSpecsForPlatform(AppPlatform platform) {
  final routeBuilders = switch (platform) {
    AppPlatform.desktop => _desktopRouteBuilders,
    AppPlatform.mobile => _mobileRouteBuilders,
  };

  final prefix = switch (platform) {
    AppPlatform.desktop => '/desktop',
    AppPlatform.mobile => '/mobile',
  };

  final seeds = switch (platform) {
    AppPlatform.desktop => _desktopNavSeeds,
    AppPlatform.mobile => _mobileNavSeeds,
  };

  return seeds
      .expand(
        (seed) => seed.items.map((seedItem) {
          final path = '$prefix/${seedItem.slug}';
          return AppRouteSpec(
            platform: platform,
            name: '${platform.name}-${seedItem.slug}',
            path: path,
            groupId: seed.id,
            layout: AppShellLayout.standard,
            builder: (context) => routeBuilders[path]!(context),
          );
        }),
      )
      .toList(growable: false);
}

List<AppRouteSpec> get desktopRouteSpecs =>
    routeSpecsForPlatform(AppPlatform.desktop);
List<AppRouteSpec> get mobileRouteSpecs =>
    routeSpecsForPlatform(AppPlatform.mobile);

List<AppNavGroup> desktopNavGroups(AppLocalizations l10n) =>
    navGroupsForPlatform(AppPlatform.desktop, l10n: l10n);

List<AppNavGroup> mobileNavGroups(AppLocalizations l10n) =>
    navGroupsForPlatform(AppPlatform.mobile, l10n: l10n);

class _NavSeed {
  const _NavSeed({
    required this.id,
    required this.label,
    required this.icon,
    required this.items,
    this.section,
  });

  final String id;
  final _NavTextResolver label;
  final IconData icon;
  final List<_NavItemSeed> items;

  /// 侧边栏分区标题；`null` 表示该组前不渲染分区标题。
  final _NavTextResolver? section;
}

class _NavItemSeed {
  const _NavItemSeed({
    required this.slug,
    required this.label,
    required this.icon,
    required this.description,
    this.activeIcon,
  });

  final String slug;
  final _NavTextResolver label;
  final IconData icon;
  final _NavTextResolver description;

  /// 选中态使用的实心图标；`null` 时回退到 [icon]。
  final IconData? activeIcon;
}
