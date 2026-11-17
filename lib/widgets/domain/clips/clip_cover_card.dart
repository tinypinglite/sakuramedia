import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_grid_card.dart';

/// 移动端切片网格卡:整卡即封面,点击弹出操作抽屉,长按进入多选。
///
/// 与桌面 grid 版 [ClipGridCard] 共用实现:无右键菜单、无悬停披露(触屏没有
/// hover);tap Key 前缀为 `clip-cover-card-`。
class ClipCoverCard extends StatelessWidget {
  const ClipCoverCard({
    super.key,
    required this.clip,
    required this.onTap,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    this.onLongPress,
  });

  final MediaClipDto clip;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool isSelected;
  final ValueChanged<bool>? onSelectedChanged;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return ClipGridCard(
      clip: clip,
      onTap: onTap,
      tapKey: Key('clip-cover-card-${clip.clipId}'),
      selectionMode: selectionMode,
      isSelected: isSelected,
      onSelectedChanged: onSelectedChanged,
      onLongPress: onLongPress,
    );
  }
}
