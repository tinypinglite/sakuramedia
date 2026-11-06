import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/add_to_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/actions/clip_playback_launcher.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clip_mutation_events_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/features/clips/presentation/widgets/rename_clip_dialog.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_clips_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_actions_panel.dart';

/// 影片详情页「切片」区块的交互动作集合，供桌面 / 移动两端详情页 `with` 复用，
/// 避免播放 / 改名 / 删除 / 加入合集这套 handler 在两端逐行重复。
///
/// 这些动作离不开 `BuildContext`（弹窗 / 确认框），故留在页面侧；数据状态由
/// `movieClipsProvider(movieNumber)` 持有。删除成功后广播
/// `clipMutationEventsProvider`，provider 内部 `ref.listen` 后就地移除
/// （无需手动回写），同时让「我的切片」页同步。
mixin MovieClipSectionMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// 子类暴露本页的影片番号（用于取对应 provider 实例）。
  String get movieNumber;

  /// 点击切片卡的入口：移动端弹底部抽屉、桌面端弹居中弹窗，由用户再选择播放 /
  /// 改名 / 删除 / 加入合集，避免误触即播放。[playMovieClip] 为其中的原始播放动作。
  Future<void> openMovieClipActions(MediaClipDto clip) {
    return showAppAdaptiveModal<void>(
      context: context,
      modalKey: const Key('movie-detail-clip-actions'),
      mobileMaxHeightFactor: 0.62,
      builder: (_) => ClipActionsPanel(
        clip: clip,
        keyPrefix: 'movie-detail-clip',
        onPlay: () => playMovieClip(clip),
        onAddToCollection: () => addMovieClipToCollection(clip),
        onRename: () => renameMovieClip(clip),
        onDelete: () => deleteMovieClip(clip),
      ),
    );
  }

  Future<void> playMovieClip(MediaClipDto clip) {
    return launchClipPlayback(
      context,
      streamUrl: clip.streamUrl,
      title: clip.title,
    );
  }

  Future<void> renameMovieClip(MediaClipDto clip) async {
    final l10n = AppLocalizations.of(context);
    final newTitle = await showRenameClipDialog(
      context,
      initialTitle: clip.title,
    );
    if (!mounted || newTitle == null) {
      return;
    }
    try {
      final updated = await ref
          .read(clipsApiProvider)
          .updateClipTitle(clipId: clip.clipId, title: newTitle);
      if (!mounted) return;
      ref.read(movieClipsProvider(movieNumber).notifier).replaceClip(updated);
      showToast(l10n.movieControllerClipRenamed, tone: AppToastTone.success);
    } catch (error) {
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.movieControllerClipRenameFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  Future<void> deleteMovieClip(MediaClipDto clip) async {
    final l10n = AppLocalizations.of(context);
    final clipTitle = clip.title.trim();
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.movieControllerClipDeleteTitle,
      message: clipTitle.isEmpty
          ? l10n.movieControllerClipDeleteMessageUnnamed
          : l10n.movieControllerClipDeleteMessage(clipTitle),
      danger: true,
      confirmLabel: l10n.commonDelete,
      confirmKey: const Key('movie-clip-delete-confirm-button'),
    );
    if (!mounted || !confirmed) {
      return;
    }
    try {
      await ref.read(clipsApiProvider).deleteClip(clipId: clip.clipId);
      if (!mounted) return;
      // 广播删除：本页 provider 与「我的切片」页监听后各自就地移除。
      ref.read(clipMutationEventsProvider.notifier).reportDeleted(clip.clipId);
      showToast(l10n.movieControllerClipDeleted, tone: AppToastTone.success);
    } catch (error) {
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.movieControllerClipDeleteFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  Future<void> addMovieClipToCollection(MediaClipDto clip) async {
    await showAddToClipCollectionDialog(context, clipId: clip.clipId);
    if (!mounted) {
      return;
    }
    // 合集归属可能变化（含新建）：广播信号，由切片各页统一刷新合集区。
    ref
        .read(clipMutationEventsProvider.notifier)
        .reportCollectionMembershipChanged(clipId: clip.clipId);
  }
}
