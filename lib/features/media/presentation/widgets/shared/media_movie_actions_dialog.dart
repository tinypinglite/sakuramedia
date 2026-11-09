import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/media/media_action_preview_header.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_action_grid.dart';

/// 媒体列表 JAV 行点击后的弹层动作；由调用方在弹层关闭后执行
/// （避免跳路由 / 起播被正在关闭的弹层一起 pop）。
enum MediaMovieAction { play, openMovieDetail }

/// JAV 媒体行的「影片操作」弹层：桌面居中对话弹窗、移动端底部抽屉。
///
/// 版式对齐视频操作弹窗（`video_actions_panel.dart`）：封面预览 + 标题 +
/// 横排操作格；JAV 媒体只承载「播放（这条媒体）/ 影片详情」两个入口，
/// 迁移 / 删除等媒体级动作仍留在行卡图标上。
Future<MediaMovieAction?> showMediaMovieActionsOverlay({
  required BuildContext context,
  required MediaListItemDto item,
  required bool mobile,
  bool canOpenMovieDetail = false,
}) {
  final content = _MediaMovieActionsContent(
    item: item,
    mobile: mobile,
    canOpenMovieDetail: canOpenMovieDetail,
  );
  return showAppAdaptiveModal<MediaMovieAction>(
    context: context,
    variant: mobile
        ? AppAdaptiveModalVariant.drawer
        : AppAdaptiveModalVariant.dialog,
    dialogKey: const Key('media-row-movie-actions-dialog'),
    drawerKey: const Key('media-row-movie-actions-drawer'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    mobileMaxHeightFactor: 0.62,
    builder: (_) => content,
  );
}

class _MediaMovieActionsContent extends StatelessWidget {
  const _MediaMovieActionsContent({
    required this.item,
    required this.mobile,
    required this.canOpenMovieDetail,
  });

  final MediaListItemDto item;
  final bool mobile;
  final bool canOpenMovieDetail;

  bool get _canPlay => item.valid;

  /// 桌面弹窗与移动抽屉都用 16:9 预览框：宽图直接裁切填满，回退到窄图时居中留边。
  String? get _coverUrl => mobile ? item.preferredCoverUrl : item.wideCoverUrl;

  BoxFit get _coverFit {
    final isLandscape = mobile
        ? !item.usesThinCover && item.hasWideCover
        : item.hasWideCover;
    return isLandscape ? BoxFit.cover : BoxFit.contain;
  }

  void _run(BuildContext context, MediaMovieAction action) {
    Navigator.of(context).pop(action);
  }

  Widget _buildActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MediaPreviewActionGrid(
      gridKey: const Key('media-row-movie-actions-grid'),
      layout: MediaPreviewActionGridLayout.horizontalScroll,
      spacing: context.appSpacing.sm,
      tileWidth: 72,
      actions: [
        MediaPreviewActionItem(
          key: const Key('media-row-movie-actions-play'),
          label: l10n.mediaListActionPlay,
          icon: Icons.play_circle_outline_rounded,
          onTap: _canPlay ? () => _run(context, MediaMovieAction.play) : null,
        ),
        if (canOpenMovieDetail)
          MediaPreviewActionItem(
            key: const Key('media-row-movie-actions-open-detail'),
            label: l10n.mediaListActionMovieDetail,
            icon: Icons.info_outline_rounded,
            onTap: () => _run(context, MediaMovieAction.openMovieDetail),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaActionPreviewHeader(
          coverUrl: _coverUrl,
          coverFit: _coverFit,
          coverKey: const Key('media-row-movie-actions-cover'),
          durationSeconds: item.durationSeconds,
          onPlay: _canPlay ? () => _run(context, MediaMovieAction.play) : null,
          playButtonKey: const Key('media-row-movie-actions-center-play'),
          title: item.displayHeading(AppLocalizations.of(context)),
          titleKey: const Key('media-row-movie-actions-title'),
          titleMaxLines: 1,
          subtitle: item.displaySubtitle,
        ),
        SizedBox(height: spacing.lg),
        _buildActions(context),
      ],
    );
    if (mobile) {
      return SingleChildScrollView(child: body);
    }
    // 关闭按钮浮在弹窗右上角；标题区不吃封面宽度，无需额外让位。
    return body;
  }
}
