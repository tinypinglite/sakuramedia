import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// [CollectionEpisodeQueueItem] 封面 fit 策略。
///
/// - [cover] 切片合集: 封面固定横屏, 无底色兜底。
/// - [containOnMuted] 视频合集: pornbox 视频不一定横屏, 缩略图按
///   contain 完整居中,两侧灰底不裁切。
enum CollectionQueueCoverStyle { cover, containOnMuted }

/// 合集连播「选集」浮层内的一项:88 宽 16:9 封面 + 标题 + 副信息 +
/// 当前集右侧「▲」高亮 icon。切片 / 视频两页共用。
class CollectionEpisodeQueueItem extends StatelessWidget {
  const CollectionEpisodeQueueItem({
    super.key,
    required this.itemKey,
    required this.coverUrl,
    required this.coverStyle,
    required this.title,
    required this.subtitle,
    required this.isCurrent,
    required this.onTap,
    this.trailing,
  });

  final Key itemKey;
  final String? coverUrl;
  final CollectionQueueCoverStyle coverStyle;
  final String title;
  final String subtitle;
  final bool isCurrent;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final hasCover = coverUrl != null && coverUrl!.isNotEmpty;
    Widget coverBox;
    switch (coverStyle) {
      case CollectionQueueCoverStyle.cover:
        coverBox = hasCover
            ? MaskedImage(url: coverUrl!, fit: BoxFit.cover)
            : ColoredBox(color: colors.surfaceMuted);
        break;
      case CollectionQueueCoverStyle.containOnMuted:
        coverBox = ColoredBox(
          color: colors.surfaceMuted,
          child: hasCover
              ? MaskedImage(url: coverUrl!, fit: BoxFit.contain)
              : null,
        );
        break;
    }
    return AppInteractiveSurface(
      key: itemKey,
      enabled: onTap != null,
      onTap: onTap,
      focusRingRadius: context.appRadius.smBorder,
      child: Material(
        color: isCurrent ? colors.surfaceMuted : Colors.transparent,
        borderRadius: context.appRadius.smBorder,
        child: Padding(
          padding: EdgeInsets.all(spacing.xs),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: context.appRadius.xsBorder,
                child: SizedBox(
                  width: 88,
                  child: AspectRatio(aspectRatio: 16 / 9, child: coverBox),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: isCurrent
                            ? AppTextWeight.semibold
                            : AppTextWeight.regular,
                        tone: isCurrent
                            ? AppTextTone.primary
                            : AppTextTone.secondary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Row(
                      children: [
                        if (isCurrent && trailing != null) ...[
                          Icon(
                            Icons.equalizer_rounded,
                            size: context.appComponentTokens.iconSizeSm,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(width: spacing.xs),
                        ],
                        Flexible(
                          child: Text(
                            subtitle,
                            style: resolveAppTextStyle(
                              context,
                              size: AppTextSize.s12,
                              weight: AppTextWeight.regular,
                              tone: AppTextTone.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (isCurrent && trailing == null)
                Padding(
                  padding: EdgeInsets.only(left: spacing.xs),
                  child: Icon(
                    Icons.equalizer_rounded,
                    size: context.appComponentTokens.iconSizeSm,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
