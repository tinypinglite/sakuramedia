import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/core/session/providers/credential_store_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_draft_store_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_navigation_route_state.dart';
import 'package:sakuramedia/routes/desktop_routes.dart';
import 'package:sakuramedia/routes/desktop_search_route_state.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';

extension AppNavigationActions on BuildContext {
  void goPrimaryRoute(String path) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    switch (path) {
      case desktopOverviewPath:
        return const DesktopOverviewRouteData().go(this);
      case desktopDiscoverPath:
        return const DesktopDiscoverRouteData().go(this);
      case desktopMoviesPath:
        return const DesktopMoviesRouteData().go(this);
      case desktopActorsPath:
        return const DesktopActorsRouteData().go(this);
      case desktopTagsPath:
        return const DesktopTagsRouteData().go(this);
      case desktopMomentsPath:
        return const DesktopMomentsRouteData().go(this);
      case desktopPlaylistsPath:
        return const DesktopPlaylistsRouteData().go(this);
      case desktopRankingsPath:
        return const DesktopRankingsRouteData().go(this);
      case desktopHotReviewsPath:
        return const DesktopHotReviewsRouteData().go(this);
      case desktopConfigurationPath:
        return const DesktopConfigurationRouteData().go(this);
      case desktopActivityPath:
        return const DesktopActivityRouteData().go(this);
      case desktopNotificationsPath:
        return const DesktopNotificationsRouteData().go(this);
      case mobileOverviewPath:
        return const MobileOverviewRouteData().go(this);
      case mobileMoviesPath:
        return const MobileMoviesRouteData().go(this);
      case mobileActorsPath:
        return const MobileActorsRouteData().go(this);
      case mobileRankingsPath:
        return const MobileRankingsRouteData().go(this);
      case mobilePornboxPath:
        return const MobilePornboxRouteData().go(this);
      default:
        return go(path);
    }
  }

  void pushDesktopMovieDetail({
    required String movieNumber,
    String? fallbackPath,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    final route = DesktopMovieDetailRouteData(movieNumber: movieNumber);
    _pushDesktopRoute(this, route.location, fallbackPath: fallbackPath);
  }

  void pushDesktopSystemDiagnostics() {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    const DesktopSystemDiagnosticsRouteData().push(this);
  }

  /// 跳转到任务中心的「下载任务」tab，并按指定番号过滤。
  ///
  /// 订阅管理页的卡片用它查看该订阅片对应的下载记录；筛选走 query 参数，
  /// 由 [DesktopActivityPage] 在打开时消费。
  void goDesktopDownloadTasks({required String movieNumber}) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    DesktopActivityRouteData(downloadMovieNumber: movieNumber).go(this);
  }

  /// 跳到资源导入中心，创建媒体或字幕导入任务。
  void goDesktopMediaImport() {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    const DesktopMediaImportRouteData().go(this);
  }

  void pushDesktopMovieSeries({
    required int seriesId,
    String? seriesName,
    String? fallbackPath,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    final route = DesktopMovieSeriesRouteData(
      seriesId: seriesId,
      seriesName: seriesName,
    );
    _pushDesktopRoute(this, route.location, fallbackPath: fallbackPath);
  }

  void pushDesktopActorDetail({required int actorId, String? fallbackPath}) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    final route = DesktopActorDetailRouteData(actorId: actorId);
    _pushDesktopRoute(this, route.location, fallbackPath: fallbackPath);
  }

  void pushDesktopTags({required int tagId}) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    DesktopTagMoviesRouteData(tagId: tagId).push(this);
  }

  void pushDesktopPlaylistDetail({
    required int playlistId,
    String? fallbackPath,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    final route = DesktopPlaylistDetailRouteData(playlistId: playlistId);
    _pushDesktopRoute(this, route.location, fallbackPath: fallbackPath);
  }

  void pushDesktopMoviePlayer({
    required String movieNumber,
    String? fallbackPath,
    int? mediaId,
    int? positionSeconds,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    final route = DesktopMoviePlayerRouteData(
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
    );
    _pushDesktopRoute(this, route.location, fallbackPath: fallbackPath);
  }

  /// 返回的 Future 在「全部切片合集」页出栈后完成，调用方可据此刷新首页合集横滑区
  /// （页内可能重命名/删除合集）。
  Future<void> pushDesktopClipCollections() {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    return const DesktopClipCollectionsRouteData().push<void>(this);
  }

  void pushDesktopClipCollectionDetail({required int collectionId}) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    DesktopClipCollectionDetailRouteData(collectionId: collectionId).push(this);
  }

  void pushDesktopClipCollectionPlay({
    required int collectionId,
    int startIndex = 0,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    DesktopClipCollectionPlayRouteData(
      collectionId: collectionId,
      startIndex: startIndex,
    ).push(this);
  }

  /// 返回的 Future 在「全部视频合集」页出栈后完成，调用方可据此刷新首页合集横滑区
  /// （页内可能重命名/删除合集）。
  Future<void> pushDesktopVideoCollections() {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    return const DesktopVideoCollectionsRouteData().push<void>(this);
  }

  void pushDesktopVideoCollectionDetail({required int collectionId}) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    DesktopVideoCollectionDetailRouteData(
      collectionId: collectionId,
    ).push(this);
  }

  void pushDesktopVideoCollectionPlay({
    required int collectionId,
    int startIndex = 0,
    String? sort,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    DesktopVideoCollectionPlayRouteData(
      collectionId: collectionId,
      startIndex: startIndex,
      sort: sort,
    ).push(this);
  }

  void pushDesktopSearch({
    required String query,
    String? fallbackPath,
    bool useOnlineSearch = false,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      final route = DesktopSearchRouteData(useOnlineSearch: useOnlineSearch);
      GoRouter.of(this).push<void>(
        route.location,
        extra: DesktopSearchRouteState(
          fallbackPath: fallbackPath,
          useOnlineSearch: useOnlineSearch,
        ),
      );
      return;
    }
    final route = DesktopSearchQueryRouteData(
      query: trimmed,
      useOnlineSearch: useOnlineSearch,
    );
    GoRouter.of(this).push<void>(
      route.location,
      extra: DesktopSearchRouteState(
        fallbackPath: fallbackPath,
        useOnlineSearch: useOnlineSearch,
      ),
    );
  }

  void pushDesktopImageSearch({
    String? fallbackPath,
    String? initialFileName,
    Uint8List? initialFileBytes,
    String? initialMimeType,
    String? currentMovieNumber,
    ImageSearchCurrentMovieScope initialCurrentMovieScope =
        ImageSearchCurrentMovieScope.all,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    final draftId = _saveImageSearchDraft(
      fileName: initialFileName,
      fileBytes: initialFileBytes,
      mimeType: initialMimeType,
    );
    final route = DesktopImageSearchRouteData(
      draftId: draftId,
      currentMovieNumber: currentMovieNumber,
      currentMovieScope: initialCurrentMovieScope.name,
    );
    GoRouter.of(this).push<void>(
      route.location,
      extra: DesktopImageSearchRouteState(fallbackPath: fallbackPath),
    );
  }

  void goDesktopImageSearch({
    String? fallbackPath,
    String? initialFileName,
    Uint8List? initialFileBytes,
    String? initialMimeType,
    String? currentMovieNumber,
    ImageSearchCurrentMovieScope initialCurrentMovieScope =
        ImageSearchCurrentMovieScope.all,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    final draftId = _saveImageSearchDraft(
      fileName: initialFileName,
      fileBytes: initialFileBytes,
      mimeType: initialMimeType,
    );
    final route = DesktopImageSearchRouteData(
      draftId: draftId,
      currentMovieNumber: currentMovieNumber,
      currentMovieScope: initialCurrentMovieScope.name,
    );
    GoRouter.of(this).go(
      route.location,
      extra: DesktopImageSearchRouteState(fallbackPath: fallbackPath),
    );
  }

  void pushMobileMovieDetail({
    required String movieNumber,
    String? fallbackPath,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    MobileMovieDetailRouteData(movieNumber: movieNumber).push(this);
  }

  void pushMobileMovieSeries({
    required int seriesId,
    String? seriesName,
    String? fallbackPath,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    MobileMovieSeriesRouteData(
      seriesId: seriesId,
      seriesName: seriesName,
    ).push(this);
  }

  void pushMobileTags({required int tagId}) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    MobileTagMoviesRouteData(tagId: tagId).push(this);
  }

  void pushMobileImageSearch({
    String? fallbackPath,
    String? initialFileName,
    Uint8List? initialFileBytes,
    String? initialMimeType,
    String? currentMovieNumber,
    ImageSearchCurrentMovieScope initialCurrentMovieScope =
        ImageSearchCurrentMovieScope.all,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    final draftId = _saveImageSearchDraft(
      fileName: initialFileName,
      fileBytes: initialFileBytes,
      mimeType: initialMimeType,
    );
    MobileImageSearchRouteData(
      draftId: draftId,
      currentMovieNumber: currentMovieNumber,
      currentMovieScope: initialCurrentMovieScope.name,
    ).push(this);
  }

  /// 统一登出出口：清空会话并清除已保存的登录凭据。
  ///
  /// 在任何 await 之前先取出依赖，避免 await 后 context 失效再读取 Provider；
  /// 先清空会话以触发 GoRouter 立即重定向到登录页，凭据清除随后进行，
  /// 不让其 I/O 阻塞登出的可见跳转。
  Future<void> logOut() async {
    final container = ProviderScope.containerOf(this, listen: false);
    final credentialStore = container.read(credentialStoreProvider);
    final sessionStore = container.read(sessionStoreProvider);
    await sessionStore.clearSession();
    await credentialStore.clearCredentials();
  }

  String? _saveImageSearchDraft({
    required String? fileName,
    required Uint8List? fileBytes,
    required String? mimeType,
  }) {
    if (fileName == null ||
        fileName.isEmpty ||
        fileBytes == null ||
        fileBytes.isEmpty) {
      return null;
    }
    return ProviderScope.containerOf(this, listen: false)
        .read(imageSearchDraftStoreProvider)
        .save(fileName: fileName, bytes: fileBytes, mimeType: mimeType);
  }
}

void _pushDesktopRoute(
  BuildContext context,
  String location, {
  required String? fallbackPath,
}) {
  GoRouter.of(context).push<void>(
    location,
    extra: DesktopNavigationRouteState(fallbackPath: fallbackPath),
  );
}
