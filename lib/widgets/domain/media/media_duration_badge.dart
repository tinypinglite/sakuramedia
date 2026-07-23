import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/theme.dart';

/// 媒体封面右下角的时长胶囊：半透明黑底 + 白色 mm:ss 文本。
///
/// 跨切片 / 视频 / 合集等所有「有时长的媒体缩略图」共用，语义等价于
/// 「这个封面代表的媒体时长」。跟 `ClipPlayOverlay`（播放遮罩）配套但独立
/// 使用——不是所有带时长徽标的地方都有播放遮罩。
class MediaDurationBadge extends StatelessWidget {
  const MediaDurationBadge({super.key, required this.seconds});

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
