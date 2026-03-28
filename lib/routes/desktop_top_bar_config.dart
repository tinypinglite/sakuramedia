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

  if (currentPath.startsWith('/desktop/library/movies/')) {
    return DesktopTopBarConfig(
      title: '影片详情',
      fallbackPath:
          _fallbackPathFromExtra(routeExtra) ??
          AppBackDestination.defaultLocationForPath(currentPath),
      isBackEnabled: true,
    );
  }

  if (currentPath.startsWith('/desktop/library/actors/')) {
    return DesktopTopBarConfig(
      title: '女优详情',
      fallbackPath:
          _fallbackPathFromExtra(routeExtra) ??
          AppBackDestination.defaultLocationForPath(currentPath),
      isBackEnabled: true,
    );
  }

  if (currentPath.startsWith('/desktop/library/playlists/')) {
    return DesktopTopBarConfig(
      title: '播放列表详情',
      fallbackPath:
          _fallbackPathFromExtra(routeExtra) ??
          AppBackDestination.defaultLocationForPath(currentPath),
      isBackEnabled: true,
    );
  }

  if (currentPath == desktopImageSearchPath) {
    return DesktopTopBarConfig(
      title: '以图搜图',
      fallbackPath:
          _fallbackPathFromExtra(routeExtra) ??
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
          _fallbackPathFromExtra(routeExtra) ??
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

String? _fallbackPathFromExtra(Object? routeExtra) {
  if (routeExtra is String && routeExtra.startsWith('/desktop/')) {
    return routeExtra;
  }
  final searchState = DesktopSearchRouteState.maybeFromExtra(routeExtra);
  final searchFallbackPath = searchState.fallbackPath;
  if (searchFallbackPath != null &&
      searchFallbackPath.startsWith('/desktop/')) {
    return searchFallbackPath;
  }
  final imageSearchState = DesktopImageSearchRouteState.maybeFromExtra(
    routeExtra,
  );
  final imageSearchFallbackPath = imageSearchState.fallbackPath;
  if (imageSearchFallbackPath != null &&
      imageSearchFallbackPath.startsWith('/desktop/')) {
    return imageSearchFallbackPath;
  }
  return null;
}

AppShellLayout resolveDesktopShellLayout({
  required String currentPath,
  required List<AppRouteSpec> routeSpecs,
}) {
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
