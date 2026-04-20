import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';

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
    this.closeButtonTooltip = '关闭',
    this.closeButtonInset,
    this.closeButtonBackgroundColor,
    this.closeButtonIconColor,
    this.onClose,
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
  final String closeButtonTooltip;
  final EdgeInsets? closeButtonInset;
  final Color? closeButtonBackgroundColor;
  final Color? closeButtonIconColor;
  final VoidCallback? onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final closeInset = closeButtonInset ?? EdgeInsets.all(spacing.sm);
    final resolvedContentPadding = EdgeInsets.all(spacing.xl);

    Widget content = Padding(padding: resolvedContentPadding, child: child);
    if (constraints != null) {
      content = ConstrainedBox(constraints: constraints!, child: content);
    } else if (width != null || height != null) {
      content = SizedBox(width: width, height: height, child: content);
    }

    return Dialog(
      key: dialogKey,
      insetPadding: insetPadding,
      backgroundColor: backgroundColor ?? context.appColors.surfaceCard,
      shape:
          shape ??
          RoundedRectangleBorder(borderRadius: context.appRadius.lgBorder),
      clipBehavior: clipBehavior,
      child: Stack(
        children: [
          KeyedSubtree(key: contentKey, child: content),
          if (showCloseButton)
            Positioned(
              top: closeInset.top,
              right: closeInset.right,
              child: AppIconButton(
                key: closeButtonKey,
                tooltip: closeButtonTooltip,
                onPressed: onClose ?? () => Navigator.of(context).pop(),
                backgroundColor: closeButtonBackgroundColor,
                iconColor: closeButtonIconColor,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
        ],
      ),
    );
  }
}
