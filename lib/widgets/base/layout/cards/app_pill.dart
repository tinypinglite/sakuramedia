import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

/// 胶囊/徽章的语义色调。
///
/// - [neutral]：默认中性标签，灰底 + 次级文字；
/// - [muted]：禁用/停用等弱化状态；
/// - [primary]：品牌强调；
/// - [info] / [warning] / [error] / [success]：语义状态；
/// - [selected]：分段控件等场景的“被选中”表面，不是业务语义色。
enum AppPillTone {
  neutral,
  muted,
  primary,
  info,
  warning,
  error,
  success,
  selected,
}

/// 胶囊尺寸；文字/图标/内边距一起收口，调用方不要再传样式。
enum AppPillSize { compact, regular, prominent }

/// 胶囊内文字的强调级别。
enum AppPillEmphasis { regular, medium, semibold }

/// 已解析的胶囊配色。业务侧需要自己画 leading/spinner 时用它取前景色。
@immutable
class AppPillColors {
  const AppPillColors({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;
}

AppPillColors resolveAppPillColors(BuildContext context, AppPillTone tone) {
  final colors = context.appColors;
  final text = context.appTextPalette;
  return switch (tone) {
    AppPillTone.neutral => AppPillColors(
      background: colors.surfaceMuted,
      foreground: text.secondary,
      border: colors.borderSubtle,
    ),
    AppPillTone.muted => AppPillColors(
      background: colors.surfaceMuted,
      foreground: text.muted,
      border: colors.borderSubtle,
    ),
    AppPillTone.primary => AppPillColors(
      background: colors.selectionSurface,
      foreground: text.accent,
    ),
    AppPillTone.info => AppPillColors(
      background: colors.infoSurface,
      foreground: text.info,
    ),
    AppPillTone.warning => AppPillColors(
      background: colors.warningSurface,
      foreground: text.warning,
    ),
    AppPillTone.error => AppPillColors(
      background: colors.errorSurface,
      foreground: text.error,
    ),
    AppPillTone.success => AppPillColors(
      background: colors.successSurface,
      foreground: text.success,
    ),
    AppPillTone.selected => AppPillColors(
      background: colors.surfaceElevated,
      foreground: text.primary,
      border: colors.borderSubtle,
    ),
  };
}

/// 纯展示的胶囊/徽章。
///
/// 统一容器、圆角、尺寸、文字层级和色调；点击语义由 [AppPillButton] 或
/// 调用方自己的 [AppInteractiveSurface] 负责。业务侧不要再写
/// `Container + BoxDecoration + Border.all` 拼一份。
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.tone = AppPillTone.neutral,
    this.size = AppPillSize.regular,
    this.emphasis = AppPillEmphasis.regular,
    this.leading,
    this.trailing,
    this.maxLines = 1,
  }) : child = null,
       assert(label != null);

  /// 需要在一枚胶囊里组合多段文字/图标时用；容器、色调、尺寸仍由本组件决定。
  const AppPill.custom({
    super.key,
    required this.child,
    this.tone = AppPillTone.neutral,
    this.size = AppPillSize.regular,
    this.leading,
    this.trailing,
  }) : label = null,
       emphasis = AppPillEmphasis.regular,
       maxLines = 1,
       assert(child != null);

  final String? label;
  final Widget? child;
  final AppPillTone tone;
  final AppPillSize size;
  final AppPillEmphasis emphasis;
  final Widget? leading;
  final Widget? trailing;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = resolveAppPillColors(context, tone);
    final spec = _AppPillSizeSpec.resolve(context, size);
    final labelStyle = resolveAppTextStyle(
      context,
      size: spec.textSize,
      weight: switch (emphasis) {
        AppPillEmphasis.regular => AppTextWeight.regular,
        AppPillEmphasis.medium => AppTextWeight.medium,
        AppPillEmphasis.semibold => AppTextWeight.semibold,
      },
      tone: AppTextTone.primary,
    ).copyWith(color: colors.foreground);
    final content =
        child ??
        Text(
          label!,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spec.horizontalPadding,
        vertical: spec.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: context.appRadius.pillBorder,
        border: colors.border == null
            ? null
            : Border.all(color: colors.border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leading != null) ...[
            IconTheme(
              data: IconThemeData(
                size: spec.iconSize,
                color: colors.foreground,
              ),
              child: leading!,
            ),
            SizedBox(width: spec.gap),
          ],
          Flexible(child: content),
          if (trailing != null) ...[
            SizedBox(width: spec.gap),
            IconTheme(
              data: IconThemeData(
                size: spec.iconSize,
                color: colors.foreground,
              ),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}

/// 可点击胶囊：统一包一层 [AppInteractiveSurface]，并补上 button/selected 语义。
class AppPillButton extends StatelessWidget {
  const AppPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = AppPillTone.neutral,
    this.size = AppPillSize.regular,
    this.emphasis = AppPillEmphasis.regular,
    this.leading,
    this.trailing,
    this.semanticLabel,
    this.isSelected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final AppPillTone tone;
  final AppPillSize size;
  final AppPillEmphasis emphasis;
  final Widget? leading;
  final Widget? trailing;
  final String? semanticLabel;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      child: AppInteractiveSurface(
        onTap: onTap,
        semanticLabel: semanticLabel ?? label,
        child: AppPill(
          label: label,
          tone: tone,
          size: size,
          emphasis: emphasis,
          leading: leading,
          trailing: trailing,
        ),
      ),
    );
  }
}

class _AppPillSizeSpec {
  const _AppPillSizeSpec({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.textSize,
    required this.iconSize,
    required this.gap,
  });

  final double horizontalPadding;
  final double verticalPadding;
  final AppTextSize textSize;
  final double iconSize;
  final double gap;

  static _AppPillSizeSpec resolve(BuildContext context, AppPillSize size) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    return switch (size) {
      AppPillSize.compact => _AppPillSizeSpec(
        horizontalPadding: spacing.sm,
        verticalPadding: spacing.xs / 2,
        textSize: AppTextSize.s10,
        iconSize: tokens.iconSize3xs,
        gap: spacing.xs,
      ),
      AppPillSize.regular => _AppPillSizeSpec(
        horizontalPadding: spacing.sm,
        verticalPadding: spacing.xs,
        textSize: AppTextSize.s10,
        iconSize: tokens.iconSize2xs,
        gap: spacing.xs,
      ),
      AppPillSize.prominent => _AppPillSizeSpec(
        horizontalPadding: spacing.sm,
        verticalPadding: spacing.xs,
        textSize: AppTextSize.s12,
        iconSize: tokens.iconSize2xs,
        gap: spacing.xs,
      ),
    };
  }
}
