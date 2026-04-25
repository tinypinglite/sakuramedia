// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'desktop_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $desktopLoginRouteData,
  $desktopMoviePlayerRouteData,
  $desktopShellRouteData,
];

RouteBase get $desktopLoginRouteData => GoRouteData.$route(
  path: '/login',
  factory: $DesktopLoginRouteData._fromState,
);

mixin $DesktopLoginRouteData on GoRouteData {
  static DesktopLoginRouteData _fromState(GoRouterState state) =>
      const DesktopLoginRouteData();

  @override
  String get location => GoRouteData.$location('/login');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $desktopMoviePlayerRouteData => GoRouteData.$route(
  path: '/desktop/library/movies/:movieNumber/player',
  factory: $DesktopMoviePlayerRouteData._fromState,
);

mixin $DesktopMoviePlayerRouteData on GoRouteData {
  static DesktopMoviePlayerRouteData _fromState(GoRouterState state) =>
      DesktopMoviePlayerRouteData(
        movieNumber: state.pathParameters['movieNumber']!,
        mediaId: _$convertMapValue(
          'media-id',
          state.uri.queryParameters,
          int.tryParse,
        ),
        positionSeconds: _$convertMapValue(
          'position-seconds',
          state.uri.queryParameters,
          int.tryParse,
        ),
      );

  DesktopMoviePlayerRouteData get _self => this as DesktopMoviePlayerRouteData;

  @override
  String get location => GoRouteData.$location(
    '/desktop/library/movies/${Uri.encodeComponent(_self.movieNumber)}/player',
    queryParams: {
      if (_self.mediaId != null) 'media-id': _self.mediaId!.toString(),
      if (_self.positionSeconds != null)
        'position-seconds': _self.positionSeconds!.toString(),
    },
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T? Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
}

RouteBase get $desktopShellRouteData => ShellRouteData.$route(
  navigatorKey: DesktopShellRouteData.$navigatorKey,
  factory: $DesktopShellRouteDataExtension._fromState,
  routes: [
    GoRouteData.$route(
      path: '/desktop/overview',
      factory: $DesktopOverviewRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/library/follow',
      factory: $DesktopFollowRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/library/movies',
      factory: $DesktopMoviesRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/library/actors',
      factory: $DesktopActorsRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/library/moments',
      factory: $DesktopMomentsRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/library/playlists',
      factory: $DesktopPlaylistsRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/library/rankings',
      factory: $DesktopRankingsRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/library/hot-reviews',
      factory: $DesktopHotReviewsRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/system/activity',
      factory: $DesktopActivityRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/system/configuration',
      factory: $DesktopConfigurationRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/search',
      factory: $DesktopSearchRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/search/image',
      factory: $DesktopImageSearchRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/search/:query',
      factory: $DesktopSearchQueryRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/library/movies/series/:seriesId',
      factory: $DesktopMovieSeriesRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/library/movies/:movieNumber',
      factory: $DesktopMovieDetailRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/library/playlists/:playlistId',
      factory: $DesktopPlaylistDetailRouteData._fromState,
    ),
    GoRouteData.$route(
      path: '/desktop/library/actors/:actorId',
      factory: $DesktopActorDetailRouteData._fromState,
    ),
  ],
);

extension $DesktopShellRouteDataExtension on DesktopShellRouteData {
  static DesktopShellRouteData _fromState(GoRouterState state) =>
      const DesktopShellRouteData();
}

mixin $DesktopOverviewRouteData on GoRouteData {
  static DesktopOverviewRouteData _fromState(GoRouterState state) =>
      const DesktopOverviewRouteData();

  @override
  String get location => GoRouteData.$location('/desktop/overview');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopFollowRouteData on GoRouteData {
  static DesktopFollowRouteData _fromState(GoRouterState state) =>
      const DesktopFollowRouteData();

  @override
  String get location => GoRouteData.$location('/desktop/library/follow');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopMoviesRouteData on GoRouteData {
  static DesktopMoviesRouteData _fromState(GoRouterState state) =>
      const DesktopMoviesRouteData();

  @override
  String get location => GoRouteData.$location('/desktop/library/movies');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopActorsRouteData on GoRouteData {
  static DesktopActorsRouteData _fromState(GoRouterState state) =>
      const DesktopActorsRouteData();

  @override
  String get location => GoRouteData.$location('/desktop/library/actors');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopMomentsRouteData on GoRouteData {
  static DesktopMomentsRouteData _fromState(GoRouterState state) =>
      const DesktopMomentsRouteData();

  @override
  String get location => GoRouteData.$location('/desktop/library/moments');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopPlaylistsRouteData on GoRouteData {
  static DesktopPlaylistsRouteData _fromState(GoRouterState state) =>
      const DesktopPlaylistsRouteData();

  @override
  String get location => GoRouteData.$location('/desktop/library/playlists');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopRankingsRouteData on GoRouteData {
  static DesktopRankingsRouteData _fromState(GoRouterState state) =>
      const DesktopRankingsRouteData();

  @override
  String get location => GoRouteData.$location('/desktop/library/rankings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopHotReviewsRouteData on GoRouteData {
  static DesktopHotReviewsRouteData _fromState(GoRouterState state) =>
      const DesktopHotReviewsRouteData();

  @override
  String get location => GoRouteData.$location('/desktop/library/hot-reviews');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopActivityRouteData on GoRouteData {
  static DesktopActivityRouteData _fromState(GoRouterState state) =>
      const DesktopActivityRouteData();

  @override
  String get location => GoRouteData.$location('/desktop/system/activity');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopConfigurationRouteData on GoRouteData {
  static DesktopConfigurationRouteData _fromState(GoRouterState state) =>
      const DesktopConfigurationRouteData();

  @override
  String get location => GoRouteData.$location('/desktop/system/configuration');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopSearchRouteData on GoRouteData {
  static DesktopSearchRouteData _fromState(GoRouterState state) =>
      DesktopSearchRouteData(
        useOnlineSearch:
            _$convertMapValue(
              'use-online-search',
              state.uri.queryParameters,
              _$boolConverter,
            ) ??
            false,
      );

  DesktopSearchRouteData get _self => this as DesktopSearchRouteData;

  @override
  String get location => GoRouteData.$location(
    '/desktop/search',
    queryParams: {
      if (_self.useOnlineSearch != false)
        'use-online-search': _self.useOnlineSearch.toString(),
    },
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopImageSearchRouteData on GoRouteData {
  static DesktopImageSearchRouteData _fromState(GoRouterState state) =>
      DesktopImageSearchRouteData(
        draftId: state.uri.queryParameters['draft-id'],
        currentMovieNumber: state.uri.queryParameters['current-movie-number'],
        currentMovieScope:
            state.uri.queryParameters['current-movie-scope'] ?? 'all',
      );

  DesktopImageSearchRouteData get _self => this as DesktopImageSearchRouteData;

  @override
  String get location => GoRouteData.$location(
    '/desktop/search/image',
    queryParams: {
      if (_self.draftId != null) 'draft-id': _self.draftId,
      if (_self.currentMovieNumber != null)
        'current-movie-number': _self.currentMovieNumber,
      if (_self.currentMovieScope != 'all')
        'current-movie-scope': _self.currentMovieScope,
    },
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopSearchQueryRouteData on GoRouteData {
  static DesktopSearchQueryRouteData _fromState(GoRouterState state) =>
      DesktopSearchQueryRouteData(
        query: state.pathParameters['query']!,
        useOnlineSearch:
            _$convertMapValue(
              'use-online-search',
              state.uri.queryParameters,
              _$boolConverter,
            ) ??
            false,
      );

  DesktopSearchQueryRouteData get _self => this as DesktopSearchQueryRouteData;

  @override
  String get location => GoRouteData.$location(
    '/desktop/search/${Uri.encodeComponent(_self.query)}',
    queryParams: {
      if (_self.useOnlineSearch != false)
        'use-online-search': _self.useOnlineSearch.toString(),
    },
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopMovieSeriesRouteData on GoRouteData {
  static DesktopMovieSeriesRouteData _fromState(GoRouterState state) =>
      DesktopMovieSeriesRouteData(
        seriesId: int.parse(state.pathParameters['seriesId']!),
        seriesName: state.uri.queryParameters['series-name'],
      );

  DesktopMovieSeriesRouteData get _self => this as DesktopMovieSeriesRouteData;

  @override
  String get location => GoRouteData.$location(
    '/desktop/library/movies/series/${Uri.encodeComponent(_self.seriesId.toString())}',
    queryParams: {
      if (_self.seriesName != null) 'series-name': _self.seriesName,
    },
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopMovieDetailRouteData on GoRouteData {
  static DesktopMovieDetailRouteData _fromState(GoRouterState state) =>
      DesktopMovieDetailRouteData(
        movieNumber: state.pathParameters['movieNumber']!,
      );

  DesktopMovieDetailRouteData get _self => this as DesktopMovieDetailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/desktop/library/movies/${Uri.encodeComponent(_self.movieNumber)}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopPlaylistDetailRouteData on GoRouteData {
  static DesktopPlaylistDetailRouteData _fromState(GoRouterState state) =>
      DesktopPlaylistDetailRouteData(
        playlistId: int.parse(state.pathParameters['playlistId']!),
      );

  DesktopPlaylistDetailRouteData get _self =>
      this as DesktopPlaylistDetailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/desktop/library/playlists/${Uri.encodeComponent(_self.playlistId.toString())}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DesktopActorDetailRouteData on GoRouteData {
  static DesktopActorDetailRouteData _fromState(GoRouterState state) =>
      DesktopActorDetailRouteData(
        actorId: int.parse(state.pathParameters['actorId']!),
      );

  DesktopActorDetailRouteData get _self => this as DesktopActorDetailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/desktop/library/actors/${Uri.encodeComponent(_self.actorId.toString())}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

bool _$boolConverter(String value) {
  switch (value) {
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      throw UnsupportedError('Cannot convert "$value" into a bool.');
  }
}
