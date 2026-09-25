import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/shared/clip_collection_detail_content.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/add_clips_to_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/actions/clip_playback_launcher.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_actions_panel.dart';

/// 桌面切片合集详情壳：桌面语义（网格 / hover / 顶栏内联批量 /
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
      playAllBuilder: (context, {required enabled, required onPlayFrom}) {
        return AppButton(
          key: const Key('clip-collection-play-all-button'),
          label: '播放全部',
          variant: AppButtonVariant.primary,
          onPressed: enabled ? onPlayFrom : null,
        );
      },
      onMemberTap: (context, clip, actions) {
        showClipActionsDialog(
          context,
          clip: clip,
          onPlay: () => actions.playSingle(context, clip),
          onOpenMovie: _openMovieCallback(context, clip),
          onRemoveFromCollection: () => actions.remove(clip),
          onDelete: () => actions.delete(clip),
        );
      },
      playSingle: (context, clip) {
        return launchClipPlayback(
          context,
          streamUrl: clip.streamUrl,
          title: clip.title,
        );
      },
      onOpenMovie: (context, clip) => _pushMovie(context, clip),
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

  VoidCallback? _openMovieCallback(BuildContext context, MediaClipDto clip) {
    final movieNumber = clip.movieNumber;
    if (movieNumber == null || movieNumber.isEmpty) {
      return null;
    }
    return () => _pushMovie(context, clip);
  }

  void _pushMovie(BuildContext context, MediaClipDto clip) {
    final movieNumber = clip.movieNumber;
    if (movieNumber == null || movieNumber.isEmpty) {
      return;
    }
    context.pushDesktopMovieDetail(movieNumber: movieNumber);
  }
}
