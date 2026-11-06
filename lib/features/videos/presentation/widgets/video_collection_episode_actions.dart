import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/video_display_title.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/interaction/app_context_menu_trigger.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_episode_queue_item.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

enum VideoCollectionEpisodeAction { remove, delete }

/// [presentation] 由触发方式决定：行长按 / 右键用
/// [AppMenuPresentation.popup]（锚定浮层），行尾「更多」按钮在移动端用
/// [AppMenuPresentation.bottomDrawer]（底部操作表）。
Future<VideoCollectionEpisodeAction?> showVideoCollectionEpisodeActions({
  required BuildContext context,
  required String title,
  required AppMenuPresentation presentation,
  Offset position = Offset.zero,
}) {
  final isDrawer = presentation == AppMenuPresentation.bottomDrawer;
  final l10n = AppLocalizations.of(context);
  return showAppActionMenu<VideoCollectionEpisodeAction>(
    context: context,
    globalPosition: position,
    presentation: presentation,
    drawerKey: const Key('video-episode-actions'),
    title: isDrawer ? title : null,
    items: <AppMenuItem<VideoCollectionEpisodeAction>>[
      AppMenuItem(
        key: Key('video-episode-action-remove'),
        value: VideoCollectionEpisodeAction.remove,
        label: l10n.videoRemoveFromCollection,
        subtitle: l10n.videoEpisodeRemoveSubtitle,
        icon: Icons.playlist_remove_rounded,
      ),
      AppMenuItem(
        key: Key('video-episode-action-delete'),
        value: VideoCollectionEpisodeAction.delete,
        label: l10n.videoEpisodeDeleteTitle,
        subtitle: l10n.videoEpisodeDeleteSubtitle,
        icon: Icons.delete_outline_rounded,
        tone: AppTextTone.error,
      ),
    ],
  );
}

Future<bool> showVideoEpisodeDeleteConfirmation({
  required BuildContext context,
  required String title,
  required Future<void> Function() onConfirm,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppConfirmDialog(
    context,
    title: l10n.videoEpisodeDeleteTitle,
    message: l10n.videoEpisodeDeleteMessage,
    extraContent: Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        tone: AppTextTone.primary,
      ),
    ),
    confirmLabel: l10n.videoEpisodeDeleteTitle,
    danger: true,
    // 横屏使用紧凑确认窗；菜单仍为移动操作表。
    variant: AppConfirmVariant.dialog,
    confirmKey: const Key('video-episode-delete-confirm'),
    onConfirm: onConfirm,
  );
}

class VideoEpisodeQueueItem extends StatelessWidget {
  const VideoEpisodeQueueItem({
    super.key,
    required this.video,
    required this.index,
    required this.isCurrent,
    required this.isBusy,
    required this.onPlay,
    required this.onContextActions,
    this.onMoreActions,
  });

  final VideoItemListItemDto video;
  final int index;
  final bool isCurrent;
  final bool isBusy;
  final VoidCallback? onPlay;

  /// 行长按 / 右键 → 锚定浮层，回调带按压点全局坐标。
  final ValueChanged<Offset>? onContextActions;

  /// 行尾「更多」按钮 → 移动端底部操作表 / 桌面浮层，回调带按钮右下角坐标。
  final ValueChanged<Offset>? onMoreActions;

  @override
  Widget build(BuildContext context) {
    final onContextActions = this.onContextActions;
    final onMoreActions = this.onMoreActions;
    final l10n = AppLocalizations.of(context);
    final item = CollectionEpisodeQueueItem(
      itemKey: Key('video-collection-play-queue-item-${video.id}'),
      coverUrl: video.coverImage?.origin,
      coverStyle: CollectionQueueCoverStyle.containOnMuted,
      title: video.displayTitle(l10n),
      subtitle: l10n.videoEpisodeIndex(index + 1),
      isCurrent: isCurrent,
      onTap: onPlay,
      trailing: Builder(
        builder: (buttonContext) => AppIconButton(
          key: Key('video-episode-more-${video.id}'),
          size: AppIconButtonSize.regular,
          tooltip: l10n.videoEpisodeActionsTooltip,
          icon: isBusy
              ? SizedBox.square(
                  dimension: context.appComponentTokens.iconSizeSm,
                  child: const CircularProgressIndicator.adaptive(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.more_horiz_rounded),
          onPressed: onMoreActions == null
              ? null
              : () {
                  final box = buttonContext.findRenderObject()! as RenderBox;
                  onMoreActions(
                    box.localToGlobal(Offset(box.size.width, box.size.height)),
                  );
                },
        ),
      ),
    );
    if (onContextActions == null) {
      return item;
    }
    return AppContextMenuTrigger(onRequestMenu: onContextActions, child: item);
  }
}
