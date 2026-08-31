import 'package:flutter/material.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/clip_confirm_drawer.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_actions_sheet.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_player_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_collection_detail_content.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';

export 'package:sakuramedia/features/videos/presentation/pages/shared/video_collection_detail_content.dart'
    show CollectionDetailLayout;

/// 移动视频合集详情壳：移动语义（网格默认 / 长按进多选 / 底部批量条 /
/// 底部抽屉筛选 / 动作抽屉与确认抽屉 / 标题报返回栏）收在壳里，实现在
/// [VideoCollectionDetailContent]。
class MobileVideoCollectionDetailPage extends StatelessWidget {
  const MobileVideoCollectionDetailPage({
    super.key,
    required this.collectionId,
  });

  final int collectionId;

  @override
  Widget build(BuildContext context) {
    return VideoCollectionDetailContent(
      collectionId: collectionId,
      surfaceColor: context.appColors.surfaceCard,
      keyPrefix: 'mobile-video-collection',
      useMobileSelectionLayout: true,
      hoistTitleToSubpageShell: true,
      useMobileFilterDrawer: true,
      enableReorder: false,
      defaultLayout: CollectionDetailLayout.grid,
      loadingBuilder: (_) => const AppMobileSkeletonList(
        key: Key('mobile-video-collection-detail-loading'),
      ),
      playAllBuilder: (context, {required enabled, required onPlayFrom}) {
        return AppTextButton(
          key: const Key('mobile-video-collection-play-all-button'),
          label: '播放',
          size: AppTextButtonSize.xSmall,
          onPressed: onPlayFrom,
        );
      },
      onMemberTap: (context, item, actions) {
        final video = item.video;
        // 过滤掉「当前合集」这条冗余归属：用户已经在这里了。
        final otherCollections = video.collections
            .where((ref) => ref.id != collectionId)
            .toList(growable: false);
        showMobileVideoActionsSheet(
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
              (ref) => MobileVideoCollectionDetailRouteData(
                collectionId: ref.id,
              ).push(context),
        );
      },
      playSingle: (context, videoId, title) async {
        // 用根 Navigator 推全屏页，覆盖底部导航。
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder:
                (_) => MobileVideoPlayerPage(videoId: videoId, title: title),
          ),
        );
      },
      onOpenCollection: (context, targetId) {
        MobileVideoCollectionDetailRouteData(
          collectionId: targetId,
        ).push(context);
      },
      confirm: (
        context, {
        required title,
        required message,
        required confirmLabel,
        required confirmKey,
        drawerKey,
      }) async {
        final confirmed = await showMobileClipConfirmDrawer(
          context,
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          drawerKey: drawerKey,
          confirmButtonKey: confirmKey,
        );
        return confirmed == true;
      },
    );
  }
}
