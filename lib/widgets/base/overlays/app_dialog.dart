import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 桌面弹窗统一入口。
///
/// 与 [showDialog] 的差别只在转场：不用祖先 [FadeTransition] 淡整棵弹窗，
/// 而是让 liquid glass 通过自身的 visibility/materialize 通道入退场。
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final localizations = MaterialLocalizations.of(context);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final dialogTheme = DialogTheme.of(context);
  final resolvedBarrierColor =
      barrierColor ??
      dialogTheme.barrierColor ??
      context.appColors.modalBarrier;

  return showRawDialog<T>(
    context: context,
    builder: builder,
    useRootNavigator: useRootNavigator,
    routeBuilder: (routeContext, _) => _AppDialogRoute<T>(
      context: routeContext,
      builder: builder,
      barrierColor: resolvedBarrierColor,
      barrierDismissible: barrierDismissible,
      barrierLabel: localizations.modalBarrierDismissLabel,
      useSafeArea: true,
      themes: themes,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    ),
  );
}

class _AppDialogRoute<T> extends DialogRoute<T> {
  _AppDialogRoute({
    required super.context,
    required super.builder,
    required super.barrierColor,
    super.barrierDismissible,
    super.barrierLabel,
    super.useSafeArea,
    super.themes,
    super.traversalEdgeBehavior,
  });

  @override
  Duration get transitionDuration => GlassDefaults.materializeDuration;

  @override
  Duration get reverseTransitionDuration => GlassDefaults.dematerializeDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return GlassMaterializeTransition(
      animation: animation,
      scaleFrom: 1.04,
      contentSigma: 4,
      child: child,
    );
  }
}
