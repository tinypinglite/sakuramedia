import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// Hero 元信息段：可选的图标 + 文案，与影片详情页的元信息保持同一套内容。
class TvHeroMetaItem {
  const TvHeroMetaItem({required this.text, this.icon, this.iconColor});

  final String text;
  final IconData? icon;
  final Color? iconColor;
}

/// 电视首页 / 详情页共用的宽幅 Hero：背景图 + 左侧压暗 + 标题信息 + 操作区。
///
/// [eyebrow] 放番号；[seriesName] 是系列名；[metaItems] 依次渲染热度、上映
/// 日期、时长、厂商、导演等元信息，不再拼单行字符串。
class TvHeroBanner extends StatelessWidget {
  const TvHeroBanner({
    super.key,
    required this.imageUrl,
    required this.title,
    this.eyebrow,
    this.seriesName,
    this.metaItems = const <TvHeroMetaItem>[],
    this.actions = const <Widget>[],
  });

  final String? imageUrl;
  final String title;
  final String? eyebrow;
  final String? seriesName;
  final List<TvHeroMetaItem> metaItems;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final eyebrow = this.eyebrow?.trim() ?? '';
    final seriesName = this.seriesName?.trim() ?? '';

    return SizedBox(
      height: AppTvTokens.heroHeight,
      child: ClipRRect(
        borderRadius: context.appRadius.xlBorder,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MaskedImage(
              url: imageUrl ?? '',
              fit: BoxFit.cover,
              memCacheWidth: 1920,
              memCacheHeight: 1080,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    context.appColors.surfacePage.withValues(alpha: 0.96),
                    context.appColors.surfacePage.withValues(alpha: 0.72),
                    context.appColors.surfacePage.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(spacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (eyebrow.isNotEmpty) ...[
                    Text(
                      eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s18,
                        weight: AppTextWeight.medium,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                  ],
                  if (seriesName.isNotEmpty) ...[
                    Text(
                      seriesName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s20,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                    SizedBox(height: spacing.sm),
                  ],
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s48,
                      weight: AppTextWeight.semibold,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  if (metaItems.isNotEmpty) ...[
                    SizedBox(height: spacing.md),
                    Wrap(
                      spacing: spacing.lg,
                      runSpacing: spacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final item in metaItems)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.icon case final icon?) ...[
                                Icon(
                                  icon,
                                  size: tokens.iconSizeSm,
                                  color:
                                      item.iconColor ??
                                      context.appTextPalette.secondary,
                                ),
                                SizedBox(width: spacing.xs),
                              ],
                              Text(
                                item.text,
                                style: resolveAppTextStyle(
                                  context,
                                  size: AppTextSize.s18,
                                  tone: AppTextTone.secondary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                  if (actions.isNotEmpty) ...[
                    SizedBox(height: spacing.xl),
                    Row(spacing: spacing.md, children: actions),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
