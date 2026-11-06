import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_glass_surface.dart';

class AppDesktopDialog extends StatelessWidget {
  const AppDesktopDialog({
    super.key,
    this.dialogKey,
    this.contentKey,
    this.width,
    this.height,
    this.constraints,
    this.insetPadding,
    this.backgroundColor,
    this.shape,
    this.clipBehavior = Clip.antiAlias,
    this.showCloseButton = true,
    this.closeButtonKey,
    this.closeButtonTooltip,
    this.closeButtonInset,
    this.closeButtonBackgroundColor,
    this.closeButtonIconColor,
    this.onClose,
    this.glassStrength = kAppModalGlassStrength,
    required this.child,
  }) : assert(
         constraints == null || (width == null && height == null),
         'Use either constraints or width/height sizing.',
       );

  final Key? dialogKey;
  final Key? contentKey;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsets? insetPadding;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final Clip clipBehavior;
  final bool showCloseButton;
  final Key? closeButtonKey;
  final String? closeButtonTooltip;
  final EdgeInsets? closeButtonInset;
  final Color? closeButtonBackgroundColor;
  final Color? closeButtonIconColor;
  final VoidCallback? onClose;
  final AppModalGlassStrength glassStrength;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final spacing = context.appSpacing;
    final useGlass = backgroundColor == null && shape == null;
    final closeInset = closeButtonInset ?? EdgeInsets.all(spacing.sm);
    final resolvedContentPadding = EdgeInsets.all(spacing.xl);

    Widget content = Padding(padding: resolvedContentPadding, child: child);
    if (constraints != null) {
      content = ConstrainedBox(constraints: constraints!, child: content);
    } else if (width != null || height != null) {
      content = SizedBox(width: width, height: height, child: content);
    }

    final dialogContent = Stack(
      children: [
        KeyedSubtree(key: contentKey, child: content),
        if (showCloseButton)
          Positioned(
            top: closeInset.top,
            right: closeInset.right,
            child: AppIconButton(
              key: closeButtonKey,
              tooltip: closeButtonTooltip ?? l10n.baseClose,
              onPressed: onClose ?? () => Navigator.of(context).pop(),
              backgroundColor: closeButtonBackgroundColor,
              iconColor: closeButtonIconColor,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
      ],
    );
    return Dialog(
      key: dialogKey,
      insetPadding: insetPadding,
      backgroundColor: useGlass
          ? Colors.transparent
          : backgroundColor ?? context.appColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
      shadowColor: useGlass ? Colors.transparent : null,
      elevation: useGlass ? 0 : null,
      shape:
          shape ??
          RoundedRectangleBorder(
            borderRadius: useGlass
                ? context.appRadius.xlBorder
                : context.appRadius.lgBorder,
          ),
      clipBehavior: useGlass ? Clip.none : clipBehavior,
      child: useGlass
          ? AppModalGlassSurface(strength: glassStrength, child: dialogContent)
          : dialogContent,
    );
  }
}
