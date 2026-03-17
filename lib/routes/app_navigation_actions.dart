import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_search_route_state.dart';

extension AppNavigationActions on BuildContext {
  void goPrimaryRoute(String path) {
    _enableImperativeUrlSync();
    go(path);
  }

  void _enableImperativeUrlSync() {
    GoRouter.optionURLReflectsImperativeAPIs = true;
  }

  void pushDesktopMovieDetail({
    required String movieNumber,
    required String fallbackPath,
  }) {
    _enableImperativeUrlSync();
    push(buildDesktopMovieDetailRoutePath(movieNumber), extra: fallbackPath);
  }

  void pushDesktopActorDetail({
    required int actorId,
    required String fallbackPath,
  }) {
    _enableImperativeUrlSync();
    push(buildDesktopActorDetailRoutePath(actorId), extra: fallbackPath);
  }

  void pushDesktopPlaylistDetail({
    required int playlistId,
    required String fallbackPath,
  }) {
    _enableImperativeUrlSync();
    push(buildDesktopPlaylistDetailRoutePath(playlistId), extra: fallbackPath);
  }

  void pushDesktopMoviePlayer({
    required String movieNumber,
    required String fallbackPath,
    int? mediaId,
    int? positionSeconds,
  }) {
    _enableImperativeUrlSync();
    push(
      buildDesktopMoviePlayerRoutePath(
        movieNumber,
        mediaId: mediaId,
        positionSeconds: positionSeconds,
      ),
      extra: fallbackPath,
    );
  }

  void pushDesktopSearch({
    required String query,
    String? fallbackPath,
    bool useOnlineSearch = false,
  }) {
    _enableImperativeUrlSync();
    push(
      buildDesktopSearchRoutePath(query),
      extra: DesktopSearchRouteState(
        fallbackPath: fallbackPath,
        useOnlineSearch: useOnlineSearch,
      ),
    );
  }

  void pushDesktopImageSearch({
    required String fallbackPath,
    String? initialFileName,
    Uint8List? initialFileBytes,
    String? initialMimeType,
    String? currentMovieNumber,
    ImageSearchCurrentMovieScope initialCurrentMovieScope =
        ImageSearchCurrentMovieScope.all,
  }) {
    _enableImperativeUrlSync();
    push(
      desktopImageSearchPath,
      extra: DesktopImageSearchRouteState(
        fallbackPath: fallbackPath,
        initialFileName: initialFileName,
        initialFileBytes: initialFileBytes,
        initialMimeType: initialMimeType,
        currentMovieNumber: currentMovieNumber,
        initialCurrentMovieScope: initialCurrentMovieScope,
      ),
    );
  }

  void pushMobileMovieDetail({
    required String movieNumber,
    String? fallbackPath,
  }) {
    _enableImperativeUrlSync();
    push(buildMobileMovieDetailRoutePath(movieNumber), extra: fallbackPath);
  }

  void pushMobileActorDetail({required int actorId, String? fallbackPath}) {
    _enableImperativeUrlSync();
    push(buildMobileActorDetailRoutePath(actorId), extra: fallbackPath);
  }

  void pushMobilePlaylistDetail({
    required int playlistId,
    String? fallbackPath,
  }) {
    _enableImperativeUrlSync();
    push(buildMobilePlaylistDetailRoutePath(playlistId), extra: fallbackPath);
  }

  void pushMobileMoviePlayer({
    required String movieNumber,
    int? mediaId,
    int? positionSeconds,
    String? fallbackPath,
  }) {
    _enableImperativeUrlSync();
    push(
      buildMobileMoviePlayerRoutePath(
        movieNumber,
        mediaId: mediaId,
        positionSeconds: positionSeconds,
      ),
      extra: fallbackPath,
    );
  }

  void pushMobileSearch({
    required String query,
    String? fallbackPath,
    bool useOnlineSearch = false,
  }) {
    _enableImperativeUrlSync();
    push(
      buildMobileSearchRoutePath(query),
      extra: DesktopSearchRouteState(
        fallbackPath: fallbackPath,
        useOnlineSearch: useOnlineSearch,
      ),
    );
  }

  void pushMobileImageSearch({
    required String fallbackPath,
    String? initialFileName,
    Uint8List? initialFileBytes,
    String? initialMimeType,
    String? currentMovieNumber,
    ImageSearchCurrentMovieScope initialCurrentMovieScope =
        ImageSearchCurrentMovieScope.all,
  }) {
    _enableImperativeUrlSync();
    push(
      mobileImageSearchPath,
      extra: DesktopImageSearchRouteState(
        fallbackPath: fallbackPath,
        initialFileName: initialFileName,
        initialFileBytes: initialFileBytes,
        initialMimeType: initialMimeType,
        currentMovieNumber: currentMovieNumber,
        initialCurrentMovieScope: initialCurrentMovieScope,
      ),
    );
  }
}
