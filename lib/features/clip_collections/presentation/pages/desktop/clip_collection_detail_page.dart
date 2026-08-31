import 'package:flutter/material.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/shared/clip_collection_detail_content.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/add_clips_to_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_player_dialog.dart';

export 'package:sakuramedia/features/clip_collections/presentation/pages/shared/clip_collection_detail_content.dart'
    show ClipCollectionDetailLayout;

/// 桌面切片合集详情壳：桌面语义（网格默认 / 拖序 + hover / 顶栏内联批量 /
/// 桌面对话框 / 直接播放切片）收在壳里，实现在 [ClipCollectionDetailContent]。
class DesktopClipCollectionDetailPage extends StatelessWidget {
  const DesktopClipCollectionDetailPage({
    super.key,
    required this.collectionId,
  });

  final int collectionId;

  @override
  Widget build(BuildContext context) {
    return ClipCollectionDetailContent(
      collectionId: collectionId,
      surfaceColor: context.appColors.surfaceElevated,
      keyPrefix: 'clip-collection',
      useMobileSelectionLayout: false,
      hoistTitleToSubpageShell: false,
      enableReorder: true,
      defaultLayout: ClipCollectionDetailLayout.grid,
      loadingBuilder: (_) => const Center(
        child: SizedBox(
          key: Key('clip-collection-detail-loading'),
          width: 40,
          height: 40,
          child: CircularProgressIndicator(),
        ),
      ),
      playAllBuilder: (context, {required enabled, required onPlayFrom}) {
        return AppButton(
          key: const Key('clip-collection-play-all-button'),
          label: '播放全部',
          variant: AppButtonVariant.primary,
          onPressed: enabled ? onPlayFrom : null,
        );
      },
      onMemberTap: (context, clip, actions) {
        actions.playSingle(context, clip);
      },
      playSingle: (context, clip) async {
        showClipPlayerDialog(
          context,
          streamUrl: clip.streamUrl,
          title: clip.title,
        );
      },
      onOpenMovie: (context, clip) {
        final movieNumber = clip.movieNumber;
        if (movieNumber == null || movieNumber.isEmpty) {
          return;
        }
        context.pushDesktopMovieDetail(movieNumber: movieNumber);
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
      onEditCollection: (context, collection) async {
        return showEditClipCollectionDialog(context, collection: collection);
      },
      onAddClips: (context, memberClipIds) async {
        await showAddClipsToCollectionDialog(
          context,
          collectionId: collectionId,
          memberClipIds: memberClipIds,
        );
      },
    );
  }
}
