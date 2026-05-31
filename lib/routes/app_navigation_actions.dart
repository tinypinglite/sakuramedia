import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/credential_store.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_routes.dart';
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
      case desktopMediaMaintenancePath:
        return const DesktopMediaMaintenanceRouteData().go(this);
      case desktopConfigurationPath:
        return const DesktopConfigurationRouteData().go(this);
      case desktopActivityPath:
        return const DesktopActivityRouteData().go(this);
      case mobileOverviewPath:
        return const MobileOverviewRouteData().go(this);
      case mobileMoviesPath:
        return const MobileMoviesRouteData().go(this);
      case mobileActorsPath:
        return const MobileActorsRouteData().go(this);
      case mobileRankingsPath:
        return const MobileRankingsRouteData().go(this);
      default:
        return go(path);
    }
  }

  void pushDesktopMovieDetail({
    required String movieNumber,
    String? fallbackPath,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    DesktopMovieDetailRouteData(movieNumber: movieNumber).push(this);
  }

  void pushDesktopMovieSeries({
    required int seriesId,
    String? seriesName,
    String? fallbackPath,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    DesktopMovieSeriesRouteData(
      seriesId: seriesId,
      seriesName: seriesName,
    ).push(this);
  }

  void pushDesktopActorDetail({required int actorId, String? fallbackPath}) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    DesktopActorDetailRouteData(actorId: actorId).push(this);
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
    DesktopPlaylistDetailRouteData(playlistId: playlistId).push(this);
  }

  void pushDesktopMoviePlayer({
    required String movieNumber,
    String? fallbackPath,
    int? mediaId,
    int? positionSeconds,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    DesktopMoviePlayerRouteData(
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
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
      DesktopSearchRouteData(useOnlineSearch: useOnlineSearch).push(this);
      return;
    }
    DesktopSearchQueryRouteData(
      query: trimmed,
      useOnlineSearch: useOnlineSearch,
    ).push(this);
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

  void pushMobileActorDetail({required int actorId, String? fallbackPath}) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    MobileActorDetailRouteData(actorId: actorId).push(this);
  }

  void pushMobileTags({required int tagId}) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    MobileTagMoviesRouteData(tagId: tagId).push(this);
  }

  void pushMobilePlaylistDetail({
    required int playlistId,
    String? fallbackPath,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    MobilePlaylistDetailRouteData(playlistId: playlistId).push(this);
  }

  void pushMobileMoviePlayer({
    required String movieNumber,
    int? mediaId,
    int? positionSeconds,
    String? fallbackPath,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    MobileMoviePlayerRouteData(
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
    ).push(this);
  }

  void pushMobileSearch({
    required String query,
    String? fallbackPath,
    bool useOnlineSearch = false,
  }) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      MobileSearchRouteData(useOnlineSearch: useOnlineSearch).push(this);
      return;
    }
    MobileSearchQueryRouteData(
      query: trimmed,
      useOnlineSearch: useOnlineSearch,
    ).push(this);
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
    final credentialStore = read<CredentialStore>();
    final sessionStore = read<SessionStore>();
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
    return read<ImageSearchDraftStore>().save(
      fileName: fileName,
      bytes: fileBytes,
      mimeType: mimeType,
    );
  }
}
