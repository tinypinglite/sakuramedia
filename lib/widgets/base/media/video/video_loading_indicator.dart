import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 播放器统一加载反馈：用于页面取流、首帧等待与播放中缓冲。
///
/// 深色半透明胶囊保证它在黑底和视频画面上都清晰可见，同时不使用第二套强调色。
class VideoLoadingIndicator extends StatelessWidget {
  const VideoLoadingIndicator({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final text = label ?? l10n.baseVideoLoading;
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    return Semantics(
      container: true,
      label: text,
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
                child: CircularProgressIndicator.adaptive(
                  backgroundColor: switch (Theme.of(context).platform) {
                    TargetPlatform.iOS || TargetPlatform.macOS => context.appTextPalette.onMedia,
                    _ => null,
                  },
                  key: const Key('video-loading-spinner'),
                  strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
                  valueColor: AlwaysStoppedAnimation<Color?>(context.appTextPalette.onMedia),
                ),
              ),
              SizedBox(width: spacing.sm),
              Text(
                text,
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
