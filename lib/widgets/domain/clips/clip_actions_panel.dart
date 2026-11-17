import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/media/media_action_preview_header.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_action_grid.dart';

/// 切片操作面板：封面预览 + 标题/元信息 + 横向操作格。
///
/// 移动端点击切片卡 / 行后从底部弹出，桌面端点击合集成员后居中弹窗；
/// 封面 / 番号 / 时长 / 大小本地都有，无需额外请求。动作按调用方传入的回调动态展示。
class ClipActionsPanel extends StatelessWidget {
  const ClipActionsPanel({
    super.key,
    required this.clip,
    required this.keyPrefix,
    required this.onPlay,
    this.onOpenMovie,
    this.onAddToCollection,
    this.onRename,
    this.onDelete,
    this.onRemoveFromCollection,
  });

  final MediaClipDto clip;
  final String keyPrefix;
  final VoidCallback onPlay;
  final VoidCallback? onOpenMovie;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onRemoveFromCollection;

  // 先关闭弹层再执行动作，避免弹层叠弹层。
  void _run(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  List<MediaPreviewActionItem> _buildActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <MediaPreviewActionItem>[
      MediaPreviewActionItem(
        key: Key('$keyPrefix-action-play'),
        label: l10n.widgetClipActionPlay,
        icon: Icons.play_circle_outline_rounded,
        onTap: () => _run(context, onPlay),
      ),
      if (onOpenMovie != null)
        MediaPreviewActionItem(
          key: Key('$keyPrefix-action-movie'),
          label: l10n.widgetClipActionMovie,
          icon: Icons.movie_outlined,
          onTap: () => _run(context, onOpenMovie!),
        ),
      if (onAddToCollection != null)
        MediaPreviewActionItem(
          key: Key('$keyPrefix-action-add-to-collection'),
          label: l10n.widgetClipActionAddToCollection,
          icon: Icons.playlist_add_rounded,
          onTap: () => _run(context, onAddToCollection!),
        ),
      if (onRename != null)
        MediaPreviewActionItem(
          key: Key('$keyPrefix-action-rename'),
          label: l10n.widgetClipActionRename,
          icon: Icons.edit_outlined,
          onTap: () => _run(context, onRename!),
        ),
      if (onRemoveFromCollection != null)
        MediaPreviewActionItem(
          key: Key('$keyPrefix-action-remove-from-collection'),
          label: l10n.widgetClipActionRemoveFromCollection,
          icon: Icons.playlist_remove_rounded,
          onTap: () => _run(context, onRemoveFromCollection!),
        ),
      if (onDelete != null)
        MediaPreviewActionItem(
          key: Key('$keyPrefix-action-delete'),
          label: l10n.commonDelete,
          icon: Icons.delete_outline_rounded,
          onTap: () => _run(context, onDelete!),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final coverUrl = clip.coverImage?.origin;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MediaActionPreviewHeader(
            coverUrl: coverUrl,
            coverFit: BoxFit.cover,
            durationSeconds: clip.durationSeconds,
            onPlay: () => _run(context, onPlay),
            title: clip.displayTitle(l10n),
            subtitle: clip.metaLine(l10n),
          ),
          SizedBox(height: spacing.lg),
          MediaPreviewActionGrid(
            gridKey: Key('$keyPrefix-actions-grid'),
            layout: MediaPreviewActionGridLayout.horizontalScroll,
            spacing: spacing.xs,
            tileWidth: 64,
            actions: _buildActions(context),
          ),
        ],
      ),
    );
  }
}

/// 切片操作弹层：按 [variant] 走底部抽屉 / 居中弹窗 / 平台自适应。
Future<void> showClipActions(
  BuildContext context, {
  required MediaClipDto clip,
  required VoidCallback onPlay,
  VoidCallback? onOpenMovie,
  VoidCallback? onAddToCollection,
  VoidCallback? onRename,
  VoidCallback? onDelete,
  VoidCallback? onRemoveFromCollection,
  AppAdaptiveModalVariant variant = AppAdaptiveModalVariant.auto,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    variant: variant,
    dialogKey: const Key('clip-actions-dialog'),
    drawerKey: const Key('mobile-clip-actions-sheet'),
    desktopWidth: context.appComponentTokens.playlistDialogWidth,
    mobileMaxHeightFactor: 0.62,
    builder: (_) => Builder(
      builder: (modalContext) => ClipActionsPanel(
        clip: clip,
        keyPrefix: AppAdaptiveModalShellScope.maybeIsDrawer(modalContext)
            ? 'mobile-clip'
            : 'clip',
        onPlay: onPlay,
        onOpenMovie: onOpenMovie,
        onAddToCollection: onAddToCollection,
        onRename: onRename,
        onDelete: onDelete,
        onRemoveFromCollection: onRemoveFromCollection,
      ),
    ),
  );
}
