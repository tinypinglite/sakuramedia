import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

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

  // 全屏图片宿主画在路由之上，只有宿主自己的底部抽屉能盖住它；移动端统一走
  // 抽屉，桌面端（详情页未开启全屏）用锚定弹层。
  final l10n = AppLocalizations.of(context);
  final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
  final action = await showAppActionMenu<AppImageActionType>(
    context: context,
    globalPosition: globalPosition,
    presentation: isMobile
        ? AppMenuPresentation.bottomDrawer
        : AppMenuPresentation.popup,
    drawerKey: isMobile ? kAppImageActionMenuDrawerKey : null,
    items: buildImageActionMenuItems(<AppImageActionDescriptor>[
      if (ProviderScope.containerOf(
        context,
        listen: false,
      ).read(imageSearchEnabledProvider))
        AppImageActionDescriptor(
          type: AppImageActionType.searchSimilar,
          label: l10n.movieActionSearchSimilarImages,
          icon: Icons.image_search_outlined,
        ),
      AppImageActionDescriptor(
        type: AppImageActionType.saveToLocal,
        label: l10n.movieActionSaveToLocal,
        icon: Icons.download_outlined,
      ),
    ]),
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
    case AppImageActionType.addToCollection:
    case AppImageActionType.play:
    case AppImageActionType.setCover:
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
  final l10n = AppLocalizations.of(hostContext);
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
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.movieActionReadImageFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }
}

String _resolveImageUrl(MovieImageDto image) => image.origin.trim();

Future<void> _searchSimilar({
  required BuildContext context,
  required BuildContext hostContext,
  required String imageUrl,
  required String fileName,
  required String movieNumber,
  required bool closeCurrentRouteOnSearch,
}) async {
  final launch = () => launchDesktopImageSearchFromUrl(
    hostContext,
    imageUrl: imageUrl,
    fallbackPath: DesktopRoutes.movieDetail(movieNumber: movieNumber).location,
    fileName: fileName,
    currentMovieNumber: movieNumber,
  );
  final l10n = AppLocalizations.of(hostContext);

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
            showToast(
              apiErrorMessage(
                error,
                fallback: l10n.movieActionReadImageFailed,
                l10n: l10n,
              ),
              tone: AppToastTone.error,
            );
          }
        }
      });
      return;
    }

    await launch();
  } catch (error) {
    if (hostContext.mounted) {
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.movieActionReadImageFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }
}

Future<void> _saveToLocal({
  required BuildContext context,
  required String imageUrl,
  required String fileName,
}) async {
  final l10n = AppLocalizations.of(context);
  final result =
      await ImageSaveService(
        fetchBytes: ProviderScope.containerOf(
          context,
          listen: false,
        ).read(apiClientProvider).getBytes,
      ).saveImageFromUrl(
        imageUrl: imageUrl,
        fileName: fileName,
        dialogTitle: l10n.movieActionSaveToLocal,
        l10n: l10n,
      );
  if (!context.mounted) {
    return;
  }
  if (result.status == ImageSaveStatus.success) {
    showToast(
      result.message ?? l10n.movieActionImageSaved,
      tone: AppToastTone.success,
    );
  }
  if (result.status == ImageSaveStatus.failed) {
    showToast(
      result.message ?? l10n.movieActionImageSaveFailed,
      tone: AppToastTone.error,
    );
  }
}
