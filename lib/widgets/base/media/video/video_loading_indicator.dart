import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 播放器统一加载反馈：用于页面取流、首帧等待与播放中缓冲。
///
/// 深色半透明胶囊保证它在黑底和视频画面上都清晰可见，同时不使用第二套强调色。
class VideoLoadingIndicator extends StatelessWidget {
  const VideoLoadingIndicator({
    super.key,
    this.label = '正在加载…',
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    return Semantics(
      container: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.mediaOverlayStrong,
          borderRadius: context.appRadius.pillBorder,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: componentTokens.iconSizeMd,
                child: CircularProgressIndicator(
                  key: const Key('video-loading-spinner'),
                  strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
                  color: context.appTextPalette.onMedia,
                ),
              ),
              SizedBox(width: spacing.sm),
              Text(
                label,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.onMedia,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
