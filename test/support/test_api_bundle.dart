import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_api.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';
import 'package:sakuramedia/features/configuration/data/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/discovery/data/discovery_api.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_reviews_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';

import 'fake_http_client_adapter.dart';

class TestApiBundle {
  TestApiBundle({
    required this.apiClient,
    required this.accountApi,
    required this.activityApi,
    required this.activityEventStreamClient,
    required this.actorsApi,
    required this.authApi,
    required this.collectionNumberFeaturesApi,
    required this.downloadClientsApi,
    required this.discoveryApi,
    required this.downloadsApi,
    required this.indexerSettingsApi,
    required this.mediaLibrariesApi,
    required this.metadataProviderLicenseApi,
    required this.movieDescTranslationSettingsApi,
    required this.statusApi,
    required this.moviesApi,
    required this.playlistsApi,
    required this.rankingsApi,
    required this.hotReviewsApi,
    required this.adapter,
  });

  final ApiClient apiClient;
  final AccountApi accountApi;
  final ActivityApi activityApi;
  final ActivityEventStreamClient activityEventStreamClient;
  final ActorsApi actorsApi;
  final AuthApi authApi;
  final CollectionNumberFeaturesApi collectionNumberFeaturesApi;
  final DownloadClientsApi downloadClientsApi;
  final DiscoveryApi discoveryApi;
  final DownloadsApi downloadsApi;
  final IndexerSettingsApi indexerSettingsApi;
  final MediaLibrariesApi mediaLibrariesApi;
  final MetadataProviderLicenseApi metadataProviderLicenseApi;
  final MovieDescTranslationSettingsApi movieDescTranslationSettingsApi;
  final StatusApi statusApi;
  final MoviesApi moviesApi;
  final PlaylistsApi playlistsApi;
  final RankingsApi rankingsApi;
  final HotReviewsApi hotReviewsApi;
  final FakeHttpClientAdapter adapter;

  void dispose() {
    activityEventStreamClient.dispose();
    apiClient.dispose();
  }
}

Future<TestApiBundle> createTestApiBundle(SessionStore sessionStore) async {
  final apiClient = ApiClient(sessionStore: sessionStore);
  final activityEventStreamClient = createActivityEventStreamClient(
    apiClient: apiClient,
    sessionStore: sessionStore,
  );
  final adapter = FakeHttpClientAdapter();
  apiClient.rawDio.httpClientAdapter = adapter;
  apiClient.rawRefreshDio.httpClientAdapter = adapter;

  return TestApiBundle(
    apiClient: apiClient,
    accountApi: AccountApi(apiClient: apiClient),
    activityApi: ActivityApi(
      apiClient: apiClient,
      streamClient: activityEventStreamClient,
    ),
    activityEventStreamClient: activityEventStreamClient,
    actorsApi: ActorsApi(apiClient: apiClient),
    authApi: AuthApi(apiClient: apiClient, sessionStore: sessionStore),
    collectionNumberFeaturesApi: CollectionNumberFeaturesApi(
      apiClient: apiClient,
    ),
    downloadClientsApi: DownloadClientsApi(apiClient: apiClient),
    discoveryApi: DiscoveryApi(apiClient: apiClient),
    downloadsApi: DownloadsApi(apiClient: apiClient),
    indexerSettingsApi: IndexerSettingsApi(apiClient: apiClient),
    mediaLibrariesApi: MediaLibrariesApi(apiClient: apiClient),
    metadataProviderLicenseApi: MetadataProviderLicenseApi(
      apiClient: apiClient,
    ),
    movieDescTranslationSettingsApi: MovieDescTranslationSettingsApi(
      apiClient: apiClient,
    ),
    statusApi: StatusApi(apiClient: apiClient),
    moviesApi: MoviesApi(apiClient: apiClient),
    playlistsApi: PlaylistsApi(apiClient: apiClient),
    rankingsApi: RankingsApi(apiClient: apiClient),
    hotReviewsApi: HotReviewsApi(apiClient: apiClient),
    adapter: adapter,
  );
}
