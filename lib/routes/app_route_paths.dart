import 'package:sakuramedia/app/app_platform.dart';

const String desktopOverviewPath = '/desktop/overview';
const String desktopDiscoverPath = '/desktop/library/discover';
const String desktopDiscoverMoviesPath = '$desktopDiscoverPath/movies';
const String desktopDiscoverMomentsPath = '$desktopDiscoverPath/moments';
const String desktopHotActressReleasesPath =
    '$desktopDiscoverPath/hot-actress-releases';
const String desktopFollowPath = '/desktop/library/follow';
const String desktopSearchPath = '/desktop/search';
const String desktopImageSearchPath = '/desktop/search/image';
const String desktopMoviesPath = '/desktop/library/movies';
const String desktopMovieSeriesPathPrefix = '$desktopMoviesPath/series';
const String desktopActorsPath = '/desktop/library/actors';
const String desktopTagsPath = '/desktop/library/tags';
const String desktopMomentsPath = '/desktop/library/moments';
const String desktopPlaylistsPath = '/desktop/library/playlists';
const String desktopClipsPath = '/desktop/library/clips';
const String desktopClipCollectionsPath = '/desktop/library/clip-collections';
const String desktopVideosPath = '/desktop/library/videos';
const String desktopVideoCollectionsPath = '/desktop/library/video-collections';
const String desktopRankingsPath = '/desktop/library/rankings';
const String desktopActivityPath = '/desktop/system/activity';
const String desktopMediaPath = '/desktop/system/media';
const String desktopNotificationsPath = '/desktop/system/notifications';
const String desktopConfigurationPath = '/desktop/system/configuration';
const String desktopMediaImportPath = '/desktop/system/media-import';
const String desktopMovieSubscriptionsPath =
    '/desktop/system/movie-subscriptions';
const String desktopSystemDiagnosticsPath = '/desktop/system/diagnostics';

const String mobileOverviewPath = '/mobile/overview';
const String mobileFollowPath = '$mobileOverviewPath/discover/follow';
const String mobileDiscoverMoviesPath = '$mobileOverviewPath/discover/movies';
const String mobileDiscoverMomentsPath = '$mobileOverviewPath/discover/moments';
const String mobileHotActressReleasesPath =
    '$mobileOverviewPath/discover/hot-actress-releases';
const String mobileSystemOverviewPath = '/mobile/system/overview';
const String mobileActivityPath = '/mobile/system/activity';
const String mobileNotificationsPath = '/mobile/system/notifications';
const String mobileMediaManagementPath = '/mobile/system/media';
const String mobileMediaImportPath = '/mobile/system/media-import';
const String mobileSearchPath = '/mobile/search';
const String mobileImageSearchPath = '/mobile/search/image';
const String mobileMoviesPath = '/mobile/library/movies';
const String mobileMovieSeriesPathPrefix = '$mobileMoviesPath/series';
const String mobileActorsPath = '/mobile/library/actors';
const String mobileTagsPath = '/mobile/library/tags';
const String mobileClipCollectionsPath = '/mobile/library/clip-collections';
const String mobileVideoCollectionsPath = '/mobile/library/video-collections';
const String mobileRankingsPath = '/mobile/rankings';
const String mobilePornboxPath = '/mobile/pornbox';
const String mobileSettingsMediaLibrariesPath =
    '/mobile/settings/media-libraries';
const String mobileSettingsPluginsPath = '/mobile/settings/plugins';
const String mobileSettingsDownloadersPath = '/mobile/settings/downloaders';
const String mobileSettingsIndexersPath = '/mobile/settings/indexers';
const String mobileSettingsPlaylistsPath = '/mobile/settings/playlists';
const String mobileSettingsSystemMaintenancePath =
    '/mobile/settings/system-maintenance';
const String mobileSettingsExternalPlayerPath =
    '/mobile/settings/external-player';
const String mobileSettingsUsernamePath = '/mobile/settings/username';
const String mobileSettingsPasswordPath = '/mobile/settings/password';

const String loginPath = '/login';

@Deprecated('请改用 typed route，例如 DesktopMovieDetailRoute。')
String buildDesktopMovieDetailRoutePath(String movieNumber) {
  return '$desktopMoviesPath/${Uri.encodeComponent(movieNumber)}';
}

@Deprecated('请改用 typed route，例如 MobileMovieDetailRoute。')
String buildMobileMovieDetailRoutePath(String movieNumber) {
  return '$mobileMoviesPath/${Uri.encodeComponent(movieNumber)}';
}

@Deprecated('请改用 typed route，例如 DesktopPlaylistDetailRoute。')
String buildDesktopPlaylistDetailRoutePath(int playlistId) {
  return '$desktopPlaylistsPath/$playlistId';
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
  }
}
