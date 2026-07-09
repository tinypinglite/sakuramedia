import 'package:flutter/material.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_grid_card.dart';

/// 移动端切片网格卡:整卡即封面 + 底部一条信息栏(左番号、右时长)。
///
/// 整卡点击触发 [onTap](通常弹出操作抽屉),无右键 / 长按菜单。
/// 选择模式下整卡点击切换选中并叠加勾选。
///
/// 内部委托 [ClipGridCard],只把差异点(materialColor / 底色到 decoration /
/// 番号 fallback / tap Key 前缀 / 无菜单回调)作参数传入。桌面 grid 版仍
/// 直接用 [ClipGridCard]。
class ClipCoverCard extends StatelessWidget {
  const ClipCoverCard({
    super.key,
    required this.clip,
    required this.onTap,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  final MediaClipDto clip;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool isSelected;
  final ValueChanged<bool>? onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    return ClipGridCard(
      clip: clip,
      onTap: onTap,
      tapKey: Key('clip-cover-card-${clip.clipId}'),
      numberOverride: clip.displayNumber,
      materialColor: Colors.transparent,
      backgroundOnDecoration: true,
      selectionMode: selectionMode,
      isSelected: isSelected,
      onSelectedChanged: onSelectedChanged,
    );
  }
}
