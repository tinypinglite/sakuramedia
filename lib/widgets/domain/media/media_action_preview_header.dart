import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/domain/media/media_center_play_button.dart';
import 'package:sakuramedia/widgets/domain/media/media_duration_badge.dart';

/// 媒体动作弹层的封面预览头：16:9 封面 + 时长角标 + 可选播放键 + 标题/副标题。
class MediaActionPreviewHeader extends StatelessWidget {
  const MediaActionPreviewHeader({
    super.key,
    required this.coverUrl,
    required this.coverFit,
    required this.title,
    this.subtitle,
    this.durationSeconds,
    this.onPlay,
    this.titleKey,
    this.playButtonKey,
    this.coverKey,
    this.titleSize = AppTextSize.s16,
    this.titleMaxLines = 2,
    this.rightPadding = 0,
  });

  final String? coverUrl;
  final BoxFit coverFit;
  final String title;
  final String? subtitle;
  final int? durationSeconds;
  final VoidCallback? onPlay;
  final Key? titleKey;
  final Key? playButtonKey;
  final Key? coverKey;
  final AppTextSize titleSize;
  final int titleMaxLines;
  final double rightPadding;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final url = coverUrl?.trim();
    final duration = durationSeconds;
    final sub = subtitle?.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: context.appRadius.mdBorder,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  key: coverKey,
                  color: context.appColors.surfaceMuted,
                  child: url == null || url.isEmpty
                      ? null
                      : MaskedImage(url: url, fit: coverFit),
                ),
                if (duration != null && duration > 0)
                  Positioned(
                    right: spacing.xs,
                    bottom: spacing.xs,
                    child: MediaDurationBadge(seconds: duration),
                  ),
                if (onPlay != null)
                  MediaCenterPlayButton(
                    buttonKey: playButtonKey,
                    onTap: onPlay!,
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.md),
        Padding(
          padding: EdgeInsets.only(right: rightPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                key: titleKey,
                maxLines: titleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: titleSize,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              if (sub != null && sub.isNotEmpty) ...[
                SizedBox(height: spacing.xs),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
