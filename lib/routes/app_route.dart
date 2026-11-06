import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

enum AppRouteScope { outsideShell, shellLevel, branchRoot, branchChild }

enum AppRouteTransition { none, material, cupertino }

enum AppPrimarySwitchMode { go, push }

enum AppDrawerBadge { notifications }

enum AppQueryType { string, integer, boolean }

typedef AppRouteTitle =
    String Function(AppLocalizations l10n, [GoRouterState? state]);

typedef AppTextResolver = String Function(AppLocalizations l10n);

@immutable
class AppQueryParam {
  const AppQueryParam({
    required this.name,
    required this.type,
    this.alias,
    this.defaultValue,
  });

  /// Canonical query key written to outbound URLs.
  final String name;

  /// Legacy key still accepted for incoming deep links.
  final String? alias;
  final AppQueryType type;
  final Object? defaultValue;
}

@immutable
class AppSubpageChrome {
  const AppSubpageChrome({
    this.bodyPadding = AppPageInsets.compactStandard,
    this.immersive = false,
    this.glassChrome = false,
    this.autoHideAppBar = true,
  });

  final EdgeInsetsGeometry bodyPadding;
  final bool immersive;
  final bool glassChrome;
  final bool autoHideAppBar;
}

@immutable
class AppNavDestination {
  const AppNavDestination({
    required this.groupId,
    required this.order,
    required this.icon,
    required this.description,
    this.activeIcon,
    this.sectionId,
    this.switchMode = AppPrimarySwitchMode.go,
  });

  final String groupId;
  final int order;
  final IconData icon;
  final IconData? activeIcon;
  final AppTextResolver description;
  final String? sectionId;
  final AppPrimarySwitchMode switchMode;
}

@immutable
class AppRouteDefinition {
  const AppRouteDefinition({
    required this.id,
    required this.name,
    required this.platform,
    required this.path,
    required this.scope,
    required this.pageBuilder,
    required this.title,
    this.parentId,
    this.useRootNavigator = false,
    this.transition = AppRouteTransition.none,
    this.backTarget,
    this.layout = AppShellLayout.standard,
    this.showTopBar = true,
    this.subpageChrome,
    this.queryParameters = const <AppQueryParam>[],
    this.nav,
  });

  final AppRouteId id;
  final String name;
  final AppPlatform platform;

  /// Full path template shared by incoming matching and outgoing URLs.
  final String path;
  final AppRouteScope scope;
  final AppRouteId? parentId;
  final bool useRootNavigator;
  final AppRouteTransition transition;
  final Widget Function(BuildContext context, GoRouterState state) pageBuilder;
  final AppRouteTitle title;

  /// Canonical fallback when there is no navigator stack to pop.
  final String? Function(GoRouterState state)? backTarget;
  final AppShellLayout layout;
  final bool showTopBar;
  final AppSubpageChrome? subpageChrome;
  final List<AppQueryParam> queryParameters;
  final AppNavDestination? nav;
}

@immutable
class AppRouteExtra {
  const AppRouteExtra({this.fallbackPath});

  final String? fallbackPath;

  static String? fallbackPathOf(
    Object? extra, {
    required AppPlatform platform,
  }) {
    final value = switch (extra) {
      AppRouteExtra(:final fallbackPath) => fallbackPath,
      String value => value,
      _ => null,
    };
    if (value == null || value.isEmpty) {
      return null;
    }
    final prefix = platform == AppPlatform.desktop ? '/desktop/' : '/mobile/';
    return value.startsWith(prefix) ? value : null;
  }
}

/// Typed reader for query values declared by an [AppRouteDefinition].
class AppQueryValues {
  AppQueryValues(this._parameters, this._state);

  final List<AppQueryParam> _parameters;
  final GoRouterState _state;

  AppQueryParam? _parameter(String name) {
    for (final parameter in _parameters) {
      if (parameter.name == name) {
        return parameter;
      }
    }
    return null;
  }

  String? _raw(String name) {
    final parameter = _parameter(name);
    if (parameter == null) {
      return null;
    }
    final canonical = _state.uri.queryParameters[parameter.name];
    if (canonical != null && canonical.isNotEmpty) {
      return canonical;
    }
    final alias = parameter.alias;
    if (alias == null) {
      return null;
    }
    final legacy = _state.uri.queryParameters[alias];
    return legacy == null || legacy.isEmpty ? null : legacy;
  }

  String? string(String name) {
    final value = _raw(name);
    if (value != null) {
      return value;
    }
    return _parameter(name)?.defaultValue as String?;
  }

  int? integer(String name) {
    final value = _raw(name);
    if (value != null) {
      return int.tryParse(value) ?? _parameter(name)?.defaultValue as int?;
    }
    return _parameter(name)?.defaultValue as int?;
  }

  bool boolean(String name) {
    final value = _raw(name);
    if (value == 'true') {
      return true;
    }
    if (value == 'false') {
      return false;
    }
    return _parameter(name)?.defaultValue as bool? ?? false;
  }
}

enum AppRouteId {
  desktopLogin,
  desktopMoviePlayer,
  desktopCastRemote,
  desktopVideoPlayer,
  desktopClipCollectionPlay,
  desktopVideoCollectionPlay,
  desktopOverview,
  desktopDiscover,
  desktopMovies,
  desktopActors,
  desktopTags,
  desktopMoments,
  desktopPlaylists,
  desktopRatedMovies,
  desktopClips,
  desktopVideos,
  desktopRankings,
  desktopActivity,
  desktopDownloadTasks,
  desktopMedia,
  desktopNotifications,
  desktopConfiguration,
  desktopMediaImport,
  desktopMovieSubscriptions,
  desktopDiscoverMovies,
  desktopDiscoverMoments,
  desktopHotActressReleases,
  desktopFollow,
  desktopLatestMovies,
  desktopRecentlySubscribedMovies,
  desktopRecentViews,
  desktopFavorites,
  desktopRecentlyPlayed,
  desktopVideoCollections,
  desktopSystemDiagnostics,
  desktopSearch,
  desktopImageSearch,
  desktopSearchQuery,
  desktopMovieSeries,
  desktopMovieDetail,
  desktopPlaylistDetail,
  desktopClipCollections,
  desktopClipCollectionDetail,
  desktopMomentCollections,
  desktopMomentCollectionDetail,
  desktopActorDetail,
  desktopTagMovies,
  desktopVideoCollectionDetail,
  desktopVideoThumbnail,
  mobileLogin,
  mobileSearch,
  mobileImageSearch,
  mobileSearchQuery,
  mobileSettingsMediaLibraries,
  mobileSettingsMediaTags,
  mobileSettingsPlugins,
  mobileSettingsPluginMarket,
  mobileLatestMovies,
  mobileRecentlySubscribedMovies,
  mobileRecentViews,
  mobileFavorites,
  mobileRecentlyPlayed,
  mobileRatedMovies,
  mobileSystemOverview,
  mobileMediaImport,
  mobileActivity,
  mobileDownloadTasks,
  mobileNotifications,
  mobileMediaManagement,
  mobileMovieSubscriptions,
  mobileSettingsDownloaders,
  mobileSettingsIndexers,
  mobileSettingsDownloadSelection,
  mobileSettingsSystemMaintenance,
  mobileSettingsExternalPlayer,
  mobileSettingsAppearance,
  mobileSettingsAccountSecurity,
  mobileMoviePlayer,
  mobileCastRemote,
  mobileVideoPlayer,
  mobileVideoThumbnail,
  mobileTags,
  mobileTagMovies,
  mobileClipCollections,
  mobileClipCollectionDetail,
  mobileMomentCollections,
  mobileMomentCollectionDetail,
  mobileClipCollectionPlay,
  mobileVideoCollections,
  mobileVideoCollectionDetail,
  mobileVideoCollectionPlay,
  mobileOverview,
  mobileMovies,
  mobileActors,
  mobileRankings,
  mobilePornbox,
  mobileFollow,
  mobileDiscoverMovies,
  mobileDiscoverMoments,
  mobileHotActressReleases,
  mobilePlaylistDetail,
  mobileMovieSeries,
  mobileMovieDetail,
  mobileActorDetail,
}
