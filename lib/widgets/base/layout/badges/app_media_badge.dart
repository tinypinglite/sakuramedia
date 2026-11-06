import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

enum AppMediaBadgeSize { compact, prominent }

/// 视频/封面上的烟熏角标：4K/8K、热度、排名共用同一份静态材质。
///
/// 只绘制深色渐变，不读取背景、不做模糊、不描边；文字/图标仍由这里控制，
/// 保证小尺寸下的可读性。需要固定尺寸时传 [width] / [height]。
class AppMediaBadge extends StatelessWidget {
  const AppMediaBadge({
    super.key,
    required this.label,
    this.labelKey,
    this.leading,
    this.width,
    this.height,
    this.padding,
    this.size = AppMediaBadgeSize.compact,
  });

  final String label;
  final Key? labelKey;
  final Widget? leading;
  final double? width;
  final double? height;

  /// 固定尺寸角标可传 `EdgeInsets.zero`，避免默认内边距把文字挤没。
  final EdgeInsetsGeometry? padding;
  final AppMediaBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final compact = size == AppMediaBadgeSize.compact;
    final iconSize = compact ? tokens.iconSize3xs : tokens.iconSize2xs;
    final textStyle = compact
        ? resolveAppTextStyle(
            context,
            size: AppTextSize.s10,
            weight: AppTextWeight.medium,
            tone: AppTextTone.onMedia,
            height: 13 / 10,
            letterSpacing: 0.12,
          )
        : resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.onMedia,
          ).copyWith(
            height: 1,
            leadingDistribution: TextLeadingDistribution.even,
          );

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: context.appRadius.pillBorder,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            context.appColors.mediaOverlayStrong.withValues(alpha: 0.80),
            context.appColors.mediaOverlayStrong.withValues(alpha: 0.68),
          ],
        ),
      ),
      child: Padding(
        padding:
            padding ??
            EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(
                    size: iconSize,
                    color: context.appTextPalette.onMedia,
                  ),
                  child: leading!,
                ),
                SizedBox(width: spacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  key: labelKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (width != null || height != null) {
      surface = SizedBox(width: width, height: height, child: surface);
    }
    return surface;
  }
}
