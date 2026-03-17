import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';

Future<void> launchDesktopImageSearchFromUrl(
  BuildContext context, {
  required String imageUrl,
  required String fallbackPath,
  required String fileName,
  String? currentMovieNumber,
  ImageSearchCurrentMovieScope initialCurrentMovieScope =
      ImageSearchCurrentMovieScope.all,
  bool replaceCurrent = false,
}) async {
  await launchImageSearchFromUrl(
    context,
    imageUrl: imageUrl,
    routePath: desktopImageSearchPath,
    fallbackPath: fallbackPath,
    fileName: fileName,
    currentMovieNumber: currentMovieNumber,
    initialCurrentMovieScope: initialCurrentMovieScope,
    replaceCurrent: replaceCurrent,
  );
}

Future<void> launchImageSearchFromUrl(
  BuildContext context, {
  required String imageUrl,
  required String routePath,
  required String fallbackPath,
  required String fileName,
  String? currentMovieNumber,
  ImageSearchCurrentMovieScope initialCurrentMovieScope =
      ImageSearchCurrentMovieScope.all,
  bool replaceCurrent = false,
}) async {
  final apiClient = context.read<ApiClient>();
  final bytes = await apiClient.getBytes(imageUrl);
  if (!context.mounted) {
    return;
  }
  if (replaceCurrent) {
    context.pushReplacement(
      routePath,
      extra: _buildRouteState(
        fallbackPath: fallbackPath,
        fileName: fileName,
        bytes: bytes,
        currentMovieNumber: currentMovieNumber,
        initialCurrentMovieScope: initialCurrentMovieScope,
      ),
    );
    return;
  }
  if (routePath == desktopImageSearchPath) {
    context.pushDesktopImageSearch(
      fallbackPath: fallbackPath,
      initialFileName: fileName,
      initialFileBytes: bytes,
      initialMimeType: guessImageMimeType(fileName),
      currentMovieNumber: currentMovieNumber,
      initialCurrentMovieScope: initialCurrentMovieScope,
    );
    return;
  }
  if (routePath == mobileImageSearchPath) {
    context.pushMobileImageSearch(
      fallbackPath: fallbackPath,
      initialFileName: fileName,
      initialFileBytes: bytes,
      initialMimeType: guessImageMimeType(fileName),
      currentMovieNumber: currentMovieNumber,
      initialCurrentMovieScope: initialCurrentMovieScope,
    );
    return;
  }
  context.push(
    routePath,
    extra: _buildRouteState(
      fallbackPath: fallbackPath,
      fileName: fileName,
      bytes: bytes,
      currentMovieNumber: currentMovieNumber,
      initialCurrentMovieScope: initialCurrentMovieScope,
    ),
  );
}

Object _buildRouteState({
  required String fallbackPath,
  required String fileName,
  required Uint8List bytes,
  String? currentMovieNumber,
  required ImageSearchCurrentMovieScope initialCurrentMovieScope,
}) {
  return DesktopImageSearchRouteState(
    fallbackPath: fallbackPath,
    initialFileName: fileName,
    initialFileBytes: bytes,
    initialMimeType: guessImageMimeType(fileName),
    currentMovieNumber: currentMovieNumber,
    initialCurrentMovieScope: initialCurrentMovieScope,
  );
}
