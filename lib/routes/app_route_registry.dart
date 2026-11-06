import 'package:go_router/go_router.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/definitions/actors_tags.dart';
import 'package:sakuramedia/routes/definitions/auth.dart';
import 'package:sakuramedia/routes/definitions/collections.dart';
import 'package:sakuramedia/routes/definitions/discovery.dart';
import 'package:sakuramedia/routes/definitions/movies.dart';
import 'package:sakuramedia/routes/definitions/overview.dart';
import 'package:sakuramedia/routes/definitions/playlists.dart';
import 'package:sakuramedia/routes/definitions/search.dart';
import 'package:sakuramedia/routes/definitions/shared.dart';
import 'package:sakuramedia/routes/definitions/system.dart';
import 'package:sakuramedia/routes/definitions/videos.dart';

class AppRouteRegistry {
  AppRouteRegistry(Iterable<AppRouteDefinition> definitions)
    : definitions = List<AppRouteDefinition>.unmodifiable(definitions) {
    _validate();
  }

  final List<AppRouteDefinition> definitions;

  late final Map<AppRouteId, AppRouteDefinition> _byId = {
    for (final definition in definitions) definition.id: definition,
  };
  late final Map<String, AppRouteDefinition> _byPlatformName = {
    for (final definition in definitions)
      _nameKey(definition.platform, definition.name): definition,
  };
  late final Map<AppPlatform, List<AppRouteDefinition>> _byPlatform = {
    for (final platform in AppPlatform.values)
      platform: definitions
          .where((definition) => definition.platform == platform)
          .toList(growable: false),
  };
  late final Map<AppPlatform, List<_PathMatcher>> _pathMatchers = {
    for (final platform in AppPlatform.values)
      platform: _byPlatform[platform]!
          .map(_PathMatcher.new)
          .toList(growable: false),
  };

  AppRouteDefinition byId(AppRouteId id) {
    final definition = _byId[id];
    if (definition == null) {
      throw StateError('Missing route definition for $id');
    }
    return definition;
  }

  AppRouteDefinition? byName(AppPlatform platform, String? name) {
    if (name == null) {
      return null;
    }
    return _byPlatformName[_nameKey(platform, name)];
  }

  List<AppRouteDefinition> forPlatform(AppPlatform platform) =>
      _byPlatform[platform]!;

  List<AppRouteDefinition> scoped(
    AppPlatform platform,
    AppRouteScope scope, {
    AppRouteId? parentId,
  }) {
    return _byPlatform[platform]!
        .where(
          (definition) =>
              definition.scope == scope &&
              (parentId == null || definition.parentId == parentId),
        )
        .toList(growable: false);
  }

  AppRouteDefinition? forPath(AppPlatform platform, String path) {
    for (final matcher in _pathMatchers[platform]!) {
      if (matcher.matches(path)) {
        return matcher.definition;
      }
    }
    return null;
  }

  AppRouteDefinition? forState(AppPlatform platform, GoRouterState state) {
    return byName(platform, state.name) ?? forPath(platform, state.uri.path);
  }

  String locationOf({
    required AppRouteDefinition definition,
    required Map<String, String> pathParameters,
    required Map<String, String?> queryParameters,
  }) {
    final resolvedPath = definition.path.replaceAllMapped(
      RegExp(r':([A-Za-z0-9_]+)'),
      (match) {
        final name = match.group(1)!;
        final value = pathParameters[name];
        if (value == null) {
          throw StateError(
            'Missing path parameter "$name" for ${definition.id}',
          );
        }
        return Uri.encodeComponent(value);
      },
    );

    final effectiveQuery = <String, String>{};
    for (final parameter in definition.queryParameters) {
      final value = queryParameters[parameter.name];
      if (value == null || value.isEmpty) {
        continue;
      }
      final defaultValue = parameter.defaultValue;
      if (defaultValue != null && value == '$defaultValue') {
        continue;
      }
      effectiveQuery[parameter.name] = value;
    }
    if (effectiveQuery.isEmpty) {
      return resolvedPath;
    }
    return '$resolvedPath?${Uri(queryParameters: effectiveQuery).query}';
  }

  void _validate() {
    final ids = <AppRouteId>{};
    final paths = <String>{};
    final names = <String>{};

    for (final definition in definitions) {
      if (!ids.add(definition.id)) {
        throw StateError('Duplicate route id: ${definition.id}');
      }
      final pathKey = '${definition.platform.name}:${definition.path}';
      if (!paths.add(pathKey)) {
        throw StateError('Duplicate route path: $pathKey');
      }
      if (!names.add(_nameKey(definition.platform, definition.name))) {
        throw StateError(
          'Duplicate route name: ${definition.platform.name}:${definition.name}',
        );
      }
      if (definition.scope == AppRouteScope.branchChild) {
        final parentId = definition.parentId;
        if (parentId == null) {
          throw StateError(
            'branchChild route ${definition.id} must declare parentId',
          );
        }
        final parent = _byId[parentId];
        if (parent == null) {
          throw StateError(
            'branchChild route ${definition.id} references missing parent $parentId',
          );
        }
        if (!definition.path.startsWith('${parent.path}/')) {
          throw StateError(
            'branchChild route ${definition.id} path must be nested under ${parent.path}',
          );
        }
      }
      final queryNames = <String>{};
      for (final parameter in definition.queryParameters) {
        if (!queryNames.add(parameter.name)) {
          throw StateError(
            'Duplicate query parameter ${parameter.name} on ${definition.id}',
          );
        }
        final alias = parameter.alias;
        if (alias != null && queryNames.contains(alias)) {
          throw StateError('Query alias $alias collides on ${definition.id}');
        }
        queryNames.add(alias ?? parameter.name);
      }
    }
  }

  static String _nameKey(AppPlatform platform, String name) =>
      '${platform.name}:$name';
}

class _PathMatcher {
  _PathMatcher(this.definition)
    : _pattern = RegExp(
        '^${definition.path.replaceAllMapped(RegExp(r':([A-Za-z0-9_]+)'), (match) => '([^/]+)')}\$',
      );

  final AppRouteDefinition definition;
  final RegExp _pattern;

  bool matches(String path) => _pattern.hasMatch(path);
}

final AppRouteRegistry appRoutes = AppRouteRegistry(<AppRouteDefinition>[
  desktopLoginRoute,
  desktopMoviePlayerRoute,
  desktopCastRemoteRoute,
  desktopVideoPlayerRoute,
  desktopClipCollectionPlayRoute,
  desktopVideoCollectionPlayRoute,
  desktopOverviewRoute,
  desktopDiscoverRoute,
  desktopMoviesRoute,
  desktopActorsRoute,
  desktopTagsRoute,
  desktopMomentsRoute,
  desktopPlaylistsRoute,
  desktopRatedMoviesRoute,
  desktopClipsRoute,
  desktopVideosRoute,
  desktopRankingsRoute,
  desktopActivityRoute,
  desktopDownloadTasksRoute,
  desktopMediaRoute,
  desktopNotificationsRoute,
  desktopConfigurationRoute,
  desktopMediaImportRoute,
  desktopMovieSubscriptionsRoute,
  desktopDiscoverMoviesRoute,
  desktopDiscoverMomentsRoute,
  desktopHotActressReleasesRoute,
  desktopFollowRoute,
  desktopLatestMoviesRoute,
  desktopRecentlySubscribedMoviesRoute,
  desktopRecentViewsRoute,
  desktopFavoritesRoute,
  desktopRecentlyPlayedRoute,
  desktopVideoCollectionsRoute,
  desktopSystemDiagnosticsRoute,
  desktopSearchRoute,
  desktopImageSearchRoute,
  desktopSearchQueryRoute,
  desktopMovieSeriesRoute,
  desktopMovieDetailRoute,
  desktopPlaylistDetailRoute,
  desktopClipCollectionsRoute,
  desktopClipCollectionDetailRoute,
  desktopMomentCollectionsRoute,
  desktopMomentCollectionDetailRoute,
  desktopActorDetailRoute,
  desktopTagMoviesRoute,
  desktopVideoCollectionDetailRoute,
  desktopVideoThumbnailRoute,
  mobileLoginRoute,
  mobileSearchRoute,
  mobileImageSearchRoute,
  mobileSearchQueryRoute,
  mobileSettingsMediaLibrariesRoute,
  mobileSettingsMediaTagsRoute,
  mobileSettingsPluginsRoute,
  mobileSettingsPluginMarketRoute,
  mobileLatestMoviesRoute,
  mobileRecentlySubscribedMoviesRoute,
  mobileRecentViewsRoute,
  mobileFavoritesRoute,
  mobileRecentlyPlayedRoute,
  mobileRatedMoviesRoute,
  mobileSystemOverviewRoute,
  mobileMediaImportRoute,
  mobileActivityRoute,
  mobileDownloadTasksRoute,
  mobileNotificationsRoute,
  mobileMediaManagementRoute,
  mobileMovieSubscriptionsRoute,
  mobileSettingsDownloadersRoute,
  mobileSettingsIndexersRoute,
  mobileSettingsDownloadSelectionRoute,
  mobileSettingsSystemMaintenanceRoute,
  mobileSettingsExternalPlayerRoute,
  mobileSettingsAppearanceRoute,
  mobileSettingsAccountSecurityRoute,
  mobileMoviePlayerRoute,
  mobileCastRemoteRoute,
  mobileVideoPlayerRoute,
  mobileVideoThumbnailRoute,
  mobileTagsRoute,
  mobileTagMoviesRoute,
  mobileClipCollectionsRoute,
  mobileClipCollectionDetailRoute,
  mobileMomentCollectionsRoute,
  mobileMomentCollectionDetailRoute,
  mobileClipCollectionPlayRoute,
  mobileVideoCollectionsRoute,
  mobileVideoCollectionDetailRoute,
  mobileVideoCollectionPlayRoute,
  mobileOverviewRoute,
  mobileMoviesRoute,
  mobileActorsRoute,
  mobileRankingsRoute,
  mobilePornboxRoute,
  mobileFollowRoute,
  mobileDiscoverMoviesRoute,
  mobileDiscoverMomentsRoute,
  mobileHotActressReleasesRoute,
  mobilePlaylistDetailRoute,
  mobileMovieSeriesRoute,
  mobileMovieDetailRoute,
  mobileActorDetailRoute,
]);
