import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_launcher.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/widgets/media/app_image_action_menu.dart';

Future<void> showMoviePlotImageActionMenu({
  required BuildContext context,
  required BuildContext hostContext,
  required List<MovieImageDto> plotImages,
  required String movieNumber,
  required int index,
  required Offset globalPosition,
  bool closeCurrentRouteOnSearch = false,
  Future<void> Function(BuildContext context, String imageUrl, String fileName)?
  onSearchSimilar,
}) async {
  if (index < 0 || index >= plotImages.length) {
    return;
  }

  final image = plotImages[index];
  final imageUrl = _resolveImageUrl(image);
  if (imageUrl.isEmpty) {
    return;
  }

  final action = await showAppImageActionMenu(
    context: context,
    globalPosition: globalPosition,
    presentation:
        isMobileAppPlatform()
            ? AppImageActionMenuPresentation.bottomDrawer
            : AppImageActionMenuPresentation.popup,
    actions: const <AppImageActionDescriptor>[
      AppImageActionDescriptor(
        type: AppImageActionType.searchSimilar,
        label: '相似图片',
        icon: Icons.image_search_outlined,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.saveToLocal,
        label: '保存到本地',
        icon: Icons.download_outlined,
      ),
    ],
  );
  if (action == null) {
    return;
  }

  final fileName = 'movie_plot_${movieNumber}_${index + 1}.webp';

  switch (action) {
    case AppImageActionType.searchSimilar:
      if (onSearchSimilar != null) {
        await _searchSimilarWithCallback(
          context: context,
          hostContext: hostContext,
          imageUrl: imageUrl,
          fileName: fileName,
          closeCurrentRouteOnSearch: closeCurrentRouteOnSearch,
          onSearchSimilar: onSearchSimilar,
        );
      } else {
        await _searchSimilar(
          context: context,
          hostContext: hostContext,
          imageUrl: imageUrl,
          fileName: fileName,
          movieNumber: movieNumber,
          closeCurrentRouteOnSearch: closeCurrentRouteOnSearch,
        );
      }
      break;
    case AppImageActionType.saveToLocal:
      await _saveToLocal(
        context: hostContext,
        imageUrl: imageUrl,
        fileName: fileName,
      );
      break;
    case AppImageActionType.toggleMark:
    case AppImageActionType.play:
    case AppImageActionType.movieDetail:
      break;
  }
}

Future<void> _searchSimilarWithCallback({
  required BuildContext context,
  required BuildContext hostContext,
  required String imageUrl,
  required String fileName,
  required bool closeCurrentRouteOnSearch,
  required Future<void> Function(
    BuildContext context,
    String imageUrl,
    String fileName,
  )
  onSearchSimilar,
}) async {
  try {
    if (closeCurrentRouteOnSearch) {
      Navigator.of(context).pop();
      Future<void>.microtask(() async {
        if (!hostContext.mounted) {
          return;
        }
        await onSearchSimilar(hostContext, imageUrl, fileName);
      });
      return;
    }
    await onSearchSimilar(hostContext, imageUrl, fileName);
  } catch (error) {
    if (hostContext.mounted) {
      showToast(apiErrorMessage(error, fallback: '读取图片失败，请稍后重试'));
    }
  }
}

String _resolveImageUrl(MovieImageDto image) {
  final origin = image.origin.trim();
  if (origin.isNotEmpty) {
    return origin;
  }
  return image.bestAvailableUrl.trim();
}

Future<void> _searchSimilar({
  required BuildContext context,
  required BuildContext hostContext,
  required String imageUrl,
  required String fileName,
  required String movieNumber,
  required bool closeCurrentRouteOnSearch,
}) async {
  final launch =
      () => launchDesktopImageSearchFromUrl(
        hostContext,
        imageUrl: imageUrl,
        fallbackPath: buildDesktopMovieDetailRoutePath(movieNumber),
        fileName: fileName,
        currentMovieNumber: movieNumber,
      );

  try {
    if (closeCurrentRouteOnSearch) {
      Navigator.of(context).pop();
      Future<void>.microtask(() async {
        if (!hostContext.mounted) {
          return;
        }
        try {
          await launch();
        } catch (error) {
          if (hostContext.mounted) {
            showToast(apiErrorMessage(error, fallback: '读取图片失败，请稍后重试'));
          }
        }
      });
      return;
    }

    await launch();
  } catch (error) {
    if (hostContext.mounted) {
      showToast(apiErrorMessage(error, fallback: '读取图片失败，请稍后重试'));
    }
  }
}

Future<void> _saveToLocal({
  required BuildContext context,
  required String imageUrl,
  required String fileName,
}) async {
  final result = await ImageSaveService(
    fetchBytes: context.read<ApiClient>().getBytes,
  ).saveImageFromUrl(
    imageUrl: imageUrl,
    fileName: fileName,
    dialogTitle: '保存到本地',
  );
  if (!context.mounted) {
    return;
  }
  if (result.status == ImageSaveStatus.success) {
    showToast(result.message ?? '图片已保存');
  }
  if (result.status == ImageSaveStatus.failed) {
    showToast(result.message ?? '保存失败，请稍后重试');
  }
}
