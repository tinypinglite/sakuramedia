import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 切片封面上的播放遮罩：半透明暗层 + 居中播放图标。
/// 供「全部切片」网格卡与合集详情网格卡复用，保持一致观感。
///
/// 时长徽标不再放在本文件——跨切片/视频/媒体通用，见
/// `widgets/domain/media/media_duration_badge.dart` 的 `MediaDurationBadge`。
class ClipPlayOverlay extends StatelessWidget {
  const ClipPlayOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.16)),
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.white.withValues(alpha: 0.92),
          size: context.appComponentTokens.iconSize2xl,
        ),
      ),
    );
  }
}
