import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_routes.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';

Future<void> launchDesktopImageSearchFromUrl(
  BuildContext context, {
  required String imageUrl,
  String? fallbackPath,
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
  String? fallbackPath,
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
    final mimeType = guessImageMimeType(fileName);
    if (routePath == desktopImageSearchPath) {
      final route = _buildDesktopRoute(
        context: context,
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        currentMovieNumber: currentMovieNumber,
        initialCurrentMovieScope: initialCurrentMovieScope,
      );
      route.pushReplacement(context);
      return;
    }
    if (routePath == mobileImageSearchPath) {
      final route = _buildMobileRoute(
        context: context,
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        currentMovieNumber: currentMovieNumber,
        initialCurrentMovieScope: initialCurrentMovieScope,
      );
      route.pushReplacement(context);
      return;
    }
    return;
  }
  if (routePath == desktopImageSearchPath) {
    context.pushDesktopImageSearch(
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
      initialFileName: fileName,
      initialFileBytes: bytes,
      initialMimeType: guessImageMimeType(fileName),
      currentMovieNumber: currentMovieNumber,
      initialCurrentMovieScope: initialCurrentMovieScope,
    );
    return;
  }
}

DesktopImageSearchRouteData _buildDesktopRoute({
  required BuildContext context,
  required String fileName,
  required Uint8List bytes,
  required String? mimeType,
  required String? currentMovieNumber,
  required ImageSearchCurrentMovieScope initialCurrentMovieScope,
}) {
  final draftId = context.read<ImageSearchDraftStore>().save(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
  return DesktopImageSearchRouteData(
    draftId: draftId,
    currentMovieNumber: currentMovieNumber,
    currentMovieScope: initialCurrentMovieScope.name,
  );
}

MobileImageSearchRouteData _buildMobileRoute({
  required BuildContext context,
  required String fileName,
  required Uint8List bytes,
  required String? mimeType,
  required String? currentMovieNumber,
  required ImageSearchCurrentMovieScope initialCurrentMovieScope,
}) {
  final draftId = context.read<ImageSearchDraftStore>().save(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
  return MobileImageSearchRouteData(
    draftId: draftId,
    currentMovieNumber: currentMovieNumber,
    currentMovieScope: initialCurrentMovieScope.name,
  );
}
