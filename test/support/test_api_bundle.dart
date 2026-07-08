import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/configuration/data/config_api.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/discovery/data/discovery_api.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_reviews_api.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/playlists/data/api/playlists_api.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/videos/data/api/video_imports_api.dart';

import 'fake_http_client_adapter.dart';
import 'in_memory_credential_store.dart';

class TestApiBundle {
  TestApiBundle({
    required this.apiClient,
    required this.accountApi,
    required this.activityApi,
    required this.activityEventStreamClient,
    required this.actorsApi,
    required this.authApi,
    required this.clipsApi,
    required this.configApi,
    required this.downloadClientsApi,
    required this.discoveryApi,
    required this.downloadsApi,
    required this.indexerSettingsApi,
    required this.mediaApi,
    required this.mediaImportApi,
    required this.mediaLibrariesApi,
    required this.movieDescTranslationSettingsApi,
    required this.statusApi,
    required this.moviesApi,
    required this.playlistsApi,
    required this.rankingsApi,
    required this.hotReviewsApi,
    required this.videoImportsApi,
    required this.adapter,
  });

  final ApiClient apiClient;
  final AccountApi accountApi;
  final ActivityApi activityApi;
  final ActivityEventStreamClient activityEventStreamClient;
  final ActorsApi actorsApi;
  final AuthApi authApi;
  final ClipsApi clipsApi;
  final ConfigApi configApi;
  final DownloadClientsApi downloadClientsApi;
  final DiscoveryApi discoveryApi;
  final DownloadsApi downloadsApi;
  final IndexerSettingsApi indexerSettingsApi;
  final MediaApi mediaApi;
  final MediaImportApi mediaImportApi;
  final MediaLibrariesApi mediaLibrariesApi;
  final MovieDescTranslationSettingsApi movieDescTranslationSettingsApi;
  final StatusApi statusApi;
  final MoviesApi moviesApi;
  final PlaylistsApi playlistsApi;
  final RankingsApi rankingsApi;
  final HotReviewsApi hotReviewsApi;
  final VideoImportsApi videoImportsApi;
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

  // 影片详情页 init 会发 GET /media-clips 拉该片切片(列表非关键),
  // 默认给空兜底,各用例无需逐个 enqueue;需要校验该端点的用例可显式 enqueue 覆盖。
  adapter.setFallbackJson(
    method: 'GET',
    path: '/media-clips',
    body: const <String, dynamic>{'items': <dynamic>[], 'total': 0},
  );

  return TestApiBundle(
    apiClient: apiClient,
    accountApi: AccountApi(apiClient: apiClient),
    activityApi: ActivityApi(
      apiClient: apiClient,
      streamClient: activityEventStreamClient,
    ),
    activityEventStreamClient: activityEventStreamClient,
    actorsApi: ActorsApi(apiClient: apiClient),
    authApi: AuthApi(
      apiClient: apiClient,
      sessionStore: sessionStore,
      credentialStore: InMemoryCredentialStore(),
    ),
    clipsApi: ClipsApi(apiClient: apiClient),
    configApi: ConfigApi(apiClient: apiClient),
    downloadClientsApi: DownloadClientsApi(apiClient: apiClient),
    discoveryApi: DiscoveryApi(apiClient: apiClient),
    downloadsApi: DownloadsApi(apiClient: apiClient),
    indexerSettingsApi: IndexerSettingsApi(apiClient: apiClient),
    mediaApi: MediaApi(apiClient: apiClient),
    mediaImportApi: MediaImportApi(apiClient: apiClient),
    mediaLibrariesApi: MediaLibrariesApi(apiClient: apiClient),
    movieDescTranslationSettingsApi: MovieDescTranslationSettingsApi(
      apiClient: apiClient,
    ),
    statusApi: StatusApi(apiClient: apiClient),
    moviesApi: MoviesApi(apiClient: apiClient),
    playlistsApi: PlaylistsApi(apiClient: apiClient),
    rankingsApi: RankingsApi(apiClient: apiClient),
    hotReviewsApi: HotReviewsApi(apiClient: apiClient),
    videoImportsApi: VideoImportsApi(apiClient: apiClient),
    adapter: adapter,
  );
}
