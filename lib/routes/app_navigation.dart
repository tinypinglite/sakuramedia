import 'package:flutter/material.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/actors/presentation/desktop_actors_page.dart';
import 'package:sakuramedia/features/configuration/presentation/desktop_configuration_page.dart';
import 'package:sakuramedia/features/moments/presentation/desktop_moments_page.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movies_page.dart';
import 'package:sakuramedia/features/overview/presentation/desktop_overview_page.dart';
import 'package:sakuramedia/features/overview/presentation/mobile_overview_skeleton_page.dart';
import 'package:sakuramedia/features/playlists/presentation/desktop_playlists_page.dart';
import 'package:sakuramedia/features/workbench/workbench_placeholder_page.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';

const String desktopOverviewPath = '/desktop/overview';
const String desktopSearchPath = '/desktop/search';
const String desktopImageSearchPath = '/desktop/search/image';
const String desktopMoviesPath = '/desktop/library/movies';
const String desktopActorsPath = '/desktop/library/actors';
const String desktopMomentsPath = '/desktop/library/moments';
const String desktopPlaylistsPath = '/desktop/library/playlists';
const String desktopConfigurationPath = '/desktop/system/configuration';
const String mobileOverviewPath = '/mobile/overview';
const String mobileMoviesPath = '/mobile/library/movies';
const String mobileActorsPath = '/mobile/library/actors';
const String mobileRankingsPath = '/mobile/rankings';
const String webOverviewPath = '/web/overview';
const String loginPath = '/login';

String buildDesktopSearchRoutePath(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return desktopSearchPath;
  }
  return '$desktopSearchPath/${Uri.encodeComponent(trimmed)}';
}

String buildDesktopMoviePlayerRoutePath(
  String movieNumber, {
  int? mediaId,
  int? positionSeconds,
}) {
  final queryParameters = <String, String>{};
  if (mediaId != null) {
    queryParameters['mediaId'] = '$mediaId';
  }
  if (positionSeconds != null) {
    queryParameters['positionSeconds'] = '$positionSeconds';
  }
  final path = Uri(
    path: '/desktop/library/movies/$movieNumber/player',
    queryParameters: queryParameters.isEmpty ? null : queryParameters,
  );
  return path.toString();
}

String overviewPathForPlatform(AppPlatform platform) {
  switch (platform) {
    case AppPlatform.desktop:
      return desktopOverviewPath;
    case AppPlatform.mobile:
      return mobileOverviewPath;
    case AppPlatform.web:
      return webOverviewPath;
  }
}

const List<_NavSeed> _webNavSeeds = [
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
    id: 'library',
    label: '媒体库',
    icon: Icons.video_library_outlined,
    items: [
      _NavItemSeed(
        slug: 'library/movies',
        label: '影片库',
        icon: Icons.movie_creation_outlined,
        description: '影片资料、筛选入口与后续详情工作流的承载区域。',
      ),
      _NavItemSeed(
        slug: 'library/actors',
        label: '女优库',
        icon: Icons.face_retouching_natural_outlined,
        description: '演员资料、关联影片与标签体系的管理入口。',
      ),
      _NavItemSeed(
        slug: 'library/tags',
        label: '标签与分类',
        icon: Icons.sell_outlined,
        description: '标签、系列、厂牌等分类体系的统一管理面板。',
      ),
    ],
  ),
  _NavSeed(
    id: 'resources',
    label: '资源管理',
    icon: Icons.inventory_2_outlined,
    items: [
      _NavItemSeed(
        slug: 'resources/downloads',
        label: '下载任务',
        icon: Icons.download_for_offline_outlined,
        description: '下载任务、队列状态与异常处理的后续入口。',
      ),
      _NavItemSeed(
        slug: 'resources/files',
        label: '文件整理',
        icon: Icons.folder_open_outlined,
        description: '文件归档、整理规则与扫描任务的占位页面。',
      ),
    ],
  ),
  _NavSeed(
    id: 'system',
    label: '系统',
    icon: Icons.settings_suggest_outlined,
    items: [
      _NavItemSeed(
        slug: 'system/settings',
        label: '应用设置',
        icon: Icons.tune_outlined,
        description: '应用配置、偏好设置和后续系统能力的统一入口。',
      ),
      _NavItemSeed(
        slug: 'system/ui-kit',
        label: 'UI 规范',
        icon: Icons.palette_outlined,
        description: '项目专属设计令牌、组件基线与布局规范预览。',
      ),
    ],
  ),
];

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
    AppPlatform.web => '/web',
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
    AppPlatform.web => _webNavSeeds,
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
                    platform == AppPlatform.desktop &&
                            item.path == desktopOverviewPath
                        ? const DesktopOverviewPage()
                        : platform == AppPlatform.mobile &&
                            item.path == mobileOverviewPath
                        ? const MobileOverviewSkeletonPage()
                        : platform == AppPlatform.desktop &&
                            item.path == desktopMoviesPath
                        ? const DesktopMoviesPage()
                        : platform == AppPlatform.desktop &&
                            item.path == desktopActorsPath
                        ? const DesktopActorsPage()
                        : platform == AppPlatform.desktop &&
                            item.path == desktopMomentsPath
                        ? const DesktopMomentsPage()
                        : platform == AppPlatform.desktop &&
                            item.path == desktopPlaylistsPath
                        ? const DesktopPlaylistsPage()
                        : platform == AppPlatform.desktop &&
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
