import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_entrance.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';

/// 桌面弹窗统一入口。
///
/// 转场不使用祖先 [FadeTransition]：玻璃框架是合成器级的 backdrop pass，被
/// [Opacity] 包住就拿不到真实背景，淡入期间整块框架迟到、只能等淡入结束才出现。
/// 这里改用 [AppGlassEntrance] 把进度传下去——玻璃走 `visibility`，纯绘制表面
/// 走 opacity，入场和出场共用同一个进度，不会出现“内容先消失、只剩空玻璃”。
///
/// 扁平样式和高对比度没有 backdrop，仍然用整树淡入。
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
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
      themes: themes,
      barrierColor: resolvedBarrierColor,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(
        context,
      ).modalBarrierDismissLabel,
    ),
  );
}

class _AppDialogRoute<T> extends DialogRoute<T> {
  _AppDialogRoute({
    required super.context,
    required super.builder,
    required super.themes,
    required super.barrierColor,
    required super.barrierDismissible,
    required super.barrierLabel,
  }) : super(
         useSafeArea: true,
         traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
       );

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = animation.drive(CurveTween(curve: Curves.easeOut));
    // 只有 Impeller（premium glass shader）才能用 visibility 通道。扁平样式、
    // 高对比度和非 Impeller 后端没有可用的 backdrop pass：前者是纯绘制，后者由
    // 包内的轻量实现按 visibility 自己包一层 Opacity，并在到达 1.0 时把这层去掉
    // ——那会在入场结束的一帧重建整棵弹窗、丢掉内容状态。
    final fadeWithEntrance =
        AppSurfaceStyleScope.of(context) != AppSurfaceStyle.flat &&
        !(MediaQuery.maybeHighContrastOf(context) ?? false) &&
        ui.ImageFilter.isShaderFilterSupported;
    if (!fadeWithEntrance) {
      return FadeTransition(opacity: curved, child: child);
    }
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) =>
          AppGlassEntrance(progress: curved.value, child: child!),
    );
  }
}
