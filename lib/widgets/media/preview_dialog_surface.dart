import 'package:flutter/material.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';

class PreviewDialogSurface extends StatelessWidget {
  const PreviewDialogSurface({
    super.key,
    this.dialogKey,
    this.contentKey,
    this.width,
    this.height,
    this.constraints,
    this.insetPadding,
    this.backgroundColor,
    this.showCloseButton = true,
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
  final bool showCloseButton;
  final VoidCallback? onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppDesktopDialog(
      dialogKey: dialogKey,
      contentKey: contentKey,
      width: width,
      height: height,
      constraints: constraints,
      insetPadding: insetPadding,
      backgroundColor: backgroundColor,
      showCloseButton: showCloseButton,
      onClose: onClose,
      child: child,
    );
  }
}
