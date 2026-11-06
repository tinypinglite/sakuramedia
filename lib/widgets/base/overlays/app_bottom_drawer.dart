import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_glass_surface.dart';

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
  EdgeInsetsGeometry? contentPadding,
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
    barrierColor: context.appColors.modalBarrier,
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    clipBehavior: Clip.none,
    builder: (sheetContext) {
      final spacing = sheetContext.appSpacing;
      Widget drawer = Padding(
        padding: EdgeInsets.all(spacing.sm),
        child: AppBottomDrawerSurface(
          key: drawerKey,
          heightFactor: heightFactor,
          maxHeightFactor: maxHeightFactor,
          showHandle: showHandle,
          contentPadding: contentPadding,
          verticalMargin: spacing.sm,
          child: builder(sheetContext),
        ),
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
    this.contentPadding,
    this.verticalMargin = 0,
  });

  static const double _handleWidth = 36;
  static const double _handleHeight = 5;
  static const double _handleTopSpacing = 9;

  final Widget child;
  final double heightFactor;
  final double? maxHeightFactor;
  final bool showHandle;
  final EdgeInsetsGeometry? contentPadding;

  /// 外層浮动边距的上下部分，只参与高度预算，不在这里实际绘制。
  final double verticalMargin;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = (screenHeight - bottomInset - verticalMargin * 2)
        .clamp(0.0, screenHeight);
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final resolvedContentPadding =
        (contentPadding ?? EdgeInsets.all(spacing.lg)).resolve(
          Directionality.of(context),
        );
    final handleSpace = showHandle
        ? _handleTopSpacing + _handleHeight + spacing.sm
        : spacing.sm;
    final contentInsets = EdgeInsets.fromLTRB(
      resolvedContentPadding.left,
      resolvedContentPadding.top + handleSpace,
      resolvedContentPadding.right,
      resolvedContentPadding.bottom + spacing.sm,
    );

    final content = AppModalGlassSurface(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Padding(
            key: const Key('app-bottom-drawer-content'),
            padding: contentInsets,
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
                    color: colors.borderStrong.withValues(alpha: 0.90),
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
        constraints: BoxConstraints(
          maxHeight: target < availableHeight ? target : availableHeight,
        ),
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
