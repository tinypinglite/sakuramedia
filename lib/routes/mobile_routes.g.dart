// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mobile_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $mobileLoginRouteData,
  $mobileSearchRouteData,
  $mobileImageSearchRouteData,
  $mobileSearchQueryRouteData,
  $mobileSettingsMediaLibrariesRouteData,
  $mobileSettingsDownloadersRouteData,
  $mobileSettingsIndexersRouteData,
  $mobileSettingsPlaylistsRouteData,
  $mobileSettingsPasswordRouteData,
  $mobileMoviePlayerRouteData,
  $mobileRootShellRouteData,
];

RouteBase get $mobileLoginRouteData => GoRouteData.$route(
  path: '/login',
  factory: $MobileLoginRouteData._fromState,
);

mixin $MobileLoginRouteData on GoRouteData {
  static MobileLoginRouteData _fromState(GoRouterState state) =>
      const MobileLoginRouteData();

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

RouteBase get $mobileSearchRouteData => GoRouteData.$route(
  path: '/mobile/search',
  factory: $MobileSearchRouteData._fromState,
);

mixin $MobileSearchRouteData on GoRouteData {
  static MobileSearchRouteData _fromState(GoRouterState state) =>
      MobileSearchRouteData(
        useOnlineSearch:
            _$convertMapValue(
              'use-online-search',
              state.uri.queryParameters,
              _$boolConverter,
            ) ??
            false,
      );

  MobileSearchRouteData get _self => this as MobileSearchRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/search',
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

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T? Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
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

RouteBase get $mobileImageSearchRouteData => GoRouteData.$route(
  path: '/mobile/search/image',
  factory: $MobileImageSearchRouteData._fromState,
);

mixin $MobileImageSearchRouteData on GoRouteData {
  static MobileImageSearchRouteData _fromState(GoRouterState state) =>
      MobileImageSearchRouteData(
        draftId: state.uri.queryParameters['draft-id'],
        currentMovieNumber: state.uri.queryParameters['current-movie-number'],
        currentMovieScope:
            state.uri.queryParameters['current-movie-scope'] ?? 'all',
      );

  MobileImageSearchRouteData get _self => this as MobileImageSearchRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/search/image',
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

RouteBase get $mobileSearchQueryRouteData => GoRouteData.$route(
  path: '/mobile/search/:query',
  factory: $MobileSearchQueryRouteData._fromState,
);

mixin $MobileSearchQueryRouteData on GoRouteData {
  static MobileSearchQueryRouteData _fromState(GoRouterState state) =>
      MobileSearchQueryRouteData(
        query: state.pathParameters['query']!,
        useOnlineSearch:
            _$convertMapValue(
              'use-online-search',
              state.uri.queryParameters,
              _$boolConverter,
            ) ??
            false,
      );

  MobileSearchQueryRouteData get _self => this as MobileSearchQueryRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/search/${Uri.encodeComponent(_self.query)}',
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

RouteBase get $mobileSettingsMediaLibrariesRouteData => GoRouteData.$route(
  path: '/mobile/settings/media-libraries',
  factory: $MobileSettingsMediaLibrariesRouteData._fromState,
);

mixin $MobileSettingsMediaLibrariesRouteData on GoRouteData {
  static MobileSettingsMediaLibrariesRouteData _fromState(
    GoRouterState state,
  ) => const MobileSettingsMediaLibrariesRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/settings/media-libraries');

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

RouteBase get $mobileSettingsDownloadersRouteData => GoRouteData.$route(
  path: '/mobile/settings/downloaders',
  factory: $MobileSettingsDownloadersRouteData._fromState,
);

mixin $MobileSettingsDownloadersRouteData on GoRouteData {
  static MobileSettingsDownloadersRouteData _fromState(GoRouterState state) =>
      const MobileSettingsDownloadersRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/settings/downloaders');

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

RouteBase get $mobileSettingsIndexersRouteData => GoRouteData.$route(
  path: '/mobile/settings/indexers',
  factory: $MobileSettingsIndexersRouteData._fromState,
);

mixin $MobileSettingsIndexersRouteData on GoRouteData {
  static MobileSettingsIndexersRouteData _fromState(GoRouterState state) =>
      const MobileSettingsIndexersRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/settings/indexers');

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

RouteBase get $mobileSettingsPlaylistsRouteData => GoRouteData.$route(
  path: '/mobile/settings/playlists',
  factory: $MobileSettingsPlaylistsRouteData._fromState,
);

mixin $MobileSettingsPlaylistsRouteData on GoRouteData {
  static MobileSettingsPlaylistsRouteData _fromState(GoRouterState state) =>
      const MobileSettingsPlaylistsRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/settings/playlists');

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

RouteBase get $mobileSettingsPasswordRouteData => GoRouteData.$route(
  path: '/mobile/settings/password',
  factory: $MobileSettingsPasswordRouteData._fromState,
);

mixin $MobileSettingsPasswordRouteData on GoRouteData {
  static MobileSettingsPasswordRouteData _fromState(GoRouterState state) =>
      const MobileSettingsPasswordRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/settings/password');

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

RouteBase get $mobileMoviePlayerRouteData => GoRouteData.$route(
  path: '/mobile/library/movies/:movieNumber/player',
  factory: $MobileMoviePlayerRouteData._fromState,
);

mixin $MobileMoviePlayerRouteData on GoRouteData {
  static MobileMoviePlayerRouteData _fromState(GoRouterState state) =>
      MobileMoviePlayerRouteData(
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

  MobileMoviePlayerRouteData get _self => this as MobileMoviePlayerRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/library/movies/${Uri.encodeComponent(_self.movieNumber)}/player',
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

RouteBase get $mobileRootShellRouteData => StatefulShellRouteData.$route(
  factory: $MobileRootShellRouteDataExtension._fromState,
  branches: [
    StatefulShellBranchData.$branch(
      navigatorKey: MobileOverviewBranchData.$navigatorKey,
      routes: [
        GoRouteData.$route(
          path: '/mobile/overview',
          factory: $MobileOverviewRouteData._fromState,
          routes: [
            GoRouteData.$route(
              path: 'playlists/:playlistId',
              parentNavigatorKey:
                  MobilePlaylistDetailRouteData.$parentNavigatorKey,
              factory: $MobilePlaylistDetailRouteData._fromState,
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      navigatorKey: MobileMoviesBranchData.$navigatorKey,
      routes: [
        GoRouteData.$route(
          path: '/mobile/library/movies',
          factory: $MobileMoviesRouteData._fromState,
          routes: [
            GoRouteData.$route(
              path: ':movieNumber',
              parentNavigatorKey:
                  MobileMovieDetailRouteData.$parentNavigatorKey,
              factory: $MobileMovieDetailRouteData._fromState,
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      navigatorKey: MobileActorsBranchData.$navigatorKey,
      routes: [
        GoRouteData.$route(
          path: '/mobile/library/actors',
          factory: $MobileActorsRouteData._fromState,
          routes: [
            GoRouteData.$route(
              path: ':actorId',
              parentNavigatorKey:
                  MobileActorDetailRouteData.$parentNavigatorKey,
              factory: $MobileActorDetailRouteData._fromState,
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      navigatorKey: MobileRankingsBranchData.$navigatorKey,
      routes: [
        GoRouteData.$route(
          path: '/mobile/rankings',
          factory: $MobileRankingsRouteData._fromState,
        ),
      ],
    ),
  ],
);

extension $MobileRootShellRouteDataExtension on MobileRootShellRouteData {
  static MobileRootShellRouteData _fromState(GoRouterState state) =>
      const MobileRootShellRouteData();
}

mixin $MobileOverviewRouteData on GoRouteData {
  static MobileOverviewRouteData _fromState(GoRouterState state) =>
      const MobileOverviewRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/overview');

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

mixin $MobilePlaylistDetailRouteData on GoRouteData {
  static MobilePlaylistDetailRouteData _fromState(GoRouterState state) =>
      MobilePlaylistDetailRouteData(
        playlistId: int.parse(state.pathParameters['playlistId']!),
      );

  MobilePlaylistDetailRouteData get _self =>
      this as MobilePlaylistDetailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/overview/playlists/${Uri.encodeComponent(_self.playlistId.toString())}',
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

mixin $MobileMoviesRouteData on GoRouteData {
  static MobileMoviesRouteData _fromState(GoRouterState state) =>
      const MobileMoviesRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/library/movies');

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

mixin $MobileMovieDetailRouteData on GoRouteData {
  static MobileMovieDetailRouteData _fromState(GoRouterState state) =>
      MobileMovieDetailRouteData(
        movieNumber: state.pathParameters['movieNumber']!,
      );

  MobileMovieDetailRouteData get _self => this as MobileMovieDetailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/library/movies/${Uri.encodeComponent(_self.movieNumber)}',
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

mixin $MobileActorsRouteData on GoRouteData {
  static MobileActorsRouteData _fromState(GoRouterState state) =>
      const MobileActorsRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/library/actors');

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

mixin $MobileActorDetailRouteData on GoRouteData {
  static MobileActorDetailRouteData _fromState(GoRouterState state) =>
      MobileActorDetailRouteData(
        actorId: int.parse(state.pathParameters['actorId']!),
      );

  MobileActorDetailRouteData get _self => this as MobileActorDetailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/library/actors/${Uri.encodeComponent(_self.actorId.toString())}',
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

mixin $MobileRankingsRouteData on GoRouteData {
  static MobileRankingsRouteData _fromState(GoRouterState state) =>
      const MobileRankingsRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/rankings');

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
