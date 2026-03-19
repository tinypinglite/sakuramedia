import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_api.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';

import 'fake_http_client_adapter.dart';

class TestApiBundle {
  TestApiBundle({
    required this.apiClient,
    required this.accountApi,
    required this.actorsApi,
    required this.authApi,
    required this.collectionNumberFeaturesApi,
    required this.downloadClientsApi,
    required this.downloadsApi,
    required this.indexerSettingsApi,
    required this.mediaLibrariesApi,
    required this.statusApi,
    required this.moviesApi,
    required this.playlistsApi,
    required this.rankingsApi,
    required this.adapter,
  });

  final ApiClient apiClient;
  final AccountApi accountApi;
  final ActorsApi actorsApi;
  final AuthApi authApi;
  final CollectionNumberFeaturesApi collectionNumberFeaturesApi;
  final DownloadClientsApi downloadClientsApi;
  final DownloadsApi downloadsApi;
  final IndexerSettingsApi indexerSettingsApi;
  final MediaLibrariesApi mediaLibrariesApi;
  final StatusApi statusApi;
  final MoviesApi moviesApi;
  final PlaylistsApi playlistsApi;
  final RankingsApi rankingsApi;
  final FakeHttpClientAdapter adapter;

  void dispose() {
    apiClient.dispose();
  }
}

Future<TestApiBundle> createTestApiBundle(SessionStore sessionStore) async {
  final apiClient = ApiClient(sessionStore: sessionStore);
  final adapter = FakeHttpClientAdapter();
  apiClient.rawDio.httpClientAdapter = adapter;
  apiClient.rawRefreshDio.httpClientAdapter = adapter;

  return TestApiBundle(
    apiClient: apiClient,
    accountApi: AccountApi(apiClient: apiClient),
    actorsApi: ActorsApi(apiClient: apiClient),
    authApi: AuthApi(apiClient: apiClient, sessionStore: sessionStore),
    collectionNumberFeaturesApi: CollectionNumberFeaturesApi(
      apiClient: apiClient,
    ),
    downloadClientsApi: DownloadClientsApi(apiClient: apiClient),
    downloadsApi: DownloadsApi(apiClient: apiClient),
    indexerSettingsApi: IndexerSettingsApi(apiClient: apiClient),
    mediaLibrariesApi: MediaLibrariesApi(apiClient: apiClient),
    statusApi: StatusApi(apiClient: apiClient),
    moviesApi: MoviesApi(apiClient: apiClient),
    playlistsApi: PlaylistsApi(apiClient: apiClient),
    rankingsApi: RankingsApi(apiClient: apiClient),
    adapter: adapter,
  );
}
