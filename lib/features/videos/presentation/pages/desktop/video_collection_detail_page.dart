import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_collection_detail_content.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_actions_dialog.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/domain/media/quick_play_dialog.dart';

export 'package:sakuramedia/features/videos/presentation/pages/shared/video_collection_detail_content.dart'
    show CollectionDetailLayout;

/// 桌面视频合集详情壳：桌面语义（列表默认 / 拖序 + hover / 顶栏内联批量 /
/// 就地筛选浮层 / 桌面动作弹窗与确认对话框）收在壳里，实现在
/// [VideoCollectionDetailContent]。
class DesktopVideoCollectionDetailPage extends StatelessWidget {
  const DesktopVideoCollectionDetailPage({
    super.key,
    required this.collectionId,
  });

  final int collectionId;

  @override
  Widget build(BuildContext context) {
    return VideoCollectionDetailContent(
      collectionId: collectionId,
      surfaceColor: context.appColors.surfaceElevated,
      keyPrefix: 'video-collection',
      useMobileSelectionLayout: false,
      hoistTitleToSubpageShell: false,
      useMobileFilterDrawer: false,
      enableReorder: true,
      defaultLayout: CollectionDetailLayout.list,
      loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
      playAllBuilder: (context, {required enabled, required onPlayFrom}) {
        return AppButton(
          key: const Key('video-collection-play-all-button'),
          label: '播放全部',
          variant: AppButtonVariant.primary,
          onPressed: enabled ? onPlayFrom : null,
        );
      },
      onMemberTap: (context, item, actions) {
        final video = item.video;
        // 过滤掉「当前合集」这条冗余归属：用户已经在这里了。
        final otherCollections = video.collections
            .where((ref) => ref.id != collectionId)
            .toList(growable: false);
        showDesktopVideoActionsDialog(
          context,
          video: video,
          onPlay:
              () => actions.playSingle(
                context,
                video.id,
                video.preferredTitle,
              ),
          onRemoveFromCollection: () => actions.remove(item.itemId),
          onDelete: () => actions.delete(item.itemId),
          collections: otherCollections,
          onCollectionTap:
              (ref) =>
                  context.pushDesktopVideoCollectionDetail(collectionId: ref.id),
        );
      },
      playSingle: (context, videoId, title) async {
        await showVideoQuickPlayDialog(context, videoId: videoId, title: title);
      },
      onOpenCollection: (context, targetId) {
        context.pushDesktopVideoCollectionDetail(collectionId: targetId);
      },
      confirm: (
        context, {
        required title,
        required message,
        required confirmLabel,
        required confirmKey,
        drawerKey,
      }) =>
          showAppConfirmDialog(
            context,
            title: title,
            message: message,
            danger: true,
            confirmLabel: confirmLabel,
            confirmKey: confirmKey,
          ),
    );
  }
}
