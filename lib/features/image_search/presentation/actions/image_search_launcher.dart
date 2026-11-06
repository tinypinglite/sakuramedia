import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_draft_store_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/app_route_target.dart';
import 'package:sakuramedia/routes/app_routes.dart';

Future<void> launchDesktopImageSearchFromUrl(
  BuildContext context, {
  required String imageUrl,
  String? fallbackPath,
  required String fileName,
  String? currentMovieNumber,
  ImageSearchCurrentMovieScope initialCurrentMovieScope =
      ImageSearchCurrentMovieScope.all,
  bool replaceCurrent = false,
  bool replaceRouteStack = false,
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
    replaceRouteStack: replaceRouteStack,
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
  bool replaceRouteStack = false,
}) async {
  final apiClient = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(apiClientProvider);
  final bytes = await apiClient.getBytes(imageUrl);
  if (!context.mounted) {
    return;
  }
  if (replaceRouteStack && routePath == desktopImageSearchPath) {
    final draftId = saveImageSearchDraft(
      context,
      fileName: fileName,
      bytes: bytes,
      mimeType: guessImageMimeType(fileName),
    );
    DesktopRoutes.imageSearch(
      fallbackPath: fallbackPath,
      draftId: draftId,
      currentMovieNumber: currentMovieNumber,
      currentMovieScope: initialCurrentMovieScope.name,
    ).go(context);
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
        fallbackPath: fallbackPath,
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
        fallbackPath: fallbackPath,
      );
      route.pushReplacement(context);
      return;
    }
    return;
  }
  if (routePath == desktopImageSearchPath) {
    final route = _buildDesktopRoute(
      context: context,
      fileName: fileName,
      bytes: bytes,
      mimeType: guessImageMimeType(fileName),
      currentMovieNumber: currentMovieNumber,
      initialCurrentMovieScope: initialCurrentMovieScope,
      fallbackPath: fallbackPath,
    );
    route.push(context);
    return;
  }
  if (routePath == mobileImageSearchPath) {
    final route = _buildMobileRoute(
      context: context,
      fileName: fileName,
      bytes: bytes,
      mimeType: guessImageMimeType(fileName),
      currentMovieNumber: currentMovieNumber,
      initialCurrentMovieScope: initialCurrentMovieScope,
      fallbackPath: fallbackPath,
    );
    route.push(context);
    return;
  }
}

String? saveImageSearchDraft(
  BuildContext context, {
  required String? fileName,
  required Uint8List? bytes,
  required String? mimeType,
}) {
  if (fileName == null ||
      fileName.isEmpty ||
      bytes == null ||
      bytes.isEmpty) {
    return null;
  }
  return ProviderScope.containerOf(
    context,
    listen: false,
  ).read(imageSearchDraftStoreProvider).save(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
}

AppRouteTarget _buildDesktopRoute({
  required BuildContext context,
  required String fileName,
  required Uint8List bytes,
  required String? mimeType,
  required String? currentMovieNumber,
  required ImageSearchCurrentMovieScope initialCurrentMovieScope,
  required String? fallbackPath,
}) {
  final draftId = saveImageSearchDraft(
    context,
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
  return DesktopRoutes.imageSearch(
    fallbackPath: fallbackPath,
    draftId: draftId,
    currentMovieNumber: currentMovieNumber,
    currentMovieScope: initialCurrentMovieScope.name,
  );
}

AppRouteTarget _buildMobileRoute({
  required BuildContext context,
  required String fileName,
  required Uint8List bytes,
  required String? mimeType,
  required String? currentMovieNumber,
  required ImageSearchCurrentMovieScope initialCurrentMovieScope,
  required String? fallbackPath,
}) {
  final draftId = saveImageSearchDraft(
    context,
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
  return MobileRoutes.imageSearch(
    fallbackPath: fallbackPath,
    draftId: draftId,
    currentMovieNumber: currentMovieNumber,
    currentMovieScope: initialCurrentMovieScope.name,
  );
}
