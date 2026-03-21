import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/app_state.dart';
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
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_reviews_api.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';

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
              ),
        ),
        Provider<AccountApi>(
          create: (context) => AccountApi(apiClient: context.read<ApiClient>()),
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
        Provider<StatusApi>(
          create: (context) => StatusApi(apiClient: context.read<ApiClient>()),
        ),
        Provider<MoviesApi>(
          create: (context) => MoviesApi(apiClient: context.read<ApiClient>()),
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
        Provider<ImageSearchApi>(
          create:
              (context) => ImageSearchApi(apiClient: context.read<ApiClient>()),
        ),
      ],
      child: OKToast(
        child: MaterialApp.router(
          title: 'SakuraMedia',
          debugShowCheckedModeBanner: false,
          theme: sakuraThemeData,
          routerConfig: _router,
          builder: (context, child) {
            return ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: const {
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.touch,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                },
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
