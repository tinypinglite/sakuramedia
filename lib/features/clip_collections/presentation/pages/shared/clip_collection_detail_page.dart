import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/shared/clip_collection_detail_content.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/add_clips_to_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/actions/clip_playback_launcher.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_actions_panel.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';

/// 切片合集详情壳。平台差异只保留一个 [mobile] 维度和几个真实分叉点。
class ClipCollectionDetailPage extends StatelessWidget {
  const ClipCollectionDetailPage({
    super.key,
    required this.collectionId,
    required this.mobile,
  });

  final int collectionId;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return ClipCollectionDetailContent(
      collectionId: collectionId,
      keyPrefix: mobile ? 'mobile-clip-collection' : 'clip-collection',
      useMobileSelectionLayout: mobile,
      hoistTitleToSubpageShell: mobile,
      playAllBuilder: _buildPlayAll,
      onMemberTap: (context, clip, actions) {
        showClipActions(
          context,
          clip: clip,
          onPlay: () => actions.playSingle(context, clip),
          onOpenMovie: _openMovieCallback(context, clip),
          onRemoveFromCollection: () => actions.remove(clip),
          onDelete: () => actions.delete(clip),
          variant: mobile
              ? AppAdaptiveModalVariant.drawer
              : AppAdaptiveModalVariant.dialog,
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
            dialogKey: mobile ? drawerKey : null,
            confirmKey: confirmKey,
            onConfirm: onConfirm,
            failureFallback: AppLocalizations.of(
              context,
            ).clipCollectionDeleteFailed,
          ),
      onEditCollection: (context, collection) {
        return showEditClipCollectionDialog(
          context,
          collection: collection,
          presentation: mobile
              ? CollectionEditorPresentation.drawer
              : CollectionEditorPresentation.dialog,
        );
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

  Widget _buildPlayAll(
    BuildContext context, {
    required bool enabled,
    required VoidCallback onPlayFrom,
  }) {
    if (mobile) {
      return AppTextButton(
        key: const Key('mobile-clip-collection-play-all-button'),
        label: AppLocalizations.of(context).clipCollectionPlay,
        size: AppTextButtonSize.xSmall,
        onPressed: onPlayFrom,
      );
    }
    return AppButton(
      key: const Key('clip-collection-play-all-button'),
      label: AppLocalizations.of(context).clipCollectionPlayAll,
      variant: AppButtonVariant.primary,
      onPressed: enabled ? onPlayFrom : null,
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
    if (mobile) {
      MobileRoutes.movieDetail(movieNumber: movieNumber).push(context);
    } else {
      DesktopRoutes.movieDetail(movieNumber: movieNumber).push(context);
    }
  }
}
