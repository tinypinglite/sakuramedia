import 'package:sakuramedia/app/app_platform.dart';

const String desktopOverviewPath = '/desktop/overview';
const String desktopDiscoverPath = '/desktop/library/discover';
const String desktopDiscoverMoviesPath = '$desktopDiscoverPath/movies';
const String desktopDiscoverMomentsPath = '$desktopDiscoverPath/moments';
const String desktopFollowPath = '/desktop/library/follow';
const String desktopSearchPath = '/desktop/search';
const String desktopImageSearchPath = '/desktop/search/image';
const String desktopMoviesPath = '/desktop/library/movies';
const String desktopMovieSeriesPathPrefix = '$desktopMoviesPath/series';
const String desktopActorsPath = '/desktop/library/actors';
const String desktopMomentsPath = '/desktop/library/moments';
const String desktopPlaylistsPath = '/desktop/library/playlists';
const String desktopRankingsPath = '/desktop/library/rankings';
const String desktopHotReviewsPath = '/desktop/library/hot-reviews';
const String desktopActivityPath = '/desktop/system/activity';
const String desktopConfigurationPath = '/desktop/system/configuration';

const String mobileOverviewPath = '/mobile/overview';
const String mobileDiscoverMoviesPath = '$mobileOverviewPath/discover/movies';
const String mobileDiscoverMomentsPath = '$mobileOverviewPath/discover/moments';
const String mobilePlaylistDetailPathPrefix = '$mobileOverviewPath/playlists';
const String mobileSystemOverviewPath = '/mobile/system/overview';
const String mobileSearchPath = '/mobile/search';
const String mobileImageSearchPath = '/mobile/search/image';
const String mobileMoviesPath = '/mobile/library/movies';
const String mobileMovieSeriesPathPrefix = '$mobileMoviesPath/series';
const String mobileActorsPath = '/mobile/library/actors';
const String mobileRankingsPath = '/mobile/rankings';
const String mobileSettingsDataSourcesPath = '/mobile/settings/data-sources';
const String mobileSettingsMediaLibrariesPath =
    '/mobile/settings/media-libraries';
const String mobileSettingsDownloadersPath = '/mobile/settings/downloaders';
const String mobileSettingsIndexersPath = '/mobile/settings/indexers';
const String mobileSettingsLlmPath = '/mobile/settings/llm';
const String mobileSettingsPlaylistsPath = '/mobile/settings/playlists';
const String mobileSettingsUsernamePath = '/mobile/settings/username';
const String mobileSettingsPasswordPath = '/mobile/settings/password';

const String loginPath = '/login';

@Deprecated('请改用 typed route，例如 DesktopSearchRoute / MobileSearchRoute。')
String buildDesktopSearchRoutePath(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return desktopSearchPath;
  }
  return '$desktopSearchPath/${Uri.encodeComponent(trimmed)}';
}

@Deprecated('请改用 typed route，例如 DesktopSearchRoute / MobileSearchRoute。')
String buildMobileSearchRoutePath(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return mobileSearchPath;
  }
  return '$mobileSearchPath/${Uri.encodeComponent(trimmed)}';
}

@Deprecated('请改用 typed route，例如 MobilePlaylistDetailRoute。')
String buildMobilePlaylistDetailRoutePath(int playlistId) {
  return '$mobilePlaylistDetailPathPrefix/$playlistId';
}

@Deprecated('请改用 typed route，例如 DesktopMovieDetailRoute。')
String buildDesktopMovieDetailRoutePath(String movieNumber) {
  return '$desktopMoviesPath/${Uri.encodeComponent(movieNumber)}';
}

@Deprecated('请改用 typed route，例如 MobileMovieDetailRoute。')
String buildMobileMovieDetailRoutePath(String movieNumber) {
  return '$mobileMoviesPath/${Uri.encodeComponent(movieNumber)}';
}

@Deprecated('请改用 typed route，例如 DesktopActorDetailRoute。')
String buildDesktopActorDetailRoutePath(int actorId) {
  return '$desktopActorsPath/$actorId';
}

@Deprecated('请改用 typed route，例如 DesktopPlaylistDetailRoute。')
String buildDesktopPlaylistDetailRoutePath(int playlistId) {
  return '$desktopPlaylistsPath/$playlistId';
}

@Deprecated('请改用 typed route，例如 MobileMoviePlayerRoute。')
String buildMobileMoviePlayerRoutePath(
  String movieNumber, {
  int? mediaId,
  int? positionSeconds,
}) {
  final queryParameters = <String, String>{};
  if (mediaId != null) {
    queryParameters['mediaId'] = '$mediaId';
  }
  if (positionSeconds != null) {
    queryParameters['positionSeconds'] = '$positionSeconds';
  }
  final path = Uri(
    path: '$mobileMoviesPath/${Uri.encodeComponent(movieNumber)}/player',
    queryParameters: queryParameters.isEmpty ? null : queryParameters,
  );
  return path.toString();
}

@Deprecated('请改用 typed route，例如 MobileActorDetailRoute。')
String buildMobileActorDetailRoutePath(int actorId) {
  return '$mobileActorsPath/$actorId';
}

@Deprecated('请改用 typed route，例如 DesktopMoviePlayerRoute。')
String buildDesktopMoviePlayerRoutePath(
  String movieNumber, {
  int? mediaId,
  int? positionSeconds,
}) {
  final queryParameters = <String, String>{};
  if (mediaId != null) {
    queryParameters['mediaId'] = '$mediaId';
  }
  if (positionSeconds != null) {
    queryParameters['positionSeconds'] = '$positionSeconds';
  }
  final path = Uri(
    path: '/desktop/library/movies/${Uri.encodeComponent(movieNumber)}/player',
    queryParameters: queryParameters.isEmpty ? null : queryParameters,
  );
  return path.toString();
}

String overviewPathForPlatform(AppPlatform platform) {
  switch (platform) {
    case AppPlatform.desktop:
      return desktopOverviewPath;
    case AppPlatform.mobile:
      return mobileOverviewPath;
    case AppPlatform.web:
      return desktopOverviewPath;
  }
}
