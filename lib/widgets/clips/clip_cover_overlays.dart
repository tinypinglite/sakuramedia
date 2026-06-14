import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/theme.dart';

/// 切片封面上的播放遮罩：半透明暗层 + 居中播放图标。
/// 供「全部切片」网格卡与合集详情网格卡复用，保持一致观感。
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

/// 切片封面右下角时长徽标。
class ClipDurationBadge extends StatelessWidget {
  const ClipDurationBadge({super.key, required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: context.appRadius.xsBorder,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.appSpacing.xs,
          vertical: context.appSpacing.xs,
        ),
        child: Text(
          formatMediaTimecode(seconds),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.primary,
          ).copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
