import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/interaction/app_cover_hover_info.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_cover_card.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 时刻卡：整卡即封面，收起态不铺任何文字；桌面端指针悬停时底部渐显单行
/// 「番号 / 视频号 + 内容类型 · 时刻位置」与靠右的播放按钮。
///
/// 触摸端没有 hover（移动端靠点击预览与长按多选），触屏停在收起态。
class MomentCard extends StatelessWidget {
  const MomentCard({
    super.key,
    required this.item,
    this.onTap,
    this.onPlay,
    this.onOpenMovie,
    this.onAddToCollection,
    this.onDelete,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    this.onLongPress,
  });

  final MomentListItem item;
  final VoidCallback? onTap;

  /// 悬停面板里的播放主按钮回调（跳播到该时刻）;为 `null` 时不显示按钮。
  final VoidCallback? onPlay;

  /// 悬停面板里的「影片」动作（跳到来源影片详情）；为 `null` 时不显示。
  final VoidCallback? onOpenMovie;

  /// 悬停面板里的「加入合集」动作；为 `null` 时不显示。
  final VoidCallback? onAddToCollection;

  /// 悬停面板里的「删除」动作（删除时刻标记本体）；为 `null` 时不显示。
  final VoidCallback? onDelete;

  final bool selectionMode;
  final bool isSelected;
  final ValueChanged<bool>? onSelectedChanged;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final handleTap = selectionMode
        ? onSelectedChanged == null
              ? null
              : () => onSelectedChanged!(!isSelected)
        : onTap;
    return AppInteractiveSurface(
      key: Key('moment-card-${item.pointId}'),
      onTap: handleTap,
      onLongPress: onLongPress,
      child: AppCoverCard(
        hoverEnabled: !selectionMode,
        selectionMode: selectionMode,
        isSelected: isSelected,
        cover: MaskedImage(url: item.image?.origin ?? '', fit: BoxFit.cover),
        infoBuilder: (context) => _buildHoverInfo(context),
      ),
    );
  }

  /// 悬停展开内容：单行「标签 + 类型 · 时刻位置（来源已删除时补提示）」，
  /// 下方一整行动作按钮（播放 / 影片 / 加入合集 / 删除，按回调是否为空显隐）。
  Widget _buildHoverInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 与时刻预览的播放入口对齐：来源媒体已删除（mediaId<=0）时不提供播放，
    // 避免播到该影片的其它媒体。
    return AppCoverHoverPanel(
      info: AppCoverHoverInfoRow(
        key: Key('moment-card-info-${item.pointId}'),
        label: item.localizedDisplayLabel(l10n),
        meta: item.localizedHoverMeta(l10n),
      ),
      actions: [
        if (onPlay != null && item.mediaId > 0)
          AppCoverHoverActionButton(
            key: Key('moment-card-play-${item.pointId}'),
            icon: Icons.play_arrow_rounded,
            onTap: onPlay,
            primary: true,
            tooltip: l10n.widgetMomentActionPlay,
          ),
        if (onOpenMovie != null)
          AppCoverHoverActionButton(
            key: Key('moment-card-movie-${item.pointId}'),
            icon: Icons.movie_outlined,
            onTap: onOpenMovie,
            tooltip: l10n.widgetMomentActionMovie,
          ),
        if (onAddToCollection != null)
          AppCoverHoverActionButton(
            key: Key('moment-card-add-collection-${item.pointId}'),
            icon: Icons.playlist_add_rounded,
            onTap: onAddToCollection,
            tooltip: l10n.widgetMomentActionAddToCollection,
          ),
        if (onDelete != null)
          AppCoverHoverActionButton(
            key: Key('moment-card-delete-${item.pointId}'),
            icon: Icons.delete_outline_rounded,
            onTap: onDelete,
            tooltip: l10n.widgetMomentActionDelete,
          ),
      ],
    );
  }
}
