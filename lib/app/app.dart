import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/app_state.dart';
import 'package:sakuramedia/app/app_version_info_controller.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/credential_store.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/activity/presentation/notification_center_controller.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_api.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/discovery/data/discovery_api.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/external_player/data/external_player_store.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/clips/data/clips_api.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collections_api.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/video_imports_api.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/videos/presentation/video_mutation_change_notifier.dart';
import 'package:sakuramedia/features/clips/presentation/clip_mutation_change_notifier.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_reviews_api.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/app_image_fullscreen.dart';

/// 允许发起拖拽滚动的指针类型集合(应用全局 [ScrollConfiguration] 使用)。
///
/// 必须为 [PointerDeviceKind] 全集 —— 尤其不能漏掉 [PointerDeviceKind.unknown]:
/// 无障碍服务 / 远程控制工具(如 Android VoiceAccess、RustDesk 经
/// `AccessibilityService.dispatchGesture` 注入的滑动手势)上报的 pointer kind
/// 即为 unknown,缺它会导致这类来源只能点击、无法滚动(Flutter 框架默认集合
/// `_kTouchLikeDeviceTypes` 同样包含 unknown,原因一致)。
const Set<PointerDeviceKind> kAppScrollDragDevices = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.trackpad,
  PointerDeviceKind.unknown,
};

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.platformOverride, this.sessionStore});

  final AppPlatform? platformOverride;
  final SessionStore? sessionStore;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppPlatform _platform;
  late SessionStore _activeSessionStore;
  late GoRouter _router;
  late bool _ownsSessionStore;

  @override
  void initState() {
    super.initState();
    _initializeAppState();
  }

  @override
  void didUpdateWidget(covariant MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.platformOverride == widget.platformOverride &&
        oldWidget.sessionStore == widget.sessionStore) {
      return;
    }

    _disposeAppState();
    _initializeAppState();
  }

  @override
  void dispose() {
    _disposeAppState();
    super.dispose();
  }

  void _initializeAppState() {
    _platform = resolveAppPlatform(override: widget.platformOverride);
    _ownsSessionStore = widget.sessionStore == null;
    _activeSessionStore = widget.sessionStore ?? SessionStore.inMemory();
    _router = buildAppRouter(_platform, _activeSessionStore);
  }

  void _disposeAppState() {
    _router.dispose();
    if (_ownsSessionStore) {
      _activeSessionStore.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppPlatform>.value(value: _platform),
        ChangeNotifierProvider(create: (_) => AppShellController()),
        ChangeNotifierProvider<SessionStore>.value(value: _activeSessionStore),
        ChangeNotifierProxyProvider<SessionStore, AppPageStateCache>(
          create:
              (context) =>
                  AppPageStateCache()
                    ..bindSessionStore(context.read<SessionStore>()),
          update: (context, sessionStore, cache) {
            final activeCache = cache ?? AppPageStateCache();
            activeCache.bindSessionStore(sessionStore);
            return activeCache;
          },
        ),
        Provider<CredentialStore>(create: (_) => CredentialStore()),
        Provider<ApiClient>(
          create:
              (context) =>
                  ApiClient(sessionStore: context.read<SessionStore>()),
          dispose: (context, client) => client.dispose(),
        ),
        Provider<AuthApi>(
          create:
              (context) => AuthApi(
                apiClient: context.read<ApiClient>(),
                sessionStore: context.read<SessionStore>(),
                credentialStore: context.read<CredentialStore>(),
              ),
        ),
        Provider<AccountApi>(
          create: (context) => AccountApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<ActivityEventStreamClient>(
          create:
              (context) => createActivityEventStreamClient(
                apiClient: context.read<ApiClient>(),
                sessionStore: context.read<SessionStore>(),
              ),
          dispose: (context, client) => client.dispose(),
        ),
        Provider<ActivityApi>(
          create:
              (context) => ActivityApi(
                apiClient: context.read<ApiClient>(),
                streamClient: context.read<ActivityEventStreamClient>(),
              ),
        ),
        ChangeNotifierProvider<NotificationCenterController>(
          create:
              (context) =>
                  NotificationCenterController(
                    activityApi: context.read<ActivityApi>(),
                  )..bindSessionStore(context.read<SessionStore>()),
        ),
        Provider<CollectionNumberFeaturesApi>(
          create:
              (context) => CollectionNumberFeaturesApi(
                apiClient: context.read<ApiClient>(),
              ),
        ),
        Provider<ActorsApi>(
          create: (context) => ActorsApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<DownloadClientsApi>(
          create:
              (context) =>
                  DownloadClientsApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<DownloadsApi>(
          create:
              (context) => DownloadsApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<IndexerSettingsApi>(
          create:
              (context) =>
                  IndexerSettingsApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<MediaLibrariesApi>(
          create:
              (context) =>
                  MediaLibrariesApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<MediaImportApi>(
          create:
              (context) => MediaImportApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<MovieDescTranslationSettingsApi>(
          create:
              (context) => MovieDescTranslationSettingsApi(
                apiClient: context.read<ApiClient>(),
              ),
        ),
        Provider<StatusApi>(
          create: (context) => StatusApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<DiscoveryApi>(
          create:
              (context) => DiscoveryApi(apiClient: context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<AppVersionInfoController>(
          create:
              (context) => AppVersionInfoController(
                statusApi: context.read<StatusApi>(),
              ),
        ),
        Provider<MoviesApi>(
          create: (context) => MoviesApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<TagsApi>(
          create: (context) => TagsApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<VideosApi>(
          create: (context) => VideosApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<VideoCollectionsApi>(
          create: (context) =>
              VideoCollectionsApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<VideoImportsApi>(
          create: (context) =>
              VideoImportsApi(apiClient: context.read<ApiClient>()),
        ),
        ChangeNotifierProvider(
          create: (_) => MovieCollectionTypeChangeNotifier(),
        ),
        ChangeNotifierProvider(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
        ChangeNotifierProvider(
          create: (_) => VideoMutationChangeNotifier(),
        ),
        ChangeNotifierProvider(
          create: (_) => ClipMutationChangeNotifier(),
        ),
        // 合集详情页 → 连播页 的一次性成员交接信箱（详情 offer、连播 take），
        // 免去连播页重复全量拉取。无依赖，纯被动存取。
        Provider<CollectionPlaybackHandoff>(
          create: (_) => CollectionPlaybackHandoff(),
        ),
        Provider<PlaylistsApi>(
          create:
              (context) => PlaylistsApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<RankingsApi>(
          create:
              (context) => RankingsApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<HotReviewsApi>(
          create:
              (context) => HotReviewsApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<MediaApi>(
          create: (context) => MediaApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<ClipsApi>(
          create: (context) => ClipsApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<ClipCollectionsApi>(
          create:
              (context) =>
                  ClipCollectionsApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<ImageSearchApi>(
          create:
              (context) => ImageSearchApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<ImageSearchDraftStore>(create: (_) => ImageSearchDraftStore()),
        ChangeNotifierProvider<ExternalPlayerStore>(
          create: (_) => ExternalPlayerStore()..load(),
        ),
      ],
      child: OKToast(
        child: MaterialApp.router(
          title: 'SakuraMedia',
          debugShowCheckedModeBanner: false,
          theme:
              _platform == AppPlatform.mobile
                  ? sakuraMobileThemeData
                  : sakuraDesktopThemeData,
          routerConfig: _router,
          builder: (context, child) {
            return AppImageFullscreenHost(
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: kAppScrollDragDevices,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    );
  }
}
