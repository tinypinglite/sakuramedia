import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_collection_detail_content.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_actions_dialog.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
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
      loadingBuilder: (_) => const _DesktopVideoCollectionDetailLoadingState(),
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
        onConfirm,
      }) =>
          showAppConfirmDialog(
            context,
            title: title,
            message: message,
            danger: true,
            confirmLabel: confirmLabel,
            confirmKey: confirmKey,
            onConfirm: onConfirm,
            failureFallback: '删除失败，请重试',
          ),
    );
  }
}

class _DesktopVideoCollectionDetailLoadingState extends StatelessWidget {
  const _DesktopVideoCollectionDetailLoadingState();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      key: const Key('video-collection-detail-loading'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AppSkeletonBlock(width: 196, height: 24),
            const Spacer(),
            AppSkeletonBlock(
              width: 84,
              height: context.appComponentTokens.buttonHeightSm,
              radius: context.appRadius.pillBorder,
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        const AppSkeletonBlock(width: 320, height: 14),
        SizedBox(height: spacing.md),
        Row(
          children: [
            AppSkeletonBlock(
              width: 96,
              height: context.appComponentTokens.buttonHeightXs,
              radius: context.appRadius.pillBorder,
            ),
            SizedBox(width: spacing.sm),
            const AppSkeletonBlock(width: 68, height: 14),
            const Spacer(),
            AppSkeletonBlock(
              width: context.appComponentTokens.buttonHeightSm,
              height: context.appComponentTokens.buttonHeightSm,
              radius: context.appRadius.mdBorder,
            ),
          ],
        ),
        SizedBox(height: spacing.lg),
        Expanded(
          child: ListView.separated(
            key: const Key('video-collection-detail-skeleton-list'),
            itemCount: 6,
            separatorBuilder: (_, _) => SizedBox(height: spacing.sm),
            itemBuilder: (_, _) =>
                const _DesktopVideoCollectionMemberSkeleton(),
          ),
        ),
      ],
    );
  }
}

class _DesktopVideoCollectionMemberSkeleton extends StatelessWidget {
  const _DesktopVideoCollectionMemberSkeleton();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Container(
      height: 80,
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: double.infinity,
            decoration: BoxDecoration(
              color: context.appColors.surfaceMuted,
              borderRadius: context.appRadius.smBorder,
            ),
          ),
          SizedBox(width: spacing.md),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBlock(width: double.infinity, height: 14),
                SizedBox(height: 8),
                AppSkeletonBlock(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
