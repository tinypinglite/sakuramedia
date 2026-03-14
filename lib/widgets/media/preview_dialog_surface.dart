import 'package:flutter/material.dart';

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
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (constraints != null) {
      content = ConstrainedBox(constraints: constraints!, child: child);
    } else if (width != null || height != null) {
      content = SizedBox(width: width, height: height, child: child);
    }

    return Dialog(
      key: dialogKey,
      insetPadding: insetPadding,
      backgroundColor: backgroundColor,
      clipBehavior: Clip.antiAlias,
      child: KeyedSubtree(key: contentKey, child: content),
    );
  }
}
