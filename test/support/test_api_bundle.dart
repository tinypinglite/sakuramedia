import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/core/session/credential_store.dart';
import 'package:sakuramedia/core/session/providers/credential_store_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_api_provider.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_api_provider.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/features/auth/presentation/providers/auth_api_provider.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/features/configuration/data/api/config_api.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/api/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/config_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_api_provider.dart';
import 'package:sakuramedia/features/discovery/data/discovery_api.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_api_provider.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_api_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_draft_store_provider.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/media_import_api_provider.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/playlists/data/api/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/rankings_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
import 'package:sakuramedia/features/shared/presentation/providers/collection_playback_handoff_provider.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';
import 'package:sakuramedia/features/subscriptions/data/api/movie_subscriptions_api.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscriptions_api_provider.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tags_api_provider.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';

import 'fake_http_client_adapter.dart';
import 'in_memory_credential_store.dart';

class TestApiBundle {
  TestApiBundle({
    required this.sessionStore,
    required this.credentialStore,
    required this.apiClient,
    required this.accountApi,
    required this.activityApi,
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
    required this.statusApi,
    required this.moviesApi,
    required this.movieSubscriptionsApi,
    required this.playlistsApi,
    required this.rankingsApi,
    required this.tagsApi,
    required this.videosApi,
    required this.videoCollectionsApi,
    required this.clipCollectionsApi,
    required this.imageSearchApi,
    required this.adapter,
  });

  final SessionStore sessionStore;
  final CredentialStore credentialStore;
  final ApiClient apiClient;
  final AccountApi accountApi;
  final ActivityApi activityApi;
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
  final StatusApi statusApi;
  final MoviesApi moviesApi;
  final MovieSubscriptionsApi movieSubscriptionsApi;
  final PlaylistsApi playlistsApi;
  final RankingsApi rankingsApi;
  final TagsApi tagsApi;
  final VideosApi videosApi;
  final VideoCollectionsApi videoCollectionsApi;
  final ClipCollectionsApi clipCollectionsApi;
  final ImageSearchApi imageSearchApi;
  final FakeHttpClientAdapter adapter;

  /// 合集详情 → 连播页交接信箱的默认实例——连播页 `ref.read` 取交接数据时
  /// 测试树里必须有 override 才能落笔;无副作用,恒定注入。
  final CollectionPlaybackHandoff collectionPlaybackHandoff =
      CollectionPlaybackHandoff();

  // 外部播放器偏好已迁 keepAlive AsyncNotifier
  // (externalPlayerPreferenceProvider),直接读 SharedPreferences——需要
  // 预置选择的测试用 `SharedPreferences.setMockInitialValues({...})`,
  // 无 mock 时读盘异常被吞、降级为「未选择」,无需注入。

  // 桌面壳侧边栏折叠状态已迁 @riverpod bool Notifier
  // (appShellSidebarCollapsedProvider),默认展开无需注入,不再持实例。

  /// 图搜草稿仓默认实例——图搜启动器经 Riverpod 容器写入草稿，测试树里必须有
  /// override 才能落笔。需要自持实例（预置草稿）的测试仍可传参覆盖。
  final ImageSearchDraftStore defaultImageSearchDraftStore =
      ImageSearchDraftStore();

  // 四个跨页 mutation 广播（movie subscription / movie collection type / clip
  // mutation / video mutation）已在批 8 收敛为 Riverpod class Notifier
  // (`xxxEventsProvider`)；本身 keepAlive 常驻、自持 StreamController，
  // **不再需要 bundle 注入实例**。测试里要发广播直接
  // `container.read(xxxEventsProvider.notifier).reportXxx(...)`；要听广播
  // 直接 `container.listen(xxxEventsProvider, ...)`。

  /// 一次性产出全部 Riverpod 桥 provider 的 overrides——widget 测试给
  /// `ProviderScope(overrides: bundle.riverpodOverrides(...))` 用，
  /// 与 `lib/app/app.dart` 组合根的 override 清单同构。
  ///
  /// 非 API 的全局对象（页面缓存 / 图搜草稿仓）按需传入；不传则不 override，
  /// 对应桥保持 UnimplementedError（用不到就不会触发）。
  List<Override> riverpodOverrides({
    RiverpodPageCache? pageStateCache,
    ImageSearchDraftStore? imageSearchDraftStore,
    CollectionPlaybackHandoff? collectionPlaybackHandoff,
    // 允许单测换成 fake 子类（如刷新必败的 API），默认用 bundle 实例。
    MediaLibrariesApi? mediaLibrariesApi,
    DownloadClientsApi? downloadClientsApi,
    IndexerSettingsApi? indexerSettingsApi,
    ActivityApi? activityApi,
  }) {
    return <Override>[
      apiClientProvider.overrideWithValue(apiClient),
      sessionStoreProvider.overrideWithValue(sessionStore),
      credentialStoreProvider.overrideWithValue(credentialStore),
      accountApiProvider.overrideWithValue(accountApi),
      activityApiProvider.overrideWithValue(activityApi ?? this.activityApi),
      actorsApiProvider.overrideWithValue(actorsApi),
      authApiProvider.overrideWithValue(authApi),
      clipsApiProvider.overrideWithValue(clipsApi),
      clipCollectionsApiProvider.overrideWithValue(clipCollectionsApi),
      configApiProvider.overrideWithValue(configApi),
      discoveryApiProvider.overrideWithValue(discoveryApi),
      downloadsApiProvider.overrideWithValue(downloadsApi),
      downloadClientsApiProvider.overrideWithValue(
        downloadClientsApi ?? this.downloadClientsApi,
      ),
      imageSearchApiProvider.overrideWithValue(imageSearchApi),
      indexerSettingsApiProvider.overrideWithValue(
        indexerSettingsApi ?? this.indexerSettingsApi,
      ),
      mediaApiProvider.overrideWithValue(mediaApi),
      mediaImportApiProvider.overrideWithValue(mediaImportApi),
      mediaLibrariesApiProvider.overrideWithValue(
        mediaLibrariesApi ?? this.mediaLibrariesApi,
      ),
      moviesApiProvider.overrideWithValue(moviesApi),
      movieSubscriptionsApiProvider.overrideWithValue(movieSubscriptionsApi),
      playlistsApiProvider.overrideWithValue(playlistsApi),
      rankingsApiProvider.overrideWithValue(rankingsApi),
      statusApiProvider.overrideWithValue(statusApi),
      tagsApiProvider.overrideWithValue(tagsApi),
      videosApiProvider.overrideWithValue(videosApi),
      videoCollectionsApiProvider.overrideWithValue(videoCollectionsApi),
      if (pageStateCache != null)
        riverpodPageCacheProvider.overrideWithValue(pageStateCache),
      imageSearchDraftStoreProvider.overrideWithValue(
        imageSearchDraftStore ?? defaultImageSearchDraftStore,
      ),
      collectionPlaybackHandoffProvider.overrideWithValue(
        collectionPlaybackHandoff ?? this.collectionPlaybackHandoff,
      ),
    ];
  }

  void dispose() {
    apiClient.dispose();
  }
}

Future<TestApiBundle> createTestApiBundle(SessionStore sessionStore) async {
  final credentialStore = InMemoryCredentialStore();
  final apiClient = ApiClient(sessionStore: sessionStore);
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
    sessionStore: sessionStore,
    credentialStore: credentialStore,
    apiClient: apiClient,
    accountApi: AccountApi(apiClient: apiClient),
    activityApi: ActivityApi(apiClient: apiClient),
    actorsApi: ActorsApi(apiClient: apiClient),
    authApi: AuthApi(
      apiClient: apiClient,
      sessionStore: sessionStore,
      credentialStore: credentialStore,
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
    statusApi: StatusApi(apiClient: apiClient),
    moviesApi: MoviesApi(apiClient: apiClient),
    movieSubscriptionsApi: MovieSubscriptionsApi(apiClient: apiClient),
    playlistsApi: PlaylistsApi(apiClient: apiClient),
    rankingsApi: RankingsApi(apiClient: apiClient),
    tagsApi: TagsApi(apiClient: apiClient),
    videosApi: VideosApi(apiClient: apiClient),
    videoCollectionsApi: VideoCollectionsApi(apiClient: apiClient),
    clipCollectionsApi: ClipCollectionsApi(apiClient: apiClient),
    imageSearchApi: ImageSearchApi(apiClient: apiClient),
    adapter: adapter,
  );
}
