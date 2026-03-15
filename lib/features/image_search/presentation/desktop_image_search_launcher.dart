import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
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
  final routeState = DesktopImageSearchRouteState(
    fallbackPath: fallbackPath,
    initialFileName: fileName,
    initialFileBytes: bytes,
    initialMimeType: guessImageMimeType(fileName),
    currentMovieNumber: currentMovieNumber,
    initialCurrentMovieScope: initialCurrentMovieScope,
  );
  if (replaceCurrent) {
    context.go(routePath, extra: routeState);
    return;
  }
  context.push(routePath, extra: routeState);
}
