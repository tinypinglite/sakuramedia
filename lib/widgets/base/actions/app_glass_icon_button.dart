import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_backend.dart';

/// 导航栏和浮层里的圆形液态玻璃图标按钮。
///
/// 只用于导航栏、吸顶控制条和模态浮层等**功能层**；内容卡和正文不要套这层。
/// 高对比度模式回退为带描边的实色圆钮，命中区保持 44×44。
class AppGlassIconButton extends StatelessWidget {
  const AppGlassIconButton({
    super.key,
    required this.icon,
    this.iconWidget,
    required this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.foregroundColor,
    this.size = 44,
    this.iconSize = 20,
    this.prominent = false,
  });

  final IconData icon;

  /// 覆盖默认图标，用于加载指示器等非 [IconData] 内容。
  final Widget? iconWidget;
  final VoidCallback? onPressed;
  final String? tooltip;
  final String? semanticLabel;
  final Color? foregroundColor;
  final double size;
  final double iconSize;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final resolvedForeground =
        foregroundColor ?? context.appTextPalette.primary;
    final label = semanticLabel ?? tooltip ?? '';
    final resolvedIcon = iconWidget ?? Icon(icon);

    final button = highContrast
        ? AppIconButton(
            icon: resolvedIcon,
            onPressed: onPressed,
            tooltip: tooltip,
            semanticLabel: label,
            size: AppIconButtonSize.regular,
            iconColor: resolvedForeground,
            backgroundColor: context.appColors.surfaceElevated,
            borderColor: context.appColors.borderStrong,
            borderRadius: context.appRadius.pillBorder,
          )
        : Semantics(
            button: true,
            enabled: onPressed != null,
            label: label,
            child: AppGlassIconButtonBackend(
              icon: resolvedIcon,
              onTap: onPressed ?? () {},
              label: label,
              enabled: onPressed != null,
              width: size,
              height: size,
              iconSize: iconSize,
              iconColor: resolvedForeground,
              prominent: prominent,
              glowColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
          );

    if (tooltip == null || tooltip!.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}
