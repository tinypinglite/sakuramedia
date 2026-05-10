import 'package:flutter/foundation.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/routes/app_back_destination.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_search_route_state.dart';

@immutable
class DesktopTopBarConfig {
  const DesktopTopBarConfig({
    required this.title,
    required this.fallbackPath,
    required this.isBackEnabled,
  });

  final String title;
  final String? fallbackPath;
  final bool isBackEnabled;
}

DesktopTopBarConfig resolveDesktopTopBarConfig({
  required String currentPath,
  required List<AppRouteSpec> routeSpecs,
  Object? routeExtra,
}) {
  if (currentPath == desktopOverviewPath) {
    return const DesktopTopBarConfig(
      title: '概览',
      fallbackPath: null,
      isBackEnabled: false,
    );
  }

  if (currentPath == desktopDiscoverMoviesPath) {
    return const DesktopTopBarConfig(
      title: '推荐影片',
      fallbackPath: desktopDiscoverPath,
      isBackEnabled: true,
    );
  }

  if (currentPath == desktopDiscoverMomentsPath) {
    return const DesktopTopBarConfig(
      title: '推荐时刻',
      fallbackPath: desktopDiscoverPath,
      isBackEnabled: true,
    );
  }

  if (currentPath.startsWith(desktopMovieSeriesPathPrefix)) {
    return DesktopTopBarConfig(
      title: '系列影片',
      fallbackPath:
          _fallbackPathFromExtra(routeExtra, currentPath: currentPath) ??
          AppBackDestination.defaultLocationForPath(currentPath),
      isBackEnabled: true,
    );
  }

  if (currentPath.startsWith('/desktop/library/movies/')) {
    return DesktopTopBarConfig(
      title: '影片详情',
      fallbackPath:
          _fallbackPathFromExtra(routeExtra, currentPath: currentPath) ??
          AppBackDestination.defaultLocationForPath(currentPath),
      isBackEnabled: true,
    );
  }

  if (currentPath.startsWith('/desktop/library/actors/')) {
    return DesktopTopBarConfig(
      title: '女优详情',
      fallbackPath:
          _fallbackPathFromExtra(routeExtra, currentPath: currentPath) ??
          AppBackDestination.defaultLocationForPath(currentPath),
      isBackEnabled: true,
    );
  }

  if (currentPath.startsWith('/desktop/library/playlists/')) {
    return DesktopTopBarConfig(
      title: '播放列表详情',
      fallbackPath:
          _fallbackPathFromExtra(routeExtra, currentPath: currentPath) ??
          AppBackDestination.defaultLocationForPath(currentPath),
      isBackEnabled: true,
    );
  }

  if (currentPath == desktopImageSearchPath) {
    return DesktopTopBarConfig(
      title: '以图搜图',
      fallbackPath:
          _fallbackPathFromExtra(routeExtra, currentPath: currentPath) ??
          AppBackDestination.defaultLocationForPath(currentPath),
      isBackEnabled: true,
    );
  }

  if (currentPath == desktopSearchPath ||
      currentPath.startsWith('$desktopSearchPath/')) {
    final title =
        currentPath == desktopSearchPath
            ? '搜索'
            : _decodeSearchTitleSegment(
              currentPath.substring(desktopSearchPath.length + 1),
            );
    return DesktopTopBarConfig(
      title: title,
      fallbackPath:
          _fallbackPathFromExtra(routeExtra, currentPath: currentPath) ??
          AppBackDestination.defaultLocationForPath(currentPath),
      isBackEnabled: true,
    );
  }

  final currentSpec = routeSpecs.firstWhere(
    (spec) => spec.path == currentPath,
    orElse: () => routeSpecs.first,
  );
  return DesktopTopBarConfig(
    title: currentSpec.title,
    fallbackPath: null,
    isBackEnabled: false,
  );
}

String _decodeSearchTitleSegment(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return value;
  }
}

String? _fallbackPathFromExtra(
  Object? routeExtra, {
  required String currentPath,
}) {
  final fallbackPath = switch (routeExtra) {
    DesktopSearchRouteState(:final fallbackPath) => fallbackPath,
    DesktopImageSearchRouteState(:final fallbackPath) => fallbackPath,
    String value when _allowsLegacyStringExtra(currentPath, value) => value,
    _ => null,
  };
  if (fallbackPath != null && fallbackPath.startsWith('/desktop/')) {
    return fallbackPath;
  }
  return null;
}

bool _allowsLegacyStringExtra(String currentPath, String fallbackPath) {
  if (!fallbackPath.startsWith('/desktop/')) {
    return false;
  }
  if (currentPath == desktopImageSearchPath ||
      currentPath == desktopSearchPath ||
      currentPath.startsWith('$desktopSearchPath/')) {
    return true;
  }
  if (currentPath.startsWith('/desktop/library/movies/')) {
    return fallbackPath.startsWith(desktopMoviesPath);
  }
  if (currentPath.startsWith('/desktop/library/actors/') ||
      currentPath.startsWith('/desktop/library/playlists/')) {
    return fallbackPath.startsWith('/desktop/library/');
  }
  return false;
}

AppShellLayout resolveDesktopShellLayout({
  required String currentPath,
  required List<AppRouteSpec> routeSpecs,
}) {
  if (currentPath.startsWith(desktopMovieSeriesPathPrefix)) {
    return AppShellLayout.standard;
  }

  if (currentPath.startsWith('/desktop/library/movies/')) {
    return AppShellLayout.standard;
  }

  if (currentPath.startsWith('/desktop/library/actors/')) {
    return AppShellLayout.standard;
  }

  if (currentPath.startsWith('/desktop/library/playlists/')) {
    return AppShellLayout.standard;
  }

  final currentSpec = routeSpecs.firstWhere(
    (spec) => spec.path == currentPath,
    orElse: () => routeSpecs.first,
  );
  return currentSpec.layout;
}
