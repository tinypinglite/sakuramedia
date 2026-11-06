import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_registry.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/routes/app_route_target.dart';

export 'app_route_paths.dart';

class AppNavSectionDefinition {
  const AppNavSectionDefinition({
    required this.id,
    required this.order,
    required this.label,
  });

  final String id;
  final int order;
  final AppTextResolver label;
}

const List<AppNavSectionDefinition>
_desktopSections = <AppNavSectionDefinition>[
  AppNavSectionDefinition(id: 'browse', order: 0, label: _browseSectionLabel),
  AppNavSectionDefinition(id: 'manage', order: 1, label: _manageSectionLabel),
];

String _browseSectionLabel(AppLocalizations l10n) =>
    l10n.routeNavBrowseSectionLabel;

String _manageSectionLabel(AppLocalizations l10n) =>
    l10n.routeNavManageSectionLabel;

List<AppNavItem> desktopNavItems(AppLocalizations l10n) =>
    _navItems(AppPlatform.desktop, l10n);

List<AppNavItem> mobileNavItems(AppLocalizations l10n) =>
    _navItems(AppPlatform.mobile, l10n);

List<AppNavItem> _navItems(AppPlatform platform, AppLocalizations l10n) {
  final definitions =
      appRoutes
          .forPlatform(platform)
          .where((definition) => definition.nav != null)
          .toList(growable: false)
        ..sort((left, right) => left.nav!.order.compareTo(right.nav!.order));

  return definitions
      .map((definition) {
        final nav = definition.nav!;
        AppNavSectionDefinition? section;
        if (platform == AppPlatform.desktop) {
          for (final value in _desktopSections) {
            if (value.id == nav.sectionId) {
              section = value;
              break;
            }
          }
        }
        final label = definition.title(l10n);
        return AppNavItem(
          routeId: definition.id,
          name: nav.groupId,
          label: label,
          path: AppRouteTarget(id: definition.id).path,
          icon: nav.icon,
          activeIcon: nav.activeIcon,
          description: nav.description(l10n),
          sectionLabel: section?.label(l10n),
        );
      })
      .toList(growable: false);
}

List<AppRouteId> get desktopPrimaryBranchOrder => appRoutes
    .scoped(AppPlatform.desktop, AppRouteScope.branchRoot)
    .map((definition) => definition.id)
    .toList(growable: false);

List<AppRouteId> get mobilePrimaryBranchOrder => appRoutes
    .scoped(AppPlatform.mobile, AppRouteScope.branchRoot)
    .map((definition) => definition.id)
    .toList(growable: false);

int get mobileOverviewBranchIndex =>
    mobilePrimaryBranchOrder.indexOf(AppRouteId.mobileOverview);

extension AppNavigation on BuildContext {
  void goPrimary(AppRouteId id) {
    final definition = appRoutes.byId(id);
    final nav = definition.nav;
    if (nav == null) {
      throw StateError('$id is not a primary navigation destination');
    }
    final target = AppRouteTarget(id: id);
    switch (nav.switchMode) {
      case AppPrimarySwitchMode.go:
        target.go(this);
      case AppPrimarySwitchMode.push:
        target.push(this);
    }
  }
}

List<AppDrawerSection> mobileDrawerSections(AppLocalizations l10n) {
  return <AppDrawerSection>[
    AppDrawerSection(
      id: 'home',
      header: l10n.shellDrawerGroupHome,
      entries: <AppDrawerEntry>[
        AppDrawerEntry(
          key: 'overview',
          routeId: AppRouteId.mobileSystemOverview,
          label: l10n.shellNavOverview,
          icon: Icons.space_dashboard_outlined,
        ),
        AppDrawerEntry(
          key: 'notifications',
          routeId: AppRouteId.mobileNotifications,
          label: l10n.shellNavNotifications,
          icon: Icons.notifications_none_rounded,
          badge: AppDrawerBadge.notifications,
        ),
      ],
    ),
    AppDrawerSection(
      id: 'content',
      header: l10n.shellDrawerGroupMyContent,
      entries: <AppDrawerEntry>[
        AppDrawerEntry(
          key: 'favorites',
          routeId: AppRouteId.mobileFavorites,
          label: l10n.shellNavFavorites,
          icon: Icons.favorite_border_rounded,
        ),
        AppDrawerEntry(
          key: 'recently-played',
          routeId: AppRouteId.mobileRecentlyPlayed,
          label: l10n.shellNavRecentlyPlayed,
          icon: Icons.play_circle_outline_rounded,
        ),
        AppDrawerEntry(
          key: 'recent-views',
          routeId: AppRouteId.mobileRecentViews,
          label: l10n.shellNavRecentViews,
          icon: Icons.visibility_outlined,
        ),
        AppDrawerEntry(
          key: 'ratings',
          routeId: AppRouteId.mobileRatedMovies,
          label: l10n.shellNavMyRatings,
          icon: Icons.star_outline_rounded,
        ),
        AppDrawerEntry(
          key: 'tags',
          routeId: AppRouteId.mobileTags,
          label: l10n.shellNavTags,
          icon: Icons.sell_outlined,
        ),
      ],
    ),
    AppDrawerSection(
      id: 'downloads-tasks',
      header: l10n.shellDrawerGroupDownloadsTasks,
      entries: <AppDrawerEntry>[
        AppDrawerEntry(
          key: 'download-tasks',
          routeId: AppRouteId.mobileDownloadTasks,
          label: l10n.shellNavDownloadTasks,
          icon: Icons.download_for_offline_outlined,
        ),
        AppDrawerEntry(
          key: 'activity',
          routeId: AppRouteId.mobileActivity,
          label: l10n.shellNavTaskCenter,
          icon: Icons.bolt_outlined,
        ),
        AppDrawerEntry(
          key: 'movie-subscriptions',
          routeId: AppRouteId.mobileMovieSubscriptions,
          label: l10n.shellNavSubscriptions,
          icon: Icons.bookmark_added_outlined,
        ),
      ],
    ),
    AppDrawerSection(
      id: 'media-connections',
      header: l10n.shellDrawerGroupMediaConnections,
      entries: <AppDrawerEntry>[
        AppDrawerEntry(
          key: 'media-management',
          routeId: AppRouteId.mobileMediaManagement,
          label: l10n.shellNavMediaManagement,
          icon: Icons.video_settings_outlined,
        ),
        AppDrawerEntry(
          key: 'media-import',
          routeId: AppRouteId.mobileMediaImport,
          label: l10n.shellNavMediaImport,
          icon: Icons.drive_folder_upload_outlined,
        ),
        AppDrawerEntry(
          key: 'media-libraries',
          routeId: AppRouteId.mobileSettingsMediaLibraries,
          label: l10n.shellNavMediaLibraries,
          icon: Icons.video_library_outlined,
        ),
        AppDrawerEntry(
          key: 'media-tags',
          routeId: AppRouteId.mobileSettingsMediaTags,
          label: l10n.shellNavMediaTags,
          icon: Icons.sell_outlined,
        ),
        AppDrawerEntry(
          key: 'downloaders',
          routeId: AppRouteId.mobileSettingsDownloaders,
          label: l10n.shellNavDownloaders,
          icon: Icons.download_outlined,
        ),
        AppDrawerEntry(
          key: 'indexers',
          routeId: AppRouteId.mobileSettingsIndexers,
          label: l10n.shellNavIndexers,
          icon: Icons.travel_explore_outlined,
        ),
        AppDrawerEntry(
          key: 'download-selection',
          routeId: AppRouteId.mobileSettingsDownloadSelection,
          label: l10n.configTabDownloadSelection,
          icon: Icons.filter_alt_outlined,
        ),
      ],
    ),
    AppDrawerSection(
      id: 'system-account',
      header: l10n.shellDrawerGroupSystemAccount,
      entries: <AppDrawerEntry>[
        AppDrawerEntry(
          key: 'plugins',
          routeId: AppRouteId.mobileSettingsPlugins,
          label: l10n.shellNavPlugins,
          icon: Icons.extension_outlined,
        ),
        AppDrawerEntry(
          key: 'system-maintenance',
          routeId: AppRouteId.mobileSettingsSystemMaintenance,
          label: l10n.shellNavSystemMaintenance,
          icon: Icons.build_outlined,
        ),
        AppDrawerEntry(
          key: 'external-player',
          routeId: AppRouteId.mobileSettingsExternalPlayer,
          label: l10n.shellNavExternalPlayer,
          icon: Icons.open_in_new_rounded,
          visible: () => defaultTargetPlatform == TargetPlatform.android,
        ),
        AppDrawerEntry(
          key: 'appearance',
          routeId: AppRouteId.mobileSettingsAppearance,
          label: l10n.shellNavAppearance,
          icon: Icons.palette_outlined,
        ),
        AppDrawerEntry(
          key: 'account-security',
          routeId: AppRouteId.mobileSettingsAccountSecurity,
          label: l10n.shellNavAccountSecurity,
          icon: Icons.security_rounded,
        ),
      ],
    ),
  ];
}
