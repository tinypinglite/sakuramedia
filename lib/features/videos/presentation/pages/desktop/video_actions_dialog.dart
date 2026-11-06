import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_actions_panel.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';

/// 桌面版视频操作弹窗：点击视频卡后弹出居中对话框。
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
  return showAppDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AppDesktopDialog(
        dialogKey: const Key('desktop-video-actions-dialog'),
        width: dialogContext.appLayoutTokens.dialogWidthMd,
        child: DesktopVideoActionsDialogBody(
          video: video,
          onPlay: onPlay,
          onThumbnails: onThumbnails,
          onAddToCollection: onAddToCollection,
          onDelete: onDelete,
          onRemoveFromCollection: onRemoveFromCollection,
          collections: collections,
          onCollectionTap: onCollectionTap,
        ),
      );
    },
  );
}

class DesktopVideoActionsDialogBody extends StatelessWidget {
  const DesktopVideoActionsDialogBody({
    super.key,
    required this.video,
    required this.onPlay,
    this.onThumbnails,
    this.onAddToCollection,
    this.onDelete,
    this.onRemoveFromCollection,
    this.collections = const <VideoCollectionRef>[],
    this.onCollectionTap,
  });

  final VideoItemListItemDto video;
  final VoidCallback onPlay;
  final VoidCallback? onThumbnails;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onDelete;
  final VoidCallback? onRemoveFromCollection;
  final List<VideoCollectionRef> collections;
  final ValueChanged<VideoCollectionRef>? onCollectionTap;

  @override
  Widget build(BuildContext context) {
    return VideoActionsPanel(
      mobile: false,
      video: video,
      onPlay: onPlay,
      onThumbnails: onThumbnails,
      onAddToCollection: onAddToCollection,
      onDelete: onDelete,
      onRemoveFromCollection: onRemoveFromCollection,
      collections: collections,
      onCollectionTap: onCollectionTap,
    );
  }
}
