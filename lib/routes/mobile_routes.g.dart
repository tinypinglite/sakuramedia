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
  $mobileSettingsMediaTagsRouteData,
  $mobileSettingsPluginsRouteData,
  $mobileSettingsPluginMarketRouteData,
  $mobileLatestMoviesRouteData,
  $mobileRecentlySubscribedMoviesRouteData,
  $mobileRecentViewsRouteData,
  $mobileFavoritesRouteData,
  $mobileRecentlyPlayedRouteData,
  $mobileRatedMoviesRouteData,
  $mobileSystemOverviewRouteData,
  $mobileMediaImportRouteData,
  $mobileActivityRouteData,
  $mobileDownloadTasksRouteData,
  $mobileNotificationsRouteData,
  $mobileMediaManagementRouteData,
  $mobileMovieSubscriptionsRouteData,
  $mobileSettingsDownloadersRouteData,
  $mobileSettingsIndexersRouteData,
  $mobileSettingsDownloadSelectionRouteData,
  $mobileSettingsSystemMaintenanceRouteData,
  $mobileSettingsExternalPlayerRouteData,
  $mobileSettingsAppearanceRouteData,
  $mobileSettingsAccountSecurityRouteData,
  $mobileMoviePlayerRouteData,
  $mobileCastRemoteRouteData,
  $mobileVideoPlayerRouteData,
  $mobileVideoThumbnailRouteData,
  $mobileTagsRouteData,
  $mobileTagMoviesRouteData,
  $mobileClipCollectionsRouteData,
  $mobileClipCollectionDetailRouteData,
  $mobileMomentCollectionsRouteData,
  $mobileMomentCollectionDetailRouteData,
  $mobileClipCollectionPlayRouteData,
  $mobileVideoCollectionsRouteData,
  $mobileVideoCollectionDetailRouteData,
  $mobileVideoCollectionPlayRouteData,
  $mobileRootShellRouteData,
];

RouteBase get $mobileLoginRouteData => GoRouteData.$route(
  path: '/login',
  hasOverriddenOnExit: false,
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
  hasOverriddenOnExit: false,
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
  hasOverriddenOnExit: false,
  factory: $MobileImageSearchRouteData._fromState,
);

mixin $MobileImageSearchRouteData on GoRouteData {
  static MobileImageSearchRouteData _fromState(GoRouterState state) =>
      MobileImageSearchRouteData(
        draftId: state.uri.queryParameters['draft-id'],
        currentMovieNumber: state.uri.queryParameters['current-movie-number'],
        currentMovieScope:
            state.uri.queryParameters['current-movie-scope'] ?? 'all',
        mode: state.uri.queryParameters['mode'] ?? 'image',
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
      if (_self.mode != 'image') 'mode': _self.mode,
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
  hasOverriddenOnExit: false,
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
  hasOverriddenOnExit: false,
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

RouteBase get $mobileSettingsMediaTagsRouteData => GoRouteData.$route(
  path: '/mobile/settings/media-tags',
  hasOverriddenOnExit: false,
  factory: $MobileSettingsMediaTagsRouteData._fromState,
);

mixin $MobileSettingsMediaTagsRouteData on GoRouteData {
  static MobileSettingsMediaTagsRouteData _fromState(GoRouterState state) =>
      const MobileSettingsMediaTagsRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/settings/media-tags');

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

RouteBase get $mobileSettingsPluginsRouteData => GoRouteData.$route(
  path: '/mobile/settings/plugins',
  hasOverriddenOnExit: false,
  factory: $MobileSettingsPluginsRouteData._fromState,
);

mixin $MobileSettingsPluginsRouteData on GoRouteData {
  static MobileSettingsPluginsRouteData _fromState(GoRouterState state) =>
      const MobileSettingsPluginsRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/settings/plugins');

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

RouteBase get $mobileSettingsPluginMarketRouteData => GoRouteData.$route(
  path: '/mobile/settings/plugins/market',
  hasOverriddenOnExit: false,
  factory: $MobileSettingsPluginMarketRouteData._fromState,
);

mixin $MobileSettingsPluginMarketRouteData on GoRouteData {
  static MobileSettingsPluginMarketRouteData _fromState(GoRouterState state) =>
      const MobileSettingsPluginMarketRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/settings/plugins/market');

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

RouteBase get $mobileLatestMoviesRouteData => GoRouteData.$route(
  path: '/mobile/library/latest',
  hasOverriddenOnExit: false,
  factory: $MobileLatestMoviesRouteData._fromState,
);

mixin $MobileLatestMoviesRouteData on GoRouteData {
  static MobileLatestMoviesRouteData _fromState(GoRouterState state) =>
      const MobileLatestMoviesRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/library/latest');

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

RouteBase get $mobileRecentlySubscribedMoviesRouteData => GoRouteData.$route(
  path: '/mobile/library/recently-subscribed',
  hasOverriddenOnExit: false,
  factory: $MobileRecentlySubscribedMoviesRouteData._fromState,
);

mixin $MobileRecentlySubscribedMoviesRouteData on GoRouteData {
  static MobileRecentlySubscribedMoviesRouteData _fromState(
    GoRouterState state,
  ) => const MobileRecentlySubscribedMoviesRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/library/recently-subscribed');

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

RouteBase get $mobileRecentViewsRouteData => GoRouteData.$route(
  path: '/mobile/library/recent-views',
  hasOverriddenOnExit: false,
  factory: $MobileRecentViewsRouteData._fromState,
);

mixin $MobileRecentViewsRouteData on GoRouteData {
  static MobileRecentViewsRouteData _fromState(GoRouterState state) =>
      const MobileRecentViewsRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/library/recent-views');

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

RouteBase get $mobileFavoritesRouteData => GoRouteData.$route(
  path: '/mobile/library/favorites',
  hasOverriddenOnExit: false,
  factory: $MobileFavoritesRouteData._fromState,
);

mixin $MobileFavoritesRouteData on GoRouteData {
  static MobileFavoritesRouteData _fromState(GoRouterState state) =>
      const MobileFavoritesRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/library/favorites');

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

RouteBase get $mobileRecentlyPlayedRouteData => GoRouteData.$route(
  path: '/mobile/library/recently-played',
  hasOverriddenOnExit: false,
  factory: $MobileRecentlyPlayedRouteData._fromState,
);

mixin $MobileRecentlyPlayedRouteData on GoRouteData {
  static MobileRecentlyPlayedRouteData _fromState(GoRouterState state) =>
      const MobileRecentlyPlayedRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/library/recently-played');

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

RouteBase get $mobileRatedMoviesRouteData => GoRouteData.$route(
  path: '/mobile/library/ratings',
  hasOverriddenOnExit: false,
  factory: $MobileRatedMoviesRouteData._fromState,
);

mixin $MobileRatedMoviesRouteData on GoRouteData {
  static MobileRatedMoviesRouteData _fromState(GoRouterState state) =>
      const MobileRatedMoviesRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/library/ratings');

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

RouteBase get $mobileSystemOverviewRouteData => GoRouteData.$route(
  path: '/mobile/system/overview',
  hasOverriddenOnExit: false,
  factory: $MobileSystemOverviewRouteData._fromState,
);

mixin $MobileSystemOverviewRouteData on GoRouteData {
  static MobileSystemOverviewRouteData _fromState(GoRouterState state) =>
      const MobileSystemOverviewRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/system/overview');

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

RouteBase get $mobileMediaImportRouteData => GoRouteData.$route(
  path: '/mobile/system/media-import',
  hasOverriddenOnExit: false,
  factory: $MobileMediaImportRouteData._fromState,
);

mixin $MobileMediaImportRouteData on GoRouteData {
  static MobileMediaImportRouteData _fromState(GoRouterState state) =>
      const MobileMediaImportRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/system/media-import');

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

RouteBase get $mobileActivityRouteData => GoRouteData.$route(
  path: '/mobile/system/activity',
  hasOverriddenOnExit: false,
  factory: $MobileActivityRouteData._fromState,
);

mixin $MobileActivityRouteData on GoRouteData {
  static MobileActivityRouteData _fromState(GoRouterState state) =>
      const MobileActivityRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/system/activity');

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

RouteBase get $mobileDownloadTasksRouteData => GoRouteData.$route(
  path: '/mobile/system/download-tasks',
  hasOverriddenOnExit: false,
  factory: $MobileDownloadTasksRouteData._fromState,
);

mixin $MobileDownloadTasksRouteData on GoRouteData {
  static MobileDownloadTasksRouteData _fromState(GoRouterState state) =>
      MobileDownloadTasksRouteData(
        downloadMovieNumber: state.uri.queryParameters['download-movie-number'],
      );

  MobileDownloadTasksRouteData get _self =>
      this as MobileDownloadTasksRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/system/download-tasks',
    queryParams: {
      if (_self.downloadMovieNumber != null)
        'download-movie-number': _self.downloadMovieNumber,
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

RouteBase get $mobileNotificationsRouteData => GoRouteData.$route(
  path: '/mobile/system/notifications',
  hasOverriddenOnExit: false,
  factory: $MobileNotificationsRouteData._fromState,
);

mixin $MobileNotificationsRouteData on GoRouteData {
  static MobileNotificationsRouteData _fromState(GoRouterState state) =>
      const MobileNotificationsRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/system/notifications');

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

RouteBase get $mobileMediaManagementRouteData => GoRouteData.$route(
  path: '/mobile/system/media',
  hasOverriddenOnExit: false,
  factory: $MobileMediaManagementRouteData._fromState,
);

mixin $MobileMediaManagementRouteData on GoRouteData {
  static MobileMediaManagementRouteData _fromState(GoRouterState state) =>
      const MobileMediaManagementRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/system/media');

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

RouteBase get $mobileMovieSubscriptionsRouteData => GoRouteData.$route(
  path: '/mobile/system/movie-subscriptions',
  hasOverriddenOnExit: false,
  factory: $MobileMovieSubscriptionsRouteData._fromState,
);

mixin $MobileMovieSubscriptionsRouteData on GoRouteData {
  static MobileMovieSubscriptionsRouteData _fromState(GoRouterState state) =>
      const MobileMovieSubscriptionsRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/system/movie-subscriptions');

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
  hasOverriddenOnExit: false,
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
  hasOverriddenOnExit: false,
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

RouteBase get $mobileSettingsDownloadSelectionRouteData => GoRouteData.$route(
  path: '/mobile/settings/download-selection',
  hasOverriddenOnExit: false,
  factory: $MobileSettingsDownloadSelectionRouteData._fromState,
);

mixin $MobileSettingsDownloadSelectionRouteData on GoRouteData {
  static MobileSettingsDownloadSelectionRouteData _fromState(
    GoRouterState state,
  ) => const MobileSettingsDownloadSelectionRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/settings/download-selection');

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

RouteBase get $mobileSettingsSystemMaintenanceRouteData => GoRouteData.$route(
  path: '/mobile/settings/system-maintenance',
  hasOverriddenOnExit: false,
  factory: $MobileSettingsSystemMaintenanceRouteData._fromState,
);

mixin $MobileSettingsSystemMaintenanceRouteData on GoRouteData {
  static MobileSettingsSystemMaintenanceRouteData _fromState(
    GoRouterState state,
  ) => const MobileSettingsSystemMaintenanceRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/settings/system-maintenance');

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

RouteBase get $mobileSettingsExternalPlayerRouteData => GoRouteData.$route(
  path: '/mobile/settings/external-player',
  hasOverriddenOnExit: false,
  factory: $MobileSettingsExternalPlayerRouteData._fromState,
);

mixin $MobileSettingsExternalPlayerRouteData on GoRouteData {
  static MobileSettingsExternalPlayerRouteData _fromState(
    GoRouterState state,
  ) => const MobileSettingsExternalPlayerRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/settings/external-player');

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

RouteBase get $mobileSettingsAppearanceRouteData => GoRouteData.$route(
  path: '/mobile/settings/appearance',
  hasOverriddenOnExit: false,
  factory: $MobileSettingsAppearanceRouteData._fromState,
);

mixin $MobileSettingsAppearanceRouteData on GoRouteData {
  static MobileSettingsAppearanceRouteData _fromState(GoRouterState state) =>
      const MobileSettingsAppearanceRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/settings/appearance');

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

RouteBase get $mobileSettingsAccountSecurityRouteData => GoRouteData.$route(
  path: '/mobile/settings/account-security',
  hasOverriddenOnExit: false,
  factory: $MobileSettingsAccountSecurityRouteData._fromState,
);

mixin $MobileSettingsAccountSecurityRouteData on GoRouteData {
  static MobileSettingsAccountSecurityRouteData _fromState(
    GoRouterState state,
  ) => const MobileSettingsAccountSecurityRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/settings/account-security');

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
  hasOverriddenOnExit: false,
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
        mergedLibraryId: _$convertMapValue(
          'merged-library-id',
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
      if (_self.mergedLibraryId != null)
        'merged-library-id': _self.mergedLibraryId!.toString(),
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

RouteBase get $mobileCastRemoteRouteData => GoRouteData.$route(
  path: '/mobile/cast/remote',
  hasOverriddenOnExit: false,
  factory: $MobileCastRemoteRouteData._fromState,
);

mixin $MobileCastRemoteRouteData on GoRouteData {
  static MobileCastRemoteRouteData _fromState(GoRouterState state) =>
      const MobileCastRemoteRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/cast/remote');

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

RouteBase get $mobileVideoPlayerRouteData => GoRouteData.$route(
  path: '/mobile/library/videos/:videoId/player',
  hasOverriddenOnExit: false,
  factory: $MobileVideoPlayerRouteData._fromState,
);

mixin $MobileVideoPlayerRouteData on GoRouteData {
  static MobileVideoPlayerRouteData _fromState(GoRouterState state) =>
      MobileVideoPlayerRouteData(
        videoId: int.parse(state.pathParameters['videoId']!),
        positionSeconds: _$convertMapValue(
          'position-seconds',
          state.uri.queryParameters,
          int.tryParse,
        ),
      );

  MobileVideoPlayerRouteData get _self => this as MobileVideoPlayerRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/library/videos/${Uri.encodeComponent(_self.videoId.toString())}/player',
    queryParams: {
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

RouteBase get $mobileVideoThumbnailRouteData => GoRouteData.$route(
  path: '/mobile/library/videos/:videoId/thumbnails',
  hasOverriddenOnExit: false,
  factory: $MobileVideoThumbnailRouteData._fromState,
);

mixin $MobileVideoThumbnailRouteData on GoRouteData {
  static MobileVideoThumbnailRouteData _fromState(GoRouterState state) =>
      MobileVideoThumbnailRouteData(
        videoId: int.parse(state.pathParameters['videoId']!),
      );

  MobileVideoThumbnailRouteData get _self =>
      this as MobileVideoThumbnailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/library/videos/${Uri.encodeComponent(_self.videoId.toString())}/thumbnails',
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

RouteBase get $mobileTagsRouteData => GoRouteData.$route(
  path: '/mobile/library/tags',
  hasOverriddenOnExit: false,
  factory: $MobileTagsRouteData._fromState,
);

mixin $MobileTagsRouteData on GoRouteData {
  static MobileTagsRouteData _fromState(GoRouterState state) =>
      const MobileTagsRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/library/tags');

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

RouteBase get $mobileTagMoviesRouteData => GoRouteData.$route(
  path: '/mobile/library/tags/:tagId',
  hasOverriddenOnExit: false,
  factory: $MobileTagMoviesRouteData._fromState,
);

mixin $MobileTagMoviesRouteData on GoRouteData {
  static MobileTagMoviesRouteData _fromState(GoRouterState state) =>
      MobileTagMoviesRouteData(
        tagId: int.parse(state.pathParameters['tagId']!),
      );

  MobileTagMoviesRouteData get _self => this as MobileTagMoviesRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/library/tags/${Uri.encodeComponent(_self.tagId.toString())}',
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

RouteBase get $mobileClipCollectionsRouteData => GoRouteData.$route(
  path: '/mobile/library/clip-collections',
  hasOverriddenOnExit: false,
  factory: $MobileClipCollectionsRouteData._fromState,
);

mixin $MobileClipCollectionsRouteData on GoRouteData {
  static MobileClipCollectionsRouteData _fromState(GoRouterState state) =>
      const MobileClipCollectionsRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/library/clip-collections');

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

RouteBase get $mobileClipCollectionDetailRouteData => GoRouteData.$route(
  path: '/mobile/library/clip-collections/:collectionId',
  hasOverriddenOnExit: false,
  factory: $MobileClipCollectionDetailRouteData._fromState,
);

mixin $MobileClipCollectionDetailRouteData on GoRouteData {
  static MobileClipCollectionDetailRouteData _fromState(GoRouterState state) =>
      MobileClipCollectionDetailRouteData(
        collectionId: int.parse(state.pathParameters['collectionId']!),
      );

  MobileClipCollectionDetailRouteData get _self =>
      this as MobileClipCollectionDetailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/library/clip-collections/${Uri.encodeComponent(_self.collectionId.toString())}',
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

RouteBase get $mobileMomentCollectionsRouteData => GoRouteData.$route(
  path: '/mobile/library/moment-collections',
  hasOverriddenOnExit: false,
  factory: $MobileMomentCollectionsRouteData._fromState,
);

mixin $MobileMomentCollectionsRouteData on GoRouteData {
  static MobileMomentCollectionsRouteData _fromState(GoRouterState state) =>
      const MobileMomentCollectionsRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/library/moment-collections');

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

RouteBase get $mobileMomentCollectionDetailRouteData => GoRouteData.$route(
  path: '/mobile/library/moment-collections/:collectionId',
  hasOverriddenOnExit: false,
  factory: $MobileMomentCollectionDetailRouteData._fromState,
);

mixin $MobileMomentCollectionDetailRouteData on GoRouteData {
  static MobileMomentCollectionDetailRouteData _fromState(
    GoRouterState state,
  ) => MobileMomentCollectionDetailRouteData(
    collectionId: int.parse(state.pathParameters['collectionId']!),
  );

  MobileMomentCollectionDetailRouteData get _self =>
      this as MobileMomentCollectionDetailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/library/moment-collections/${Uri.encodeComponent(_self.collectionId.toString())}',
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

RouteBase get $mobileClipCollectionPlayRouteData => GoRouteData.$route(
  path: '/mobile/library/clip-collections/:collectionId/play',
  hasOverriddenOnExit: false,
  factory: $MobileClipCollectionPlayRouteData._fromState,
);

mixin $MobileClipCollectionPlayRouteData on GoRouteData {
  static MobileClipCollectionPlayRouteData _fromState(GoRouterState state) =>
      MobileClipCollectionPlayRouteData(
        collectionId: int.parse(state.pathParameters['collectionId']!),
        startIndex:
            _$convertMapValue(
              'start-index',
              state.uri.queryParameters,
              int.parse,
            ) ??
            0,
      );

  MobileClipCollectionPlayRouteData get _self =>
      this as MobileClipCollectionPlayRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/library/clip-collections/${Uri.encodeComponent(_self.collectionId.toString())}/play',
    queryParams: {
      if (_self.startIndex != 0) 'start-index': _self.startIndex.toString(),
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

RouteBase get $mobileVideoCollectionsRouteData => GoRouteData.$route(
  path: '/mobile/library/video-collections',
  hasOverriddenOnExit: false,
  factory: $MobileVideoCollectionsRouteData._fromState,
);

mixin $MobileVideoCollectionsRouteData on GoRouteData {
  static MobileVideoCollectionsRouteData _fromState(GoRouterState state) =>
      const MobileVideoCollectionsRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/library/video-collections');

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

RouteBase get $mobileVideoCollectionDetailRouteData => GoRouteData.$route(
  path: '/mobile/library/video-collections/:collectionId',
  hasOverriddenOnExit: false,
  factory: $MobileVideoCollectionDetailRouteData._fromState,
);

mixin $MobileVideoCollectionDetailRouteData on GoRouteData {
  static MobileVideoCollectionDetailRouteData _fromState(GoRouterState state) =>
      MobileVideoCollectionDetailRouteData(
        collectionId: int.parse(state.pathParameters['collectionId']!),
      );

  MobileVideoCollectionDetailRouteData get _self =>
      this as MobileVideoCollectionDetailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/library/video-collections/${Uri.encodeComponent(_self.collectionId.toString())}',
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

RouteBase get $mobileVideoCollectionPlayRouteData => GoRouteData.$route(
  path: '/mobile/library/video-collections/:collectionId/play',
  hasOverriddenOnExit: false,
  factory: $MobileVideoCollectionPlayRouteData._fromState,
);

mixin $MobileVideoCollectionPlayRouteData on GoRouteData {
  static MobileVideoCollectionPlayRouteData _fromState(GoRouterState state) =>
      MobileVideoCollectionPlayRouteData(
        collectionId: int.parse(state.pathParameters['collectionId']!),
        startIndex:
            _$convertMapValue(
              'start-index',
              state.uri.queryParameters,
              int.parse,
            ) ??
            0,
        sort: state.uri.queryParameters['sort'],
      );

  MobileVideoCollectionPlayRouteData get _self =>
      this as MobileVideoCollectionPlayRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/library/video-collections/${Uri.encodeComponent(_self.collectionId.toString())}/play',
    queryParams: {
      if (_self.startIndex != 0) 'start-index': _self.startIndex.toString(),
      if (_self.sort != null) 'sort': _self.sort,
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
          hasOverriddenOnExit: false,
          factory: $MobileOverviewRouteData._fromState,
          routes: [
            GoRouteData.$route(
              path: 'discover/follow',
              hasOverriddenOnExit: false,
              parentNavigatorKey: MobileFollowRouteData.$parentNavigatorKey,
              factory: $MobileFollowRouteData._fromState,
            ),
            GoRouteData.$route(
              path: 'discover/movies',
              hasOverriddenOnExit: false,
              parentNavigatorKey:
                  MobileDiscoverMoviesRouteData.$parentNavigatorKey,
              factory: $MobileDiscoverMoviesRouteData._fromState,
            ),
            GoRouteData.$route(
              path: 'discover/moments',
              hasOverriddenOnExit: false,
              parentNavigatorKey:
                  MobileDiscoverMomentsRouteData.$parentNavigatorKey,
              factory: $MobileDiscoverMomentsRouteData._fromState,
            ),
            GoRouteData.$route(
              path: 'discover/hot-actress-releases',
              hasOverriddenOnExit: false,
              parentNavigatorKey:
                  MobileHotActressReleasesRouteData.$parentNavigatorKey,
              factory: $MobileHotActressReleasesRouteData._fromState,
            ),
            GoRouteData.$route(
              path: 'playlists/:playlistId',
              hasOverriddenOnExit: false,
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
          hasOverriddenOnExit: false,
          factory: $MobileMoviesRouteData._fromState,
          routes: [
            GoRouteData.$route(
              path: 'series/:seriesId',
              hasOverriddenOnExit: false,
              parentNavigatorKey:
                  MobileMovieSeriesRouteData.$parentNavigatorKey,
              factory: $MobileMovieSeriesRouteData._fromState,
            ),
            GoRouteData.$route(
              path: ':movieNumber',
              hasOverriddenOnExit: false,
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
          hasOverriddenOnExit: false,
          factory: $MobileActorsRouteData._fromState,
          routes: [
            GoRouteData.$route(
              path: ':actorId',
              hasOverriddenOnExit: false,
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
          hasOverriddenOnExit: false,
          factory: $MobileRankingsRouteData._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      navigatorKey: MobilePornboxBranchData.$navigatorKey,
      routes: [
        GoRouteData.$route(
          path: '/mobile/pornbox',
          hasOverriddenOnExit: false,
          factory: $MobilePornboxRouteData._fromState,
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

mixin $MobileFollowRouteData on GoRouteData {
  static MobileFollowRouteData _fromState(GoRouterState state) =>
      const MobileFollowRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/overview/discover/follow');

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

mixin $MobileDiscoverMoviesRouteData on GoRouteData {
  static MobileDiscoverMoviesRouteData _fromState(GoRouterState state) =>
      const MobileDiscoverMoviesRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/overview/discover/movies');

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

mixin $MobileDiscoverMomentsRouteData on GoRouteData {
  static MobileDiscoverMomentsRouteData _fromState(GoRouterState state) =>
      const MobileDiscoverMomentsRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/overview/discover/moments');

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

mixin $MobileHotActressReleasesRouteData on GoRouteData {
  static MobileHotActressReleasesRouteData _fromState(GoRouterState state) =>
      const MobileHotActressReleasesRouteData();

  @override
  String get location =>
      GoRouteData.$location('/mobile/overview/discover/hot-actress-releases');

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

mixin $MobileMovieSeriesRouteData on GoRouteData {
  static MobileMovieSeriesRouteData _fromState(GoRouterState state) =>
      MobileMovieSeriesRouteData(
        seriesId: int.parse(state.pathParameters['seriesId']!),
        seriesName: state.uri.queryParameters['series-name'],
      );

  MobileMovieSeriesRouteData get _self => this as MobileMovieSeriesRouteData;

  @override
  String get location => GoRouteData.$location(
    '/mobile/library/movies/series/${Uri.encodeComponent(_self.seriesId.toString())}',
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

mixin $MobilePornboxRouteData on GoRouteData {
  static MobilePornboxRouteData _fromState(GoRouterState state) =>
      const MobilePornboxRouteData();

  @override
  String get location => GoRouteData.$location('/mobile/pornbox');

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
