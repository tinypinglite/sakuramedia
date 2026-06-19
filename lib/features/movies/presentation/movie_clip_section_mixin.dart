import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/presentation/add_to_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/clips_api.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/clip_mutation_change_notifier.dart';
import 'package:sakuramedia/features/clips/presentation/rename_clip_dialog.dart';
import 'package:sakuramedia/features/movies/presentation/movie_clips_controller.dart';
import 'package:sakuramedia/widgets/clips/clip_player_dialog.dart';
import 'package:sakuramedia/widgets/feedback/app_confirm_dialog.dart';

/// 影片详情页「切片」区块的交互动作集合，供桌面 / 移动两端详情页 `with` 复用，
/// 避免播放 / 改名 / 删除 / 加入合集这套 handler 在两端逐行重复。
///
/// 这些动作离不开 `BuildContext`（弹窗 / 确认框），故留在页面侧；数据状态由
/// [MovieClipsController] 持有。删除成功后广播 [ClipMutationChangeNotifier]，
/// 控制器监听后就地移除（无需手动回写），同时让「我的切片」页同步。
mixin MovieClipSectionMixin<T extends StatefulWidget> on State<T> {
  /// 子类暴露本页持有的切片控制器。
  MovieClipsController get movieClipsController;

  void playMovieClip(MediaClipDto clip) {
    showClipPlayerDialog(context, streamUrl: clip.streamUrl, title: clip.title);
  }

  Future<void> renameMovieClip(MediaClipDto clip) async {
    final newTitle = await showRenameClipDialog(
      context,
      initialTitle: clip.title,
    );
    if (!mounted || newTitle == null) {
      return;
    }
    try {
      final updated = await context.read<ClipsApi>().updateClipTitle(
        clipId: clip.clipId,
        title: newTitle,
      );
      movieClipsController.replaceClip(updated);
      if (mounted) {
        showToast('已重命名');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '重命名失败，请重试'));
    }
  }

  Future<void> deleteMovieClip(MediaClipDto clip) async {
    final title = clip.title.trim().isEmpty ? '该切片' : '“${clip.title.trim()}”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除切片',
      message: '确认删除$title？切片文件会被一并删除，该操作不可恢复。',
      danger: true,
      confirmLabel: '删除',
      confirmKey: const Key('movie-clip-delete-confirm-button'),
    );
    if (!mounted || !confirmed) {
      return;
    }
    try {
      await context.read<ClipsApi>().deleteClip(clipId: clip.clipId);
      // 广播删除：本页控制器与「我的切片」页监听后各自就地移除。
      context.read<ClipMutationChangeNotifier>().reportDeleted(clip.clipId);
      if (mounted) {
        showToast('已删除切片');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '删除失败，请重试'));
    }
  }

  Future<void> addMovieClipToCollection(MediaClipDto clip) async {
    await showAddToClipCollectionDialog(context, clipId: clip.clipId);
    if (!mounted) {
      return;
    }
    // 合集归属可能变化（含新建）：广播信号，由切片各页统一刷新合集区。
    context.read<ClipMutationChangeNotifier>().reportCollectionMembershipChanged(
      clipId: clip.clipId,
    );
  }
}
