import 'package:flutter/material.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/actors/presentation/pages/desktop/actors_page.dart';
import 'package:sakuramedia/features/activity/presentation/pages/desktop/activity_page.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actors_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/configuration_page.dart';
import 'package:sakuramedia/features/discovery/presentation/desktop_discover_page.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/pages/desktop/hot_reviews_page.dart';
import 'package:sakuramedia/features/media/presentation/pages/desktop/media_management_page.dart';
import 'package:sakuramedia/features/media_import/presentation/pages/desktop/media_import_page.dart';
import 'package:sakuramedia/features/activity/presentation/pages/desktop/notifications_page.dart';
import 'package:sakuramedia/features/moments/presentation/pages/desktop/moments_page.dart';
import 'package:sakuramedia/features/tags/presentation/pages/desktop/tags_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movies_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/desktop/overview_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/overview_skeleton_page.dart';
import 'package:sakuramedia/features/clips/presentation/pages/desktop/clips_page.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/desktop/playlists_page.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/desktop/rankings_page.dart';
import 'package:sakuramedia/features/subscriptions/presentation/pages/desktop/movie_subscriptions_page.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/mobile/rankings_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_list_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/pornbox_page.dart';
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
  _NavSeed(
    id: 'pornbox',
    label: 'PornBox',
    icon: Icons.video_library_outlined,
    items: [
      _NavItemSeed(
        slug: 'pornbox',
        label: 'PornBox',
        icon: Icons.video_library_outlined,
        description: '移动端 PornBox 视频列表、合集与播放入口。',
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
    id: 'discover',
    label: '发现',
    icon: Icons.travel_explore_outlined,
    section: '浏览',
    items: [
      _NavItemSeed(
        slug: 'library/discover',
        label: '发现',
        icon: Icons.travel_explore_outlined,
        description: '每日推荐影片与推荐时刻的统一发现入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'movies',
    label: '影片',
    icon: Icons.movie_creation_outlined,
    section: '浏览',
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
    section: '浏览',
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
    id: 'tags',
    label: '标签',
    icon: Icons.sell_outlined,
    section: '浏览',
    items: [
      _NavItemSeed(
        slug: 'library/tags',
        label: '标签',
        icon: Icons.sell_outlined,
        description: '按标签多选组合筛选影片的统一入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'moments',
    label: '时刻',
    icon: Icons.auto_awesome_motion_outlined,
    section: '浏览',
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
    id: 'clips',
    label: '切片',
    icon: Icons.content_cut_outlined,
    section: '浏览',
    items: [
      _NavItemSeed(
        slug: 'library/clips',
        label: '切片',
        icon: Icons.content_cut_outlined,
        description: '圈选生成的切片与切片合集的统一入口：浏览、悬停预览、加入合集与连播。',
      ),
    ],
  ),
  _NavSeed(
    id: 'playlists',
    label: '播放列表',
    icon: Icons.playlist_play_outlined,
    section: '浏览',
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
    id: 'videos',
    label: 'PornBox',
    icon: Icons.video_library_outlined,
    section: '浏览',
    items: [
      _NavItemSeed(
        slug: 'library/videos',
        label: 'PornBox',
        icon: Icons.video_library_outlined,
        description: 'PornBox 视频的列表、合集、详情与播放统一入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'rankings',
    label: '排行榜',
    icon: Icons.local_fire_department_outlined,
    section: '浏览',
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
    section: '浏览',
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
    id: 'media',
    label: '媒体管理',
    icon: Icons.video_settings_outlined,
    section: '管理',
    items: [
      _NavItemSeed(
        slug: 'system/media',
        label: '媒体管理',
        icon: Icons.video_settings_outlined,
        description: '媒体文件浏览、失效巡检与秒传批次的统一入口。',
      ),
    ],
  ),
  _NavSeed(
    id: 'media-import',
    label: '资源导入',
    icon: Icons.drive_folder_upload_outlined,
    section: '管理',
    items: [
      _NavItemSeed(
        slug: 'system/media-import',
        label: '资源导入',
        icon: Icons.drive_folder_upload_outlined,
        description: '导入 JAV、PornBox 影片与 JAV 字幕，并在任务中心查看进度和结果。',
      ),
    ],
  ),
  _NavSeed(
    id: 'activity',
    label: '任务中心',
    icon: Icons.bolt_outlined,
    section: '管理',
    items: [
      _NavItemSeed(
        slug: 'system/activity',
        label: '任务中心',
        icon: Icons.bolt_outlined,
        description: '后台任务、元数据任务与下载任务的统一入口，所有操作回执的落点。',
      ),
    ],
  ),
  _NavSeed(
    id: 'movie-subscriptions',
    label: '订阅管理',
    icon: Icons.bookmark_added_outlined,
    section: '管理',
    items: [
      _NavItemSeed(
        slug: 'system/movie-subscriptions',
        label: '订阅管理',
        icon: Icons.bookmark_added_outlined,
        description: '订阅影片的资源查询进展：缺资源、已放弃、查询出错的集中处理台。',
      ),
    ],
  ),
  _NavSeed(
    id: 'notifications',
    label: '通知',
    icon: Icons.notifications_none_outlined,
    section: '管理',
    items: [
      _NavItemSeed(
        slug: 'system/notifications',
        label: '通知',
        icon: Icons.notifications_none_outlined,
        description: '后台通知消息中心，展示即自动已读。',
      ),
    ],
  ),
  _NavSeed(
    id: 'configuration',
    label: '系统设置',
    icon: Icons.settings_suggest_outlined,
    section: '管理',
    items: [
      _NavItemSeed(
        slug: 'system/configuration',
        label: '系统设置',
        icon: Icons.settings_suggest_outlined,
        description: '媒体库、下载器、索引器、账号安全等系统配置的统一入口。',
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
      desktopClipsPath: (_) => const DesktopClipsPage(),
      desktopVideosPath: (_) => const DesktopVideoListPage(),
      desktopRankingsPath: (_) => const DesktopRankingsPage(),
      desktopHotReviewsPath: (_) => const DesktopHotReviewsPage(),
      desktopActivityPath: (_) => const DesktopActivityPage(),
      desktopMediaPath: (_) => const DesktopMediaManagementPage(),
      desktopNotificationsPath: (_) => const DesktopNotificationsPage(),
      desktopConfigurationPath: (_) => const DesktopConfigurationPage(),
      desktopMediaImportPath: (_) => const DesktopMediaImportPage(),
      desktopMovieSubscriptionsPath:
          (_) => const DesktopMovieSubscriptionsPage(),
    };

final Map<String, WidgetBuilder> _mobileRouteBuilders = <String, WidgetBuilder>{
  mobileOverviewPath: (_) => const MobileOverviewSkeletonPage(),
  mobileMoviesPath: (_) => const MobileMoviesPage(),
  mobileActorsPath: (_) => const MobileActorsPage(),
  mobileRankingsPath: (_) => const MobileRankingsPage(),
  mobilePornboxPath: (_) => const MobilePornboxPage(),
};

List<AppNavGroup> navGroupsForPlatform(AppPlatform platform) {
  final prefix = switch (platform) {
    AppPlatform.desktop => '/desktop',
    AppPlatform.mobile => '/mobile',
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
  };

  return seeds
      .map(
        (seed) => AppNavGroup(
          id: seed.id,
          label: seed.label,
          icon: seed.icon,
          isCollapsible: false,
          sectionLabel: seed.section,
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
  final routeBuilders = switch (platform) {
    AppPlatform.desktop => _desktopRouteBuilders,
    AppPlatform.mobile => _mobileRouteBuilders,
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
            builder: (context) => routeBuilders[item.path]!(context),
          ),
        ),
      )
      .toList(growable: false);
}

List<AppRouteSpec> get desktopRouteSpecs =>
    routeSpecsForPlatform(AppPlatform.desktop);
List<AppRouteSpec> get mobileRouteSpecs =>
    routeSpecsForPlatform(AppPlatform.mobile);

List<AppNavGroup> get desktopNavGroups =>
    navGroupsForPlatform(AppPlatform.desktop);
List<AppNavGroup> get mobileNavGroups =>
    navGroupsForPlatform(AppPlatform.mobile);

class _NavSeed {
  const _NavSeed({
    required this.id,
    required this.label,
    required this.icon,
    required this.items,
    this.section,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<_NavItemSeed> items;

  /// 侧边栏分区标题；`null` 表示该组前不渲染分区标题。
  final String? section;
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
