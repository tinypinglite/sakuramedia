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
  bool isDismissible = true,
  bool showHandle = true,
}) {
  final shouldUseRouteSafeArea = useSafeArea && !ignoreTopSafeArea;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: true,
    useSafeArea: shouldUseRouteSafeArea,
    showDragHandle: false,
    enableDrag: enableDrag,
    isDismissible: isDismissible,
    backgroundColor: context.appColors.surfaceCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.appRadius.lg),
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

  final Widget child;
  final double heightFactor;
  final double? maxHeightFactor;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = (screenHeight - bottomInset).clamp(0.0, screenHeight);
    final colors = context.appColors;
    final resolvedContentPadding = EdgeInsets.all(context.appSpacing.lg);

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

    final Widget sized;
    if (maxHeightFactor != null) {
      final target = screenHeight * maxHeightFactor!;
      sized = ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: target < availableHeight ? target : availableHeight),
        child: content,
      );
    } else {
      final target = screenHeight * heightFactor;
      sized = SizedBox(
        height: target < availableHeight ? target : availableHeight,
        child: content,
      );
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: sized,
    );
  }
}
