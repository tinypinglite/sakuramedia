import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

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
          // 行内的 InkWell / Material 原生控件会在 hover / 按下时铺矩形底色，
          // 不裁剪会从卡片圆角外漏出。
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: context.appRadius.lgBorder,
            border: Border.all(color: colors.borderSubtle),
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
    this.padding,
  });

  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final AppTextTone titleTone;
  final AppTextWeight titleWeight;

  /// 行内容内边距；默认按设置行标准内缩。嵌在已有内边距的卡片里时传更小的值，
  /// 让行内容与同卡片内的表单字段对齐。
  final EdgeInsetsGeometry? padding;

  static const double _kIconBox = 32;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    final content = Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.md),
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
          if (trailing != null) ...[SizedBox(width: spacing.md), trailing!],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return AppInteractiveSurface(onTap: onTap, child: content);
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

/// 设置行右侧的编辑 / 删除图标对。
class AppSettingInlineActions extends StatelessWidget {
  const AppSettingInlineActions({
    super.key,
    required this.editKey,
    required this.deleteKey,
    required this.onEdit,
    required this.onDelete,
    this.deleteIcon = Icons.delete_outline_rounded,
  });

  final Key editKey;
  final Key deleteKey;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final IconData deleteIcon;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final iconColor = context.appTextPalette.secondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconButton(
          key: editKey,
          icon: const Icon(Icons.edit_outlined),
          tooltip: AppLocalizations.of(context).commonEdit,
          size: AppIconButtonSize.inline,
          iconColor: iconColor,
          onPressed: onEdit,
        ),
        SizedBox(width: spacing.xs),
        AppIconButton(
          key: deleteKey,
          icon: Icon(deleteIcon),
          tooltip: AppLocalizations.of(context).commonDelete,
          size: AppIconButtonSize.inline,
          iconColor: iconColor,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// 设置分组末尾的「新建 / 添加」行。
class AppSettingCreateCell extends StatelessWidget {
  const AppSettingCreateCell({
    super.key,
    required this.title,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppSettingCell(
      icon: Icons.add_rounded,
      iconColor: Theme.of(context).colorScheme.primary,
      title: title,
      titleTone: AppTextTone.accent,
      titleWeight: AppTextWeight.medium,
      trailing: const AppSettingCellChevron(),
      onTap: enabled ? onTap : null,
    );
  }
}
