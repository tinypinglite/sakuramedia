import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_actions_panel.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';

/// 移动端视频操作抽屉：点击视频卡后从底部弹出。
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
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-video-actions-sheet'),
    maxHeightFactor: 0.8,
    builder: (_) => MobileVideoActionsSheet(
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
}

class MobileVideoActionsSheet extends StatelessWidget {
  const MobileVideoActionsSheet({
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
      mobile: true,
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
