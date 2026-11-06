import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_actions_panel.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 视频操作弹层：桌面居中弹窗、移动端底部抽屉共用同一份内容。
///
/// [builder] 通过 [AppAdaptiveModalShellScope] 感知实际壳体，再决定
/// [VideoActionsPanel.mobile]。
Future<void> showVideoActions(
  BuildContext context, {
  required VideoItemListItemDto video,
  required VoidCallback onPlay,
  VoidCallback? onThumbnails,
  VoidCallback? onAddToCollection,
  VoidCallback? onDelete,
  VoidCallback? onRemoveFromCollection,
  List<VideoCollectionRef> collections = const <VideoCollectionRef>[],
  ValueChanged<VideoCollectionRef>? onCollectionTap,
  AppAdaptiveModalVariant variant = AppAdaptiveModalVariant.auto,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    variant: variant,
    dialogKey: const Key('desktop-video-actions-dialog'),
    drawerKey: const Key('mobile-video-actions-sheet'),
    mobileMaxHeightFactor: 0.8,
    builder: (_) => Builder(
      builder: (modalContext) => VideoActionsPanel(
        mobile: AppAdaptiveModalShellScope.maybeIsDrawer(modalContext),
        video: video,
        onPlay: onPlay,
        onThumbnails: onThumbnails,
        onAddToCollection: onAddToCollection,
        onDelete: onDelete,
        onRemoveFromCollection: onRemoveFromCollection,
        collections: collections,
        onCollectionTap: onCollectionTap,
      ),
    ),
  );
}

/// 兼容桌面入口；强制使用居中对话框。
Future<void> showDesktopVideoActionsDialog(
  BuildContext context, {
  required VideoItemListItemDto video,
  required VoidCallback onPlay,
  VoidCallback? onThumbnails,
  VoidCallback? onAddToCollection,
  VoidCallback? onDelete,
  VoidCallback? onRemoveFromCollection,
  List<VideoCollectionRef> collections = const <VideoCollectionRef>[],
  ValueChanged<VideoCollectionRef>? onCollectionTap,
}) {
  return showVideoActions(
    context,
    video: video,
    onPlay: onPlay,
    onThumbnails: onThumbnails,
    onAddToCollection: onAddToCollection,
    onDelete: onDelete,
    onRemoveFromCollection: onRemoveFromCollection,
    collections: collections,
    onCollectionTap: onCollectionTap,
    variant: AppAdaptiveModalVariant.dialog,
  );
}

/// 兼容移动入口；强制使用底部抽屉。
Future<void> showMobileVideoActionsSheet(
  BuildContext context, {
  required VideoItemListItemDto video,
  required VoidCallback onPlay,
  VoidCallback? onThumbnails,
  VoidCallback? onAddToCollection,
  VoidCallback? onDelete,
  VoidCallback? onRemoveFromCollection,
  List<VideoCollectionRef> collections = const <VideoCollectionRef>[],
  ValueChanged<VideoCollectionRef>? onCollectionTap,
}) {
  return showVideoActions(
    context,
    video: video,
    onPlay: onPlay,
    onThumbnails: onThumbnails,
    onAddToCollection: onAddToCollection,
    onDelete: onDelete,
    onRemoveFromCollection: onRemoveFromCollection,
    collections: collections,
    onCollectionTap: onCollectionTap,
    variant: AppAdaptiveModalVariant.drawer,
  );
}
