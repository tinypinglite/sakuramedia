import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

Future<T?> showAppBottomDrawer<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Key? drawerKey,
  double heightFactor = 0.9,
  double? maxHeightFactor,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool ignoreTopSafeArea = false,
  bool enableDrag = true,
  bool showHandle = true,
}) {
  final shouldUseRouteSafeArea = useSafeArea && !ignoreTopSafeArea;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: shouldUseRouteSafeArea,
    showDragHandle: false,
    enableDrag: enableDrag,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.appRadius.sm),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) {
      Widget drawer = AppBottomDrawerSurface(
        key: drawerKey,
        heightFactor: heightFactor,
        maxHeightFactor: maxHeightFactor,
        showHandle: showHandle,
        child: builder(sheetContext),
      );

      if (useSafeArea && ignoreTopSafeArea) {
        drawer = SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: drawer,
        );
      }

      return drawer;
    },
  );
}

class AppBottomDrawerSurface extends StatelessWidget {
  const AppBottomDrawerSurface({
    super.key,
    required this.child,
    this.heightFactor = 0.9,
    this.maxHeightFactor,
    this.showHandle = true,
  });

  static const double _handleWidth = 28;
  static const double _handleHeight = 3;
  static const double _handleTopSpacing = 6;
  static const double _handleBottomSpacing = 6;

  final Widget child;
  final double heightFactor;
  final double? maxHeightFactor;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final colors = context.appColors;
    final resolvedContentPadding = EdgeInsets.all(context.appSpacing.lg);
    final handleContentTopInset =
        showHandle
            ? _handleTopSpacing + _handleHeight + _handleBottomSpacing
            : 0.0;

    final content = Material(
      color: colors.surfaceCard,
      child: Stack(
        children: [
          Padding(
            key: const Key('app-bottom-drawer-content'),
            padding: resolvedContentPadding,
            child: child,
          ),
          if (showHandle)
            Positioned(
              top: _handleTopSpacing,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  key: const Key('app-bottom-drawer-handle'),
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: context.appRadius.pillBorder,
                  ),
                  child: const SizedBox(
                    width: _handleWidth,
                    height: _handleHeight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (maxHeightFactor != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * maxHeightFactor!),
        child: content,
      );
    }

    return SizedBox(height: screenHeight * heightFactor, child: content);
  }
}
