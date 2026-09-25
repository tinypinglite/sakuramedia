import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_card.dart';

class MomentGrid extends StatelessWidget {
  const MomentGrid({
    super.key,
    required this.items,
    required this.onItemTap,
    this.onItemPlay,
    this.onItemOpenMovie,
    this.onItemAddToCollection,
    this.onItemDelete,
    this.maxRows,
    this.selectionMode = false,
    this.isSelected,
    this.onSelectedChanged,
    this.onLongPress,
  });

  final List<MomentListItem> items;
  final ValueChanged<MomentListItem> onItemTap;

  /// 卡片悬停面板里的播放回调（跳播到该时刻）；不传则 hover 不显示播放键。
  final ValueChanged<MomentListItem>? onItemPlay;

  /// 卡片悬停面板里的「影片」回调；不传则不显示。
  final ValueChanged<MomentListItem>? onItemOpenMovie;

  /// 卡片悬停面板里的「加入合集」回调；不传则不显示。
  final ValueChanged<MomentListItem>? onItemAddToCollection;

  /// 卡片悬停面板里的「删除」回调；不传则不显示。
  final ValueChanged<MomentListItem>? onItemDelete;

  /// 首页等预览区可限制为固定行数；列表页保持不传以展示全部项目。
  final int? maxRows;

  final bool selectionMode;
  final bool Function(MomentListItem item)? isSelected;
  final ValueChanged<MomentListItem>? onSelectedChanged;
  final ValueChanged<MomentListItem>? onLongPress;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardGrid<MomentListItem>(
      gridKey: const Key('moment-grid'),
      items: items,
      childAspectRatio: 16 / 10,
      maxRows: maxRows,
      itemBuilder: (context, item, _) => MomentCard(
        item: item,
        onTap: () => onItemTap(item),
        onPlay: onItemPlay == null ? null : () => onItemPlay!(item),
        onOpenMovie: onItemOpenMovie == null
            ? null
            : () => onItemOpenMovie!(item),
        onAddToCollection: onItemAddToCollection == null
            ? null
            : () => onItemAddToCollection!(item),
        onDelete: onItemDelete == null ? null : () => onItemDelete!(item),
        selectionMode: selectionMode,
        isSelected: isSelected?.call(item) ?? false,
        onSelectedChanged: onSelectedChanged == null
            ? null
            : (_) => onSelectedChanged!(item),
        onLongPress: onLongPress == null ? null : () => onLongPress!(item),
      ),
    );
  }
}

/// 累计分页时刻列表使用的 Sliver 网格版本。
class MomentSliver extends StatelessWidget {
  const MomentSliver({
    super.key,
    required this.items,
    required this.onItemTap,
    this.onItemPlay,
    this.onItemOpenMovie,
    this.onItemAddToCollection,
    this.onItemDelete,
    this.selectionMode = false,
    this.isSelected,
    this.onSelectedChanged,
    this.onLongPress,
  });

  final List<MomentListItem> items;
  final ValueChanged<MomentListItem> onItemTap;

  /// 卡片悬停面板里的播放回调（跳播到该时刻）；不传则 hover 不显示播放键。
  final ValueChanged<MomentListItem>? onItemPlay;

  /// 卡片悬停面板里的「影片」回调；不传则不显示。
  final ValueChanged<MomentListItem>? onItemOpenMovie;

  /// 卡片悬停面板里的「加入合集」回调；不传则不显示。
  final ValueChanged<MomentListItem>? onItemAddToCollection;

  /// 卡片悬停面板里的「删除」回调；不传则不显示。
  final ValueChanged<MomentListItem>? onItemDelete;

  final bool selectionMode;
  final bool Function(MomentListItem item)? isSelected;
  final ValueChanged<MomentListItem>? onSelectedChanged;
  final ValueChanged<MomentListItem>? onLongPress;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardSliver<MomentListItem>(
      gridKey: const Key('moment-grid'),
      items: items,
      childAspectRatio: 16 / 10,
      itemBuilder: (context, item, _) => MomentCard(
        item: item,
        onTap: () => onItemTap(item),
        onPlay: onItemPlay == null ? null : () => onItemPlay!(item),
        onOpenMovie: onItemOpenMovie == null
            ? null
            : () => onItemOpenMovie!(item),
        onAddToCollection: onItemAddToCollection == null
            ? null
            : () => onItemAddToCollection!(item),
        onDelete: onItemDelete == null ? null : () => onItemDelete!(item),
        selectionMode: selectionMode,
        isSelected: isSelected?.call(item) ?? false,
        onSelectedChanged: onSelectedChanged == null
            ? null
            : (_) => onSelectedChanged!(item),
        onLongPress: onLongPress == null ? null : () => onLongPress!(item),
      ),
    );
  }
}
