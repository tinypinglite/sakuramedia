import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/presentation/actions/video_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_collection_detail_content.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_actions_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/video_display_title.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';

/// 桌面视频合集详情壳：桌面语义（网格 / hover / 顶栏内联批量 /
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
    final l10n = AppLocalizations.of(context);
    return VideoCollectionDetailContent(
      collectionId: collectionId,
      surfaceColor: context.appColors.surfaceElevated,
      keyPrefix: 'video-collection',
      useMobileSelectionLayout: false,
      hoistTitleToSubpageShell: false,
      useMobileSortDrawer: false,
      playAllBuilder: (context, {required enabled, required onPlayFrom}) {
        return AppGlassHeaderButton(
          key: const Key('video-collection-play-all-button'),
          icon: Icons.play_arrow_rounded,
          label: l10n.videoPlayAll,
          enabled: enabled,
          onTap: onPlayFrom,
          foregroundColor: Theme.of(context).colorScheme.primary,
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
          onPlay: () =>
              actions.playSingle(context, video.id, video.displayTitle(l10n)),
          onThumbnails: () =>
              context.pushDesktopVideoThumbnails(videoId: video.id),
          onRemoveFromCollection: () => actions.remove(item.video.id),
          onDelete: () => actions.delete(item.video.id),
          collections: otherCollections,
          onCollectionTap: (ref) =>
              context.pushDesktopVideoCollectionDetail(collectionId: ref.id),
        );
      },
      playSingle: (context, videoId, title) async {
        if (await tryLaunchExternalVideoPlayback(
          context,
          videoId: videoId,
          title: title,
        )) {
          return;
        }
        if (!context.mounted) {
          return;
        }
        context.pushDesktopVideoPlayer(videoId: videoId);
      },
      onOpenCollection: (context, targetId) {
        context.pushDesktopVideoCollectionDetail(collectionId: targetId);
      },
      confirm:
          (
            context, {
            required title,
            required message,
            required confirmLabel,
            required confirmKey,
            drawerKey,
            onConfirm,
          }) => showAppConfirmDialog(
            context,
            title: title,
            message: message,
            danger: true,
            confirmLabel: confirmLabel,
            confirmKey: confirmKey,
            onConfirm: onConfirm,
            failureFallback: l10n.videoDeleteFailed,
          ),
    );
  }
}
