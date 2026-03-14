import 'package:flutter/foundation.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
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
    final fallbackPath =
        _fallbackPathFromExtra(routeExtra) ?? desktopOverviewPath;
    return DesktopTopBarConfig(
      title: '影片详情',
      fallbackPath: fallbackPath,
      isBackEnabled: true,
    );
  }

  if (currentPath.startsWith('/desktop/library/actors/')) {
    final fallbackPath =
        _fallbackPathFromExtra(routeExtra) ?? desktopActorsPath;
    return DesktopTopBarConfig(
      title: '女优详情',
      fallbackPath: fallbackPath,
      isBackEnabled: true,
    );
  }

  if (currentPath.startsWith('/desktop/library/playlists/')) {
    final fallbackPath =
        _fallbackPathFromExtra(routeExtra) ?? desktopPlaylistsPath;
    return DesktopTopBarConfig(
      title: '播放列表详情',
      fallbackPath: fallbackPath,
      isBackEnabled: true,
    );
  }

  if (currentPath == desktopImageSearchPath) {
    final fallbackPath =
        _fallbackPathFromExtra(routeExtra) ?? desktopOverviewPath;
    return DesktopTopBarConfig(
      title: '以图搜图',
      fallbackPath: fallbackPath,
      isBackEnabled: true,
    );
  }

  if (currentPath == desktopSearchPath ||
      currentPath.startsWith('$desktopSearchPath/')) {
    final fallbackPath =
        _fallbackPathFromExtra(routeExtra) ?? desktopOverviewPath;
    final title =
        currentPath == desktopSearchPath
            ? '搜索'
            : _decodeSearchTitleSegment(
              currentPath.substring(desktopSearchPath.length + 1),
            );
    return DesktopTopBarConfig(
      title: title,
      fallbackPath: fallbackPath,
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

String? _fallbackPathFromExtra(Object? routeExtra) {
  if (routeExtra is String && routeExtra.startsWith('/desktop/')) {
    return routeExtra;
  }

  final state = DesktopSearchRouteState.maybeFromExtra(routeExtra);
  final fallbackPath = state.fallbackPath;
  if (fallbackPath != null && fallbackPath.startsWith('/desktop/')) {
    return fallbackPath;
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

String _decodeSearchTitleSegment(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return value;
  }
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
