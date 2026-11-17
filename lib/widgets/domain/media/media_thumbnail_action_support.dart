import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';

List<AppImageActionDescriptor> buildMediaThumbnailActionDescriptors({
  required MovieMediaThumbnailDto thumbnail,
  required MediaPointDto? point,
  required AppLocalizations l10n,
  bool canSearchSimilar = true,
  bool showSearchSimilar = true,
  bool canPlay = true,
  bool canSetCover = false,
}) {
  final hasMedia = thumbnail.mediaId > 0;
  return <AppImageActionDescriptor>[
    if (showSearchSimilar)
      AppImageActionDescriptor(
        type: AppImageActionType.searchSimilar,
        label: l10n.widgetMediaActionSearchSimilar,
        icon: Icons.image_search_outlined,
        enabled: canSearchSimilar,
      ),
    AppImageActionDescriptor(
      type: AppImageActionType.saveToLocal,
      label: l10n.widgetMediaActionSaveToLocal,
      icon: Icons.download_outlined,
    ),
    AppImageActionDescriptor(
      type: AppImageActionType.toggleMark,
      label: point == null
          ? l10n.widgetMediaActionAddMark
          : l10n.widgetMediaActionRemoveMark,
      icon: point == null
          ? Icons.bookmark_add_outlined
          : Icons.bookmark_remove_outlined,
      enabled: hasMedia,
    ),
    AppImageActionDescriptor(
      type: AppImageActionType.play,
      label: l10n.widgetMediaActionPlay,
      icon: Icons.play_circle_outline_rounded,
      enabled: hasMedia && canPlay,
    ),
    if (canSetCover)
      AppImageActionDescriptor(
        type: AppImageActionType.setCover,
        label: l10n.widgetMediaActionSetCover,
        icon: Icons.image_outlined,
        enabled: hasMedia && thumbnail.thumbnailId > 0,
      ),
  ];
}

Future<MediaPointDto?> findMediaPointForThumbnail({
  required WidgetRef ref,
  required MovieMediaThumbnailDto thumbnail,
}) async {
  if (thumbnail.mediaId <= 0 || thumbnail.thumbnailId <= 0) {
    return null;
  }
  final points = await ref
      .read(mediaApiProvider)
      .getMediaPoints(mediaId: thumbnail.mediaId);
  for (final point in points) {
    if (point.thumbnailId == thumbnail.thumbnailId) {
      return point;
    }
  }
  return null;
}

/// 查询失败时按“尚未标记”处理，供播放中的上下文继续打开操作菜单。
Future<MediaPointDto?> tryFindMediaPointForThumbnail({
  required WidgetRef ref,
  required MovieMediaThumbnailDto thumbnail,
}) async {
  try {
    return await findMediaPointForThumbnail(ref: ref, thumbnail: thumbnail);
  } catch (_) {
    return null;
  }
}

Future<void> handleMediaThumbnailAction({
  required BuildContext context,
  required WidgetRef ref,
  required MovieMediaThumbnailDto thumbnail,
  required AppImageActionType action,
  required MediaPointDto? point,
  required String fileName,
  Future<void> Function()? onSearchSimilar,
  Future<void> Function()? onPlay,
  Future<void> Function()? onSetCover,
}) async {
  final imageUrl = thumbnail.image.origin;
  final l10n = AppLocalizations.of(context);

  switch (action) {
    case AppImageActionType.searchSimilar:
      await onSearchSimilar?.call();
      break;
    case AppImageActionType.saveToLocal:
      final result =
          await ImageSaveService(
            fetchBytes: ref.read(apiClientProvider).getBytes,
          ).saveImageFromUrl(
            imageUrl: imageUrl,
            fileName: fileName,
            dialogTitle: l10n.widgetMediaActionSaveToLocal,
            l10n: l10n,
          );
      if (!context.mounted) {
        return;
      }
      if (result.status == ImageSaveStatus.success) {
        showToast(
          result.message ?? l10n.widgetMediaImageSaved,
          tone: AppToastTone.success,
        );
      }
      if (result.status == ImageSaveStatus.failed) {
        showToast(
          result.message ?? l10n.widgetMediaSaveFailed,
          tone: AppToastTone.error,
        );
      }
      break;
    case AppImageActionType.toggleMark:
      if (thumbnail.mediaId <= 0 || thumbnail.thumbnailId <= 0) {
        return;
      }
      try {
        if (point == null) {
          await ref
              .read(mediaApiProvider)
              .createMediaPoint(
                mediaId: thumbnail.mediaId,
                thumbnailId: thumbnail.thumbnailId,
              );
          if (context.mounted) {
            showToast(l10n.widgetMediaMarkAdded, tone: AppToastTone.success);
          }
        } else {
          await ref
              .read(mediaApiProvider)
              .deleteMediaPoint(pointId: point.pointId);
          if (context.mounted) {
            showToast(l10n.widgetMediaMarkRemoved, tone: AppToastTone.success);
          }
        }
      } catch (_) {
        if (context.mounted) {
          showToast(l10n.widgetMediaMarkUpdateFailed, tone: AppToastTone.error);
        }
      }
      break;
    case AppImageActionType.play:
      await onPlay?.call();
      break;
    case AppImageActionType.setCover:
      await onSetCover?.call();
      break;
    case AppImageActionType.addToCollection:
    case AppImageActionType.movieDetail:
      break;
  }
}
