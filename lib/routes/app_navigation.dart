import 'package:flutter/material.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/actors/presentation/desktop_actors_page.dart';
import 'package:sakuramedia/features/activity/presentation/desktop_activity_page.dart';
import 'package:sakuramedia/features/actors/presentation/mobile_actors_page.dart';
import 'package:sakuramedia/features/configuration/presentation/desktop_configuration_page.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/desktop_hot_reviews_page.dart';
import 'package:sakuramedia/features/moments/presentation/desktop_moments_page.dart';
import 'package:sakuramedia/features/subscriptions/presentation/desktop_follow_page.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/mobile_movies_page.dart';
import 'package:sakuramedia/features/overview/presentation/desktop_overview_page.dart';
import 'package:sakuramedia/features/overview/presentation/mobile_overview_skeleton_page.dart';
import 'package:sakuramedia/features/playlists/presentation/desktop_playlists_page.dart';
import 'package:sakuramedia/features/rankings/presentation/desktop_rankings_page.dart';
import 'package:sakuramedia/features/rankings/presentation/mobile_rankings_page.dart';
import 'package:sakuramedia/features/workbench/workbench_placeholder_page.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';

export 'app_route_paths.dart';

const List<_NavSeed> _mobileNavSeeds = [
  _NavSeed(
    id: 'overview',
    label: '概览',
    icon: Icons.pix_outlined,
    items: [
      _NavItemSeed(
        slug: 'overview',
        label: '概览',
        icon: Icons.pix_outlined,
        description: '移动端首页骨架与后续动态入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'movies',
    label: '影片',
    icon: Icons.movie_outlined,
    items: [
      _NavItemSeed(
        slug: 'library/movies',
        label: '影片',
        icon: Icons.movie_outlined,
        description: '移动端影片列表与后续详情入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'actors',
    label: '女优',
    icon: Icons.face_4_outlined,
    items: [
      _NavItemSeed(
        slug: 'library/actors',
        label: '女优',
        icon: Icons.face_4_outlined,
        description: '移动端女优列表与后续详情入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'rankings',
    label: '榜单',
    icon: Icons.local_fire_department_outlined,
    items: [
      _NavItemSeed(
        slug: 'rankings',
        label: '榜单',
        icon: Icons.local_fire_department_outlined,
        description: '移动端榜单骨架与后续推荐入口。',
      ),
    ],
  ),
];

const List<_NavSeed> _desktopNavSeeds = [
  _NavSeed(
    id: 'overview',
    label: '概览',
    icon: Icons.space_dashboard_outlined,
    items: [
      _NavItemSeed(
        slug: 'overview',
        label: '概览',
        icon: Icons.space_dashboard_outlined,
        description: '桌面工作台总览、待办与快捷入口的统一落点。',
      ),
    ],
  ),
  _NavSeed(
    id: 'follow',
    label: '女优上新',
    icon: Icons.favorite_border_rounded,
    items: [
      _NavItemSeed(
        slug: 'library/follow',
        label: '女优上新',
        icon: Icons.favorite_border_rounded,
        description: '所有订阅女优最新影片流的统一入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'movies',
    label: '影片',
    icon: Icons.movie_creation_outlined,
    items: [
      _NavItemSeed(
        slug: 'library/movies',
        label: '影片',
        icon: Icons.movie_creation_outlined,
        description: '影片资料、筛选面板与详情浏览的统一入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'actors',
    label: '女优',
    icon: Icons.face_retouching_natural_outlined,
    items: [
      _NavItemSeed(
        slug: 'library/actors',
        label: '女优',
        icon: Icons.face_retouching_natural_outlined,
        description: '演员资料、筛选面板与后续详情工作流的统一入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'moments',
    label: '时刻',
    icon: Icons.auto_awesome_motion_outlined,
    items: [
      _NavItemSeed(
        slug: 'library/moments',
        label: '时刻',
        icon: Icons.auto_awesome_motion_outlined,
        description: '全局时刻列表、预览和快速跳播的统一入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'playlists',
    label: '播放列表',
    icon: Icons.playlist_play_outlined,
    items: [
      _NavItemSeed(
        slug: 'library/playlists',
        label: '播放列表',
        icon: Icons.playlist_play_outlined,
        description: '播放列表浏览、维护与影片归档的统一入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'rankings',
    label: '排行榜',
    icon: Icons.local_fire_department_outlined,
    items: [
      _NavItemSeed(
        slug: 'library/rankings',
        label: '排行榜',
        icon: Icons.local_fire_department_outlined,
        description: '来源榜单聚合、周期切换与影片热榜浏览入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'hot-reviews',
    label: '热评',
    icon: Icons.rate_review_outlined,
    items: [
      _NavItemSeed(
        slug: 'library/hot-reviews',
        label: '热评',
        icon: Icons.rate_review_outlined,
        description: '本地热评快照浏览、周期切换与评论洞察入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'activity',
    label: '活动中心',
    icon: Icons.notifications_active_outlined,
    items: [
      _NavItemSeed(
        slug: 'system/activity',
        label: '活动中心',
        icon: Icons.notifications_active_outlined,
        description: '后台通知、任务状态与在线活动流的统一入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'configuration',
    label: '配置管理',
    icon: Icons.settings_suggest_outlined,
    items: [
      _NavItemSeed(
        slug: 'system/configuration',
        label: '配置管理',
        icon: Icons.settings_suggest_outlined,
        description: '下载器、索引器等系统配置的统一管理入口。',
      ),
    ],
  ),
];

List<AppNavGroup> navGroupsForPlatform(AppPlatform platform) {
  final prefix = switch (platform) {
    AppPlatform.desktop => '/desktop',
    AppPlatform.mobile => '/mobile',
    AppPlatform.web => '/desktop',
  };

  AppNavItem item({
    required String slug,
    required String label,
    required IconData icon,
    required String description,
  }) {
    return AppNavItem(
      name: '${platform.name}-$slug',
      label: label,
      path: '$prefix/$slug',
      icon: icon,
      description: description,
    );
  }

  final seeds = switch (platform) {
    AppPlatform.desktop => _desktopNavSeeds,
    AppPlatform.mobile => _mobileNavSeeds,
    AppPlatform.web => _desktopNavSeeds,
  };

  return seeds
      .map(
        (seed) => AppNavGroup(
          id: seed.id,
          label: seed.label,
          icon: seed.icon,
          isCollapsible: false,
          items: seed.items
              .map(
                (seedItem) => item(
                  slug: seedItem.slug,
                  label: seedItem.label,
                  icon: seedItem.icon,
                  description: seedItem.description,
                ),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
}

List<AppRouteSpec> routeSpecsForPlatform(AppPlatform platform) {
  final useDesktopExperience =
      platform == AppPlatform.desktop || platform == AppPlatform.web;
  final platformLabel = switch (platform) {
    AppPlatform.desktop => '桌面端',
    AppPlatform.mobile => '移动端',
    AppPlatform.web => 'Web 端',
  };

  return navGroupsForPlatform(platform)
      .expand(
        (group) => group.items.map(
          (item) => AppRouteSpec(
            platform: platform,
            name: item.name,
            path: item.path,
            title: item.label,
            description: item.description,
            groupId: group.id,
            layout: AppShellLayout.standard,
            builder:
                (context) =>
                    useDesktopExperience && item.path == desktopOverviewPath
                        ? const DesktopOverviewPage()
                        : useDesktopExperience && item.path == desktopFollowPath
                        ? const DesktopFollowPage()
                        : platform == AppPlatform.mobile &&
                            item.path == mobileOverviewPath
                        ? const MobileOverviewSkeletonPage()
                        : useDesktopExperience && item.path == desktopMoviesPath
                        ? const DesktopMoviesPage()
                        : platform == AppPlatform.mobile &&
                            item.path == mobileMoviesPath
                        ? const MobileMoviesPage()
                        : useDesktopExperience && item.path == desktopActorsPath
                        ? const DesktopActorsPage()
                        : platform == AppPlatform.mobile &&
                            item.path == mobileActorsPath
                        ? const MobileActorsPage()
                        : platform == AppPlatform.mobile &&
                            item.path == mobileRankingsPath
                        ? const MobileRankingsPage()
                        : useDesktopExperience &&
                            item.path == desktopMomentsPath
                        ? const DesktopMomentsPage()
                        : useDesktopExperience &&
                            item.path == desktopPlaylistsPath
                        ? const DesktopPlaylistsPage()
                        : useDesktopExperience &&
                            item.path == desktopRankingsPath
                        ? const DesktopRankingsPage()
                        : useDesktopExperience &&
                            item.path == desktopHotReviewsPath
                        ? const DesktopHotReviewsPage()
                        : useDesktopExperience &&
                            item.path == desktopActivityPath
                        ? const DesktopActivityPage()
                        : useDesktopExperience &&
                            item.path == desktopConfigurationPath
                        ? const DesktopConfigurationPage()
                        : WorkbenchPlaceholderPage(
                          platform: platform,
                          title: item.label,
                          description: item.description,
                          routePath: item.path,
                          eyebrow:
                              item.path.endsWith('/overview')
                                  ? '$platformLabel工作台骨架'
                                  : platformLabel,
                          showUiKitShowcase: item.path.endsWith('/ui-kit'),
                        ),
          ),
        ),
      )
      .toList(growable: false);
}

List<AppRouteSpec> get desktopRouteSpecs =>
    routeSpecsForPlatform(AppPlatform.desktop);
List<AppRouteSpec> get mobileRouteSpecs =>
    routeSpecsForPlatform(AppPlatform.mobile);
List<AppRouteSpec> get webRouteSpecs => routeSpecsForPlatform(AppPlatform.web);

List<AppNavGroup> get desktopNavGroups =>
    navGroupsForPlatform(AppPlatform.desktop);
List<AppNavGroup> get mobileNavGroups =>
    navGroupsForPlatform(AppPlatform.mobile);
List<AppNavGroup> get webNavGroups => navGroupsForPlatform(AppPlatform.web);

class _NavSeed {
  const _NavSeed({
    required this.id,
    required this.label,
    required this.icon,
    required this.items,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<_NavItemSeed> items;
}

class _NavItemSeed {
  const _NavItemSeed({
    required this.slug,
    required this.label,
    required this.icon,
    required this.description,
  });

  final String slug;
  final String label;
  final IconData icon;
  final String description;
}
