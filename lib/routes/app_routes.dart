import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_target.dart';

abstract final class DesktopRoutes {
  static AppRouteTarget login() =>
      const AppRouteTarget(id: AppRouteId.desktopLogin);

  static AppRouteTarget overview() =>
      const AppRouteTarget(id: AppRouteId.desktopOverview);

  static AppRouteTarget discover() =>
      const AppRouteTarget(id: AppRouteId.desktopDiscover);

  static AppRouteTarget movies() =>
      const AppRouteTarget(id: AppRouteId.desktopMovies);

  static AppRouteTarget actors() =>
      const AppRouteTarget(id: AppRouteId.desktopActors);

  static AppRouteTarget tags() =>
      const AppRouteTarget(id: AppRouteId.desktopTags);

  static AppRouteTarget moments() =>
      const AppRouteTarget(id: AppRouteId.desktopMoments);

  static AppRouteTarget playlists() =>
      const AppRouteTarget(id: AppRouteId.desktopPlaylists);

  static AppRouteTarget favorites() =>
      const AppRouteTarget(id: AppRouteId.desktopFavorites);

  static AppRouteTarget recentlyPlayed() =>
      const AppRouteTarget(id: AppRouteId.desktopRecentlyPlayed);

  static AppRouteTarget recentViews() =>
      const AppRouteTarget(id: AppRouteId.desktopRecentViews);

  static AppRouteTarget ratedMovies() =>
      const AppRouteTarget(id: AppRouteId.desktopRatedMovies);

  static AppRouteTarget clips() =>
      const AppRouteTarget(id: AppRouteId.desktopClips);

  static AppRouteTarget videos() =>
      const AppRouteTarget(id: AppRouteId.desktopVideos);

  static AppRouteTarget rankings() =>
      const AppRouteTarget(id: AppRouteId.desktopRankings);

  static AppRouteTarget activity() =>
      const AppRouteTarget(id: AppRouteId.desktopActivity);

  static AppRouteTarget downloadTasks({String? movieNumber}) => AppRouteTarget(
    id: AppRouteId.desktopDownloadTasks,
    queryParameters: {'downloadMovieNumber': movieNumber},
  );

  static AppRouteTarget media() =>
      const AppRouteTarget(id: AppRouteId.desktopMedia);

  static AppRouteTarget notifications() =>
      const AppRouteTarget(id: AppRouteId.desktopNotifications);

  static AppRouteTarget configuration() =>
      const AppRouteTarget(id: AppRouteId.desktopConfiguration);

  static AppRouteTarget mediaImport() =>
      const AppRouteTarget(id: AppRouteId.desktopMediaImport);

  static AppRouteTarget movieSubscriptions() =>
      const AppRouteTarget(id: AppRouteId.desktopMovieSubscriptions);

  static AppRouteTarget discoverMovies() =>
      const AppRouteTarget(id: AppRouteId.desktopDiscoverMovies);

  static AppRouteTarget discoverMoments() =>
      const AppRouteTarget(id: AppRouteId.desktopDiscoverMoments);

  static AppRouteTarget hotActressReleases() =>
      const AppRouteTarget(id: AppRouteId.desktopHotActressReleases);

  static AppRouteTarget follow() =>
      const AppRouteTarget(id: AppRouteId.desktopFollow);

  static AppRouteTarget latestMovies() =>
      const AppRouteTarget(id: AppRouteId.desktopLatestMovies);

  static AppRouteTarget recentlySubscribedMovies() =>
      const AppRouteTarget(id: AppRouteId.desktopRecentlySubscribedMovies);

  static AppRouteTarget videoCollections() =>
      const AppRouteTarget(id: AppRouteId.desktopVideoCollections);

  static AppRouteTarget systemDiagnostics() =>
      const AppRouteTarget(id: AppRouteId.desktopSystemDiagnostics);

  static AppRouteTarget search({
    String query = '',
    bool useOnlineSearch = false,
    String? fallbackPath,
  }) {
    final trimmed = query.trim();
    final queryParameters = <String, String?>{
      'useOnlineSearch': useOnlineSearch ? 'true' : null,
    };
    if (trimmed.isEmpty) {
      return AppRouteTarget(
        id: AppRouteId.desktopSearch,
        queryParameters: queryParameters,
        fallbackPath: fallbackPath,
      );
    }
    return AppRouteTarget(
      id: AppRouteId.desktopSearchQuery,
      pathParameters: {'query': trimmed},
      queryParameters: queryParameters,
      fallbackPath: fallbackPath,
    );
  }

  static AppRouteTarget imageSearch({
    String? draftId,
    String? currentMovieNumber,
    String currentMovieScope = 'all',
    String mode = 'image',
    String? fallbackPath,
  }) => AppRouteTarget(
    id: AppRouteId.desktopImageSearch,
    queryParameters: {
      'draftId': draftId,
      'currentMovieNumber': currentMovieNumber,
      'currentMovieScope': currentMovieScope,
      'mode': mode,
    },
    fallbackPath: fallbackPath,
  );

  static AppRouteTarget movieSeries({
    required int seriesId,
    String? seriesName,
    String? fallbackPath,
  }) => AppRouteTarget(
    id: AppRouteId.desktopMovieSeries,
    pathParameters: {'seriesId': '$seriesId'},
    queryParameters: {
      'seriesName': seriesName != null && seriesName.trim().isNotEmpty
          ? seriesName.trim()
          : null,
    },
    fallbackPath: fallbackPath,
  );

  static AppRouteTarget movieDetail({
    required String movieNumber,
    String? fallbackPath,
  }) => AppRouteTarget(
    id: AppRouteId.desktopMovieDetail,
    pathParameters: {'movieNumber': movieNumber},
    fallbackPath: fallbackPath,
  );

  static AppRouteTarget moviePlayer({
    required String movieNumber,
    int? mediaId,
    int? mergedLibraryId,
    int? positionSeconds,
    String? fallbackPath,
  }) => AppRouteTarget(
    id: AppRouteId.desktopMoviePlayer,
    pathParameters: {'movieNumber': movieNumber},
    queryParameters: {
      'mediaId': mediaId?.toString(),
      'mergedLibraryId': mergedLibraryId?.toString(),
      'positionSeconds': positionSeconds?.toString(),
    },
    fallbackPath: fallbackPath,
  );

  static AppRouteTarget playlistDetail({
    required int playlistId,
    String? fallbackPath,
  }) => AppRouteTarget(
    id: AppRouteId.desktopPlaylistDetail,
    pathParameters: {'playlistId': '$playlistId'},
    fallbackPath: fallbackPath,
  );

  static AppRouteTarget clipCollections() =>
      const AppRouteTarget(id: AppRouteId.desktopClipCollections);

  static AppRouteTarget clipCollectionDetail({required int collectionId}) =>
      AppRouteTarget(
        id: AppRouteId.desktopClipCollectionDetail,
        pathParameters: {'collectionId': '$collectionId'},
      );

  static AppRouteTarget clipCollectionPlay({
    required int collectionId,
    int startIndex = 0,
  }) => AppRouteTarget(
    id: AppRouteId.desktopClipCollectionPlay,
    pathParameters: {'collectionId': '$collectionId'},
    queryParameters: {'startIndex': startIndex.toString()},
  );

  static AppRouteTarget momentCollections() =>
      const AppRouteTarget(id: AppRouteId.desktopMomentCollections);

  static AppRouteTarget momentCollectionDetail({required int collectionId}) =>
      AppRouteTarget(
        id: AppRouteId.desktopMomentCollectionDetail,
        pathParameters: {'collectionId': '$collectionId'},
      );

  static AppRouteTarget actorDetail({
    required int actorId,
    String? fallbackPath,
  }) => AppRouteTarget(
    id: AppRouteId.desktopActorDetail,
    pathParameters: {'actorId': '$actorId'},
    fallbackPath: fallbackPath,
  );

  static AppRouteTarget tagMovies({required int tagId}) => AppRouteTarget(
    id: AppRouteId.desktopTagMovies,
    pathParameters: {'tagId': '$tagId'},
  );

  static AppRouteTarget videoCollectionDetail({required int collectionId}) =>
      AppRouteTarget(
        id: AppRouteId.desktopVideoCollectionDetail,
        pathParameters: {'collectionId': '$collectionId'},
      );

  static AppRouteTarget videoCollectionPlay({
    required int collectionId,
    int startIndex = 0,
    String? sort,
  }) => AppRouteTarget(
    id: AppRouteId.desktopVideoCollectionPlay,
    pathParameters: {'collectionId': '$collectionId'},
    queryParameters: {'startIndex': startIndex.toString(), 'sort': sort},
  );

  static AppRouteTarget videoThumbnail({required int videoId}) =>
      AppRouteTarget(
        id: AppRouteId.desktopVideoThumbnail,
        pathParameters: {'videoId': '$videoId'},
      );

  static AppRouteTarget videoPlayer({
    required int videoId,
    int? positionSeconds,
    String? fallbackPath,
  }) => AppRouteTarget(
    id: AppRouteId.desktopVideoPlayer,
    pathParameters: {'videoId': '$videoId'},
    queryParameters: {'positionSeconds': positionSeconds?.toString()},
    fallbackPath: fallbackPath,
  );

  static AppRouteTarget castRemote() =>
      const AppRouteTarget(id: AppRouteId.desktopCastRemote);
}

abstract final class MobileRoutes {
  static AppRouteTarget login() =>
      const AppRouteTarget(id: AppRouteId.mobileLogin);

  static AppRouteTarget overview() =>
      const AppRouteTarget(id: AppRouteId.mobileOverview);

  static AppRouteTarget movies() =>
      const AppRouteTarget(id: AppRouteId.mobileMovies);

  static AppRouteTarget actors() =>
      const AppRouteTarget(id: AppRouteId.mobileActors);

  static AppRouteTarget rankings() =>
      const AppRouteTarget(id: AppRouteId.mobileRankings);

  static AppRouteTarget pornbox() =>
      const AppRouteTarget(id: AppRouteId.mobilePornbox);

  static AppRouteTarget search({
    String query = '',
    bool useOnlineSearch = false,
    String? fallbackPath,
  }) {
    final trimmed = query.trim();
    final queryParameters = <String, String?>{
      'useOnlineSearch': useOnlineSearch ? 'true' : null,
    };
    if (trimmed.isEmpty) {
      return AppRouteTarget(
        id: AppRouteId.mobileSearch,
        queryParameters: queryParameters,
        fallbackPath: fallbackPath,
      );
    }
    return AppRouteTarget(
      id: AppRouteId.mobileSearchQuery,
      pathParameters: {'query': trimmed},
      queryParameters: queryParameters,
      fallbackPath: fallbackPath,
    );
  }

  static AppRouteTarget imageSearch({
    String? draftId,
    String? currentMovieNumber,
    String currentMovieScope = 'all',
    String mode = 'image',
    String? fallbackPath,
  }) => AppRouteTarget(
    id: AppRouteId.mobileImageSearch,
    queryParameters: {
      'draftId': draftId,
      'currentMovieNumber': currentMovieNumber,
      'currentMovieScope': currentMovieScope,
      'mode': mode,
    },
    fallbackPath: fallbackPath,
  );

  static AppRouteTarget settingsMediaLibraries() =>
      const AppRouteTarget(id: AppRouteId.mobileSettingsMediaLibraries);

  static AppRouteTarget settingsMediaTags() =>
      const AppRouteTarget(id: AppRouteId.mobileSettingsMediaTags);

  static AppRouteTarget settingsMetadataSources() =>
      const AppRouteTarget(id: AppRouteId.mobileSettingsMetadataSources);

  static AppRouteTarget settingsPlugins() =>
      const AppRouteTarget(id: AppRouteId.mobileSettingsPlugins);

  static AppRouteTarget settingsPluginMarket() =>
      const AppRouteTarget(id: AppRouteId.mobileSettingsPluginMarket);

  static AppRouteTarget latestMovies() =>
      const AppRouteTarget(id: AppRouteId.mobileLatestMovies);

  static AppRouteTarget recentlySubscribedMovies() =>
      const AppRouteTarget(id: AppRouteId.mobileRecentlySubscribedMovies);

  static AppRouteTarget recentViews() =>
      const AppRouteTarget(id: AppRouteId.mobileRecentViews);

  static AppRouteTarget favorites() =>
      const AppRouteTarget(id: AppRouteId.mobileFavorites);

  static AppRouteTarget recentlyPlayed() =>
      const AppRouteTarget(id: AppRouteId.mobileRecentlyPlayed);

  static AppRouteTarget ratedMovies() =>
      const AppRouteTarget(id: AppRouteId.mobileRatedMovies);

  static AppRouteTarget systemOverview() =>
      const AppRouteTarget(id: AppRouteId.mobileSystemOverview);

  static AppRouteTarget mediaImport() =>
      const AppRouteTarget(id: AppRouteId.mobileMediaImport);

  static AppRouteTarget activity() =>
      const AppRouteTarget(id: AppRouteId.mobileActivity);

  static AppRouteTarget downloadTasks({String? movieNumber}) => AppRouteTarget(
    id: AppRouteId.mobileDownloadTasks,
    queryParameters: {'downloadMovieNumber': movieNumber},
  );

  static AppRouteTarget notifications() =>
      const AppRouteTarget(id: AppRouteId.mobileNotifications);

  static AppRouteTarget mediaManagement() =>
      const AppRouteTarget(id: AppRouteId.mobileMediaManagement);

  static AppRouteTarget movieSubscriptions() =>
      const AppRouteTarget(id: AppRouteId.mobileMovieSubscriptions);

  static AppRouteTarget settingsDownloaders() =>
      const AppRouteTarget(id: AppRouteId.mobileSettingsDownloaders);

  static AppRouteTarget settingsIndexers() =>
      const AppRouteTarget(id: AppRouteId.mobileSettingsIndexers);

  static AppRouteTarget settingsDownloadSelection() =>
      const AppRouteTarget(id: AppRouteId.mobileSettingsDownloadSelection);

  static AppRouteTarget settingsSystemMaintenance() =>
      const AppRouteTarget(id: AppRouteId.mobileSettingsSystemMaintenance);

  static AppRouteTarget settingsExternalPlayer() =>
      const AppRouteTarget(id: AppRouteId.mobileSettingsExternalPlayer);

  static AppRouteTarget settingsAppearance() =>
      const AppRouteTarget(id: AppRouteId.mobileSettingsAppearance);

  static AppRouteTarget settingsAccountSecurity() =>
      const AppRouteTarget(id: AppRouteId.mobileSettingsAccountSecurity);

  static AppRouteTarget moviePlayer({
    required String movieNumber,
    int? mediaId,
    int? mergedLibraryId,
    int? positionSeconds,
  }) => AppRouteTarget(
    id: AppRouteId.mobileMoviePlayer,
    pathParameters: {'movieNumber': movieNumber},
    queryParameters: {
      'mediaId': mediaId?.toString(),
      'mergedLibraryId': mergedLibraryId?.toString(),
      'positionSeconds': positionSeconds?.toString(),
    },
  );

  static AppRouteTarget castRemote() =>
      const AppRouteTarget(id: AppRouteId.mobileCastRemote);

  static AppRouteTarget videoPlayer({
    required int videoId,
    int? positionSeconds,
  }) => AppRouteTarget(
    id: AppRouteId.mobileVideoPlayer,
    pathParameters: {'videoId': '$videoId'},
    queryParameters: {'positionSeconds': positionSeconds?.toString()},
  );

  static AppRouteTarget videoThumbnail({required int videoId}) =>
      AppRouteTarget(
        id: AppRouteId.mobileVideoThumbnail,
        pathParameters: {'videoId': '$videoId'},
      );

  static AppRouteTarget tags() =>
      const AppRouteTarget(id: AppRouteId.mobileTags);

  static AppRouteTarget tagMovies({required int tagId}) => AppRouteTarget(
    id: AppRouteId.mobileTagMovies,
    pathParameters: {'tagId': '$tagId'},
  );

  static AppRouteTarget clipCollections() =>
      const AppRouteTarget(id: AppRouteId.mobileClipCollections);

  static AppRouteTarget clipCollectionDetail({required int collectionId}) =>
      AppRouteTarget(
        id: AppRouteId.mobileClipCollectionDetail,
        pathParameters: {'collectionId': '$collectionId'},
      );

  static AppRouteTarget clipCollectionPlay({
    required int collectionId,
    int startIndex = 0,
  }) => AppRouteTarget(
    id: AppRouteId.mobileClipCollectionPlay,
    pathParameters: {'collectionId': '$collectionId'},
    queryParameters: {'startIndex': startIndex.toString()},
  );

  static AppRouteTarget momentCollections() =>
      const AppRouteTarget(id: AppRouteId.mobileMomentCollections);

  static AppRouteTarget momentCollectionDetail({required int collectionId}) =>
      AppRouteTarget(
        id: AppRouteId.mobileMomentCollectionDetail,
        pathParameters: {'collectionId': '$collectionId'},
      );

  static AppRouteTarget videoCollections() =>
      const AppRouteTarget(id: AppRouteId.mobileVideoCollections);

  static AppRouteTarget videoCollectionDetail({required int collectionId}) =>
      AppRouteTarget(
        id: AppRouteId.mobileVideoCollectionDetail,
        pathParameters: {'collectionId': '$collectionId'},
      );

  static AppRouteTarget videoCollectionPlay({
    required int collectionId,
    int startIndex = 0,
    String? sort,
  }) => AppRouteTarget(
    id: AppRouteId.mobileVideoCollectionPlay,
    pathParameters: {'collectionId': '$collectionId'},
    queryParameters: {'startIndex': startIndex.toString(), 'sort': sort},
  );

  static AppRouteTarget follow() =>
      const AppRouteTarget(id: AppRouteId.mobileFollow);

  static AppRouteTarget discoverMovies() =>
      const AppRouteTarget(id: AppRouteId.mobileDiscoverMovies);

  static AppRouteTarget discoverMoments() =>
      const AppRouteTarget(id: AppRouteId.mobileDiscoverMoments);

  static AppRouteTarget hotActressReleases() =>
      const AppRouteTarget(id: AppRouteId.mobileHotActressReleases);

  static AppRouteTarget playlistDetail({required int playlistId}) =>
      AppRouteTarget(
        id: AppRouteId.mobilePlaylistDetail,
        pathParameters: {'playlistId': '$playlistId'},
      );

  static AppRouteTarget movieSeries({
    required int seriesId,
    String? seriesName,
    String? fallbackPath,
  }) => AppRouteTarget(
    id: AppRouteId.mobileMovieSeries,
    pathParameters: {'seriesId': '$seriesId'},
    queryParameters: {
      'seriesName': seriesName != null && seriesName.trim().isNotEmpty
          ? seriesName.trim()
          : null,
    },
    fallbackPath: fallbackPath,
  );

  static AppRouteTarget movieDetail({
    required String movieNumber,
    String? fallbackPath,
  }) => AppRouteTarget(
    id: AppRouteId.mobileMovieDetail,
    pathParameters: {'movieNumber': movieNumber},
    fallbackPath: fallbackPath,
  );

  static AppRouteTarget actorDetail({
    required int actorId,
    String? fallbackPath,
  }) => AppRouteTarget(
    id: AppRouteId.mobileActorDetail,
    pathParameters: {'actorId': '$actorId'},
    fallbackPath: fallbackPath,
  );
}
