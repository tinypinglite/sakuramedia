import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 分组卡片：浅灰底上浮起的白色圆角卡片，承载一组语义相关的设置行/内容。
///
/// 国内主流设置页的母语：可选灰色小标题在卡片上方，卡片内多行用左侧内缩的细
/// 分隔线分隔，组与组之间留空隙。把若干 [AppSettingCell] 或任意内容放进 [children]。
class AppSettingsGroup extends StatelessWidget {
  const AppSettingsGroup({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.dividerIndent,
  });

  /// 卡片上方的灰色小标题（可选）。
  final String? header;

  /// 卡片下方的辅助说明（可选，灰色小字）。
  final String? footer;

  /// 卡片内的内容行；相邻两行之间自动插入左侧内缩的细分隔线。
  final List<Widget> children;

  /// 分隔线左侧内缩量；默认对齐到行内容左边距（[AppSpacing.lg]）。
  /// 行带左图标时可传更大的值，让分隔线缩到标题起点。
  final double? dividerIndent;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final indent = dividerIndent ?? spacing.lg;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(left: indent),
            child: Divider(height: 1, thickness: 1, color: colors.divider),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null && header!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: spacing.xs, bottom: spacing.sm),
            child: Text(
              header!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
          ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: context.appRadius.lgBorder,
            border: Border.all(color: colors.borderSubtle),
            boxShadow: context.appShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
        if (footer != null && footer!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: spacing.xs, top: spacing.sm),
            child: Text(
              footer!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
          ),
      ],
    );
  }
}

/// 设置行：`[左图标(可选)] 主标题 +(副标题灰字) ……右侧区(值/徽标/开关/小按钮/chevron)`。
///
/// 整行可点（[onTap] 非空时带 hover 反馈），右侧 [trailing] 承载值或操作。
/// 放进 [AppSettingsGroup] 即可获得卡片分组与行间分隔线。
class AppSettingCell extends StatelessWidget {
  const AppSettingCell({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleTone = AppTextTone.primary,
    this.titleWeight = AppTextWeight.regular,
  });

  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final AppTextTone titleTone;
  final AppTextWeight titleWeight;

  static const double _kIconBox = 32;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            AppSettingIconBox(icon: icon!, color: iconColor),
            SizedBox(width: spacing.md),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: titleWeight,
                    tone: titleTone,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: spacing.md),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: context.appColors.surfaceMuted,
        child: content,
      ),
    );
  }
}

/// 设置行/卡片左侧的圆角图标盒（浅灰底 + 图标），供设置类页面统一复用。
class AppSettingIconBox extends StatelessWidget {
  const AppSettingIconBox({super.key, required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: AppSettingCell._kIconBox,
      height: AppSettingCell._kIconBox,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Icon(
        icon,
        size: context.appComponentTokens.iconSizeSm,
        color: resolvedColor,
      ),
    );
  }
}

/// 设置行右侧的"跳转箭头"，用于"点进去还有内容"的行。
class AppSettingCellChevron extends StatelessWidget {
  const AppSettingCellChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right_rounded,
      size: context.appComponentTokens.iconSizeMd,
      color: context.appTextPalette.muted,
    );
  }
}
