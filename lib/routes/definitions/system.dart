import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/account/presentation/pages/mobile/account_security_page.dart';
import 'package:sakuramedia/features/activity/presentation/pages/desktop/activity_page.dart';
import 'package:sakuramedia/features/activity/presentation/pages/desktop/notifications_page.dart';
import 'package:sakuramedia/features/activity/presentation/pages/mobile/activity_page.dart';
import 'package:sakuramedia/features/activity/presentation/pages/mobile/notifications_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/configuration_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/appearance_settings_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_download_selection_policy_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_system_maintenance_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/downloaders_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/indexers_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/media_libraries_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/media_tags_page.dart';
import 'package:sakuramedia/features/downloads/presentation/pages/desktop/download_tasks_page.dart';
import 'package:sakuramedia/features/downloads/presentation/pages/mobile/download_tasks_page.dart';
import 'package:sakuramedia/features/external_player/presentation/pages/mobile/external_player_settings_page.dart';
import 'package:sakuramedia/features/media/presentation/pages/desktop/media_management_page.dart';
import 'package:sakuramedia/features/media/presentation/pages/mobile/media_management_page.dart';
import 'package:sakuramedia/features/media_import/presentation/pages/shared/media_import_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/system_overview_page.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/mobile/mobile_plugin_market_page.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/mobile/mobile_plugins_page.dart';
import 'package:sakuramedia/features/subscriptions/presentation/pages/desktop/movie_subscriptions_page.dart';
import 'package:sakuramedia/features/subscriptions/presentation/pages/mobile/movie_subscriptions_page.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/pages/desktop/system_diagnostics_page.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/definitions/query_params.dart';

final AppRouteDefinition desktopActivityRoute = AppRouteDefinition(
  id: AppRouteId.desktopActivity,
  name: 'desktop-activity',
  platform: AppPlatform.desktop,
  path: desktopActivityPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopActivityPage(),
  title: (l10n, [_]) => l10n.routeTaskCenterTitle,
  nav: AppNavDestination(
    groupId: 'activity',
    order: 17,
    icon: Icons.bolt_outlined,
    description: (l10n) => l10n.routeNavTaskCenterDescription,
    sectionId: 'manage',
  ),
);

final AppRouteDefinition desktopDownloadTasksRoute = AppRouteDefinition(
  id: AppRouteId.desktopDownloadTasks,
  name: 'desktop-download-tasks',
  platform: AppPlatform.desktop,
  path: desktopDownloadTasksPath,
  scope: AppRouteScope.branchRoot,
  queryParameters: downloadTasksQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(downloadTasksQueryParameters, state);
    return DesktopDownloadTasksPage(
      initialDownloadMovieNumber: query.string('downloadMovieNumber'),
    );
  },
  title: (l10n, [_]) => l10n.routeDownloadTasksTitle,
  nav: AppNavDestination(
    groupId: 'download-tasks',
    order: 16,
    icon: Icons.download_for_offline_outlined,
    description: (l10n) => l10n.routeNavDownloadTasksDescription,
    sectionId: 'manage',
  ),
);

final AppRouteDefinition desktopMediaRoute = AppRouteDefinition(
  id: AppRouteId.desktopMedia,
  name: 'desktop-media',
  platform: AppPlatform.desktop,
  path: desktopMediaPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopMediaManagementPage(),
  title: (l10n, [_]) => l10n.routeMediaManagementTitle,
  nav: AppNavDestination(
    groupId: 'media',
    order: 14,
    icon: Icons.video_settings_outlined,
    description: (l10n) => l10n.routeNavMediaManagementDescription,
    sectionId: 'manage',
  ),
);

final AppRouteDefinition desktopNotificationsRoute = AppRouteDefinition(
  id: AppRouteId.desktopNotifications,
  name: 'desktop-notifications',
  platform: AppPlatform.desktop,
  path: desktopNotificationsPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopNotificationsPage(),
  title: (l10n, [_]) => l10n.routeNotificationsTitle,
  nav: AppNavDestination(
    groupId: 'notifications',
    order: 19,
    icon: Icons.notifications_none_outlined,
    description: (l10n) => l10n.routeNavNotificationsDescription,
    sectionId: 'manage',
  ),
);

final AppRouteDefinition desktopConfigurationRoute = AppRouteDefinition(
  id: AppRouteId.desktopConfiguration,
  name: 'desktop-configuration',
  platform: AppPlatform.desktop,
  path: desktopConfigurationPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopConfigurationPage(),
  title: (l10n, [_]) => l10n.routeConfigurationTitle,
  nav: AppNavDestination(
    groupId: 'configuration',
    order: 20,
    icon: Icons.settings_suggest_outlined,
    description: (l10n) => l10n.routeNavConfigurationDescription,
    sectionId: 'manage',
  ),
);

final AppRouteDefinition desktopMediaImportRoute = AppRouteDefinition(
  id: AppRouteId.desktopMediaImport,
  name: 'desktop-media-import',
  platform: AppPlatform.desktop,
  path: desktopMediaImportPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const MediaImportPage(),
  title: (l10n, [_]) => l10n.routeMediaImportTitle,
  nav: AppNavDestination(
    groupId: 'media-import',
    order: 15,
    icon: Icons.drive_folder_upload_outlined,
    description: (l10n) => l10n.routeNavMediaImportDescription,
    sectionId: 'manage',
  ),
);

final AppRouteDefinition desktopMovieSubscriptionsRoute = AppRouteDefinition(
  id: AppRouteId.desktopMovieSubscriptions,
  name: 'desktop-movie-subscriptions',
  platform: AppPlatform.desktop,
  path: desktopMovieSubscriptionsPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopMovieSubscriptionsPage(),
  title: (l10n, [_]) => l10n.routeSubscriptionManagementTitle,
  nav: AppNavDestination(
    groupId: 'movie-subscriptions',
    order: 18,
    icon: Icons.bookmark_added_outlined,
    description: (l10n) => l10n.routeNavSubscriptionManagementDescription,
    sectionId: 'manage',
  ),
);

final AppRouteDefinition desktopSystemDiagnosticsRoute = AppRouteDefinition(
  id: AppRouteId.desktopSystemDiagnostics,
  name: 'desktop-system-diagnostics',
  platform: AppPlatform.desktop,
  path: desktopSystemDiagnosticsPath,
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) => const DesktopSystemDiagnosticsPage(),
  title: (l10n, [_]) => l10n.systemDiagnosticsComponentTitle,
  backTarget: (state) => desktopOverviewPath,
);

final AppRouteDefinition mobileSystemOverviewRoute = AppRouteDefinition(
  id: AppRouteId.mobileSystemOverview,
  name: 'mobile-system-overview',
  platform: AppPlatform.mobile,
  path: mobileSystemOverviewPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  pageBuilder: (context, state) => const MobileSystemOverviewPage(),
  title: (l10n, [_]) => l10n.routeOverviewTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileMediaImportRoute = AppRouteDefinition(
  id: AppRouteId.mobileMediaImport,
  name: 'mobile-media-import',
  platform: AppPlatform.mobile,
  path: mobileMediaImportPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  pageBuilder: (context, state) => const MediaImportPage(),
  title: (l10n, [_]) => l10n.routeMediaImportTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileActivityRoute = AppRouteDefinition(
  id: AppRouteId.mobileActivity,
  name: 'mobile-activity',
  platform: AppPlatform.mobile,
  path: mobileActivityPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileActivityPage(),
  title: (l10n, [_]) => l10n.routeTaskCenterTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileDownloadTasksRoute = AppRouteDefinition(
  id: AppRouteId.mobileDownloadTasks,
  name: 'mobile-download-tasks',
  platform: AppPlatform.mobile,
  path: mobileDownloadTasksPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  queryParameters: downloadTasksQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(downloadTasksQueryParameters, state);
    return MobileDownloadTasksPage(
      initialDownloadMovieNumber: query.string('downloadMovieNumber'),
    );
  },
  title: (l10n, [_]) => l10n.routeDownloadTasksTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileNotificationsRoute = AppRouteDefinition(
  id: AppRouteId.mobileNotifications,
  name: 'mobile-notifications',
  platform: AppPlatform.mobile,
  path: mobileNotificationsPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileNotificationsPage(),
  title: (l10n, [_]) => l10n.routeMessagesTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileMediaManagementRoute = AppRouteDefinition(
  id: AppRouteId.mobileMediaManagement,
  name: 'mobile-media-management',
  platform: AppPlatform.mobile,
  path: mobileMediaManagementPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileMediaManagementPage(),
  title: (l10n, [_]) => l10n.routeMediaManagementTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileMovieSubscriptionsRoute = AppRouteDefinition(
  id: AppRouteId.mobileMovieSubscriptions,
  name: 'mobile-movie-subscriptions',
  platform: AppPlatform.mobile,
  path: mobileMovieSubscriptionsPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileMovieSubscriptionsPage(),
  title: (l10n, [_]) => l10n.routeSubscriptionManagementTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileSettingsMediaLibrariesRoute = AppRouteDefinition(
  id: AppRouteId.mobileSettingsMediaLibraries,
  name: 'mobile-settings-media-libraries',
  platform: AppPlatform.mobile,
  path: mobileSettingsMediaLibrariesPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  pageBuilder: (context, state) => const MediaLibrariesPage(mobile: true),
  title: (l10n, [_]) => l10n.configTabMediaLibraries,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileSettingsMediaTagsRoute = AppRouteDefinition(
  id: AppRouteId.mobileSettingsMediaTags,
  name: 'mobile-settings-media-tags',
  platform: AppPlatform.mobile,
  path: mobileSettingsMediaTagsPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  pageBuilder: (context, state) => const MediaTagsPage(mobile: true),
  title: (l10n, [_]) => l10n.configTabMediaTags,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileSettingsPluginsRoute = AppRouteDefinition(
  id: AppRouteId.mobileSettingsPlugins,
  name: 'mobile-settings-plugins',
  platform: AppPlatform.mobile,
  path: mobileSettingsPluginsPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  pageBuilder: (context, state) => const MobilePluginsPage(),
  title: (l10n, [_]) => l10n.configTabPlugins,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileSettingsPluginMarketRoute = AppRouteDefinition(
  id: AppRouteId.mobileSettingsPluginMarket,
  name: 'mobile-settings-plugin-market',
  platform: AppPlatform.mobile,
  path: mobileSettingsPluginMarketPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  pageBuilder: (context, state) => const MobilePluginMarketPage(),
  title: (l10n, [_]) => l10n.pluginMarketTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileSettingsDownloadersRoute = AppRouteDefinition(
  id: AppRouteId.mobileSettingsDownloaders,
  name: 'mobile-settings-downloaders',
  platform: AppPlatform.mobile,
  path: mobileSettingsDownloadersPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  pageBuilder: (context, state) => const DownloadersPage(mobile: true),
  title: (l10n, [_]) => l10n.configTabDownloadClients,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileSettingsIndexersRoute = AppRouteDefinition(
  id: AppRouteId.mobileSettingsIndexers,
  name: 'mobile-settings-indexers',
  platform: AppPlatform.mobile,
  path: mobileSettingsIndexersPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  pageBuilder: (context, state) => const IndexersPage(mobile: true),
  title: (l10n, [_]) => l10n.configTabIndexers,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileSettingsDownloadSelectionRoute =
    AppRouteDefinition(
      id: AppRouteId.mobileSettingsDownloadSelection,
      name: 'mobile-settings-download-selection',
      platform: AppPlatform.mobile,
      path: mobileSettingsDownloadSelectionPath,
      scope: AppRouteScope.outsideShell,
      transition: AppRouteTransition.cupertino,
      subpageChrome: const AppSubpageChrome(autoHideAppBar: false),
      pageBuilder: (context, state) =>
          const MobileDownloadSelectionPolicyPage(),
      title: (l10n, [_]) => l10n.configTabDownloadSelection,
      backTarget: (state) => mobileOverviewPath,
    );

final AppRouteDefinition mobileSettingsSystemMaintenanceRoute =
    AppRouteDefinition(
      id: AppRouteId.mobileSettingsSystemMaintenance,
      name: 'mobile-settings-system-maintenance',
      platform: AppPlatform.mobile,
      path: mobileSettingsSystemMaintenancePath,
      scope: AppRouteScope.outsideShell,
      transition: AppRouteTransition.cupertino,
      subpageChrome: const AppSubpageChrome(),
      pageBuilder: (context, state) => const MobileSystemMaintenancePage(),
      title: (l10n, [_]) => l10n.configTabSystemMaintenance,
      backTarget: (state) => mobileOverviewPath,
    );

final AppRouteDefinition mobileSettingsExternalPlayerRoute = AppRouteDefinition(
  id: AppRouteId.mobileSettingsExternalPlayer,
  name: 'mobile-settings-external-player',
  platform: AppPlatform.mobile,
  path: mobileSettingsExternalPlayerPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  pageBuilder: (context, state) => const MobileExternalPlayerSettingsPage(),
  title: (l10n, [_]) => l10n.configTabExternalPlayer,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileSettingsAppearanceRoute = AppRouteDefinition(
  id: AppRouteId.mobileSettingsAppearance,
  name: 'mobile-settings-appearance',
  platform: AppPlatform.mobile,
  path: mobileSettingsAppearancePath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  pageBuilder: (context, state) => const MobileAppearanceSettingsPage(),
  title: (l10n, [_]) => l10n.configTabAppearance,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileSettingsAccountSecurityRoute =
    AppRouteDefinition(
      id: AppRouteId.mobileSettingsAccountSecurity,
      name: 'mobile-settings-account-security',
      platform: AppPlatform.mobile,
      path: mobileSettingsAccountSecurityPath,
      scope: AppRouteScope.outsideShell,
      transition: AppRouteTransition.cupertino,
      subpageChrome: const AppSubpageChrome(),
      pageBuilder: (context, state) => const MobileAccountSecurityPage(),
      title: (l10n, [_]) => l10n.configTabAccountSecurity,
      backTarget: (state) => mobileOverviewPath,
    );
