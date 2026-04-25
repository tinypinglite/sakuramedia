import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_routes.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';

extension AppNavigationActions on BuildContext {
  void goPrimaryRoute(String path) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    switch (path) {
      case desktopOverviewPath:
        return const DesktopOverviewRouteData().go(this);
      case desktopFollowPath:
        return const DesktopFollowRouteData().go(this);
      case desktopMoviesPath:
        return const DesktopMoviesRouteData().go(this);
      case desktopActorsPath:
        return const DesktopActorsRouteData().go(this);
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
    DesktopImageSearchRouteData(
      draftId: draftId,
      currentMovieNumber: currentMovieNumber,
      currentMovieScope: initialCurrentMovieScope.name,
    ).push(this);
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
