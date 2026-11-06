import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 决定 [showAppAdaptiveModal] 用哪种壳显示。
enum AppAdaptiveModalVariant {
  /// 读 `Provider<AppPlatform?>`：`mobile` → 底部抽屉，其余（`desktop` /
  /// null）→ 桌面对话框。参考 `AppTabBar._resolveVariant`。
  auto,

  /// 显式强制走桌面对话框（`AppDesktopDialog`）。
  dialog,

  /// 显式强制走底部抽屉（`showAppBottomDrawer`）。
  drawer,
}

/// 让弹层内容感知自己落在哪种壳里的信箱。
///
/// 少数弹层的 body 布局依赖壳体（抽屉里撑满、弹窗里按内容收缩），例如选择器
/// 的列表。没有壳信息时按 `false`（弹窗）处理，与直接调用 [showAppDialog]
/// 一致。
class AppAdaptiveModalShellScope extends InheritedWidget {
  const AppAdaptiveModalShellScope({
    super.key,
    required this.isDrawer,
    required super.child,
  });

  final bool isDrawer;

  static bool maybeIsDrawer(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AppAdaptiveModalShellScope>()
            ?.isDrawer ??
        false;
  }

  @override
  bool updateShouldNotify(AppAdaptiveModalShellScope oldWidget) {
    return isDrawer != oldWidget.isDrawer;
  }
}

/// 平台自适应的通用弹窗壳。
///
/// - `mobile` → [showAppBottomDrawer]（`mobileHeightFactor` / `mobileMaxHeightFactor`）；
/// - 其余 → [showAppDialog] + [AppDesktopDialog]（`desktopWidth` /
///   `desktopHeight`）。
///
/// [builder] 在两端共用，并被 [AppAdaptiveModalShellScope] 包裹，body 可用
/// `AppAdaptiveModalShellScope.maybeIsDrawer(context)` 感知当前壳体；`modalKey`
/// 透传为 drawer 分支的 `drawerKey`、dialog 分支的 `dialogKey`，需要两端各用
/// 不同测试锚点时再传 [dialogKey] / [drawerKey]（优先级高于 `modalKey`）。
/// 桌面端默认使用 [desktopWidth] / [desktopHeight]；需要保留原有最大尺寸时
/// 传 [desktopConstraints]（与 width/height 互斥），[desktopInsetPadding]
/// / [desktopContentKey] / [desktopBackgroundColor] / [desktopOnClose] 则透传给
/// [AppDesktopDialog]。[drawerIgnoreTopSafeArea] 透传给 [showAppBottomDrawer]。
///
/// 收敛此前多处手写「`AppPlatform == mobile ? drawer : dialog`」dispatch
/// （配置页的 Provider 表单 / directory_picker_dialog）。
/// [showAppConfirmDialog] 走的是同类模式的专用版；一般表单/流程弹窗用这个。
Future<T?> showAppAdaptiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Key? modalKey,
  Key? dialogKey,
  Key? drawerKey,
  double? desktopWidth,
  double? desktopHeight,
  BoxConstraints? desktopConstraints,
  EdgeInsets? desktopInsetPadding,
  Key? desktopContentKey,
  Color? desktopBackgroundColor,
  VoidCallback? desktopOnClose,
  double mobileHeightFactor = 0.9,
  double? mobileMaxHeightFactor,
  bool drawerIgnoreTopSafeArea = false,
  bool barrierDismissible = true,
  bool enableDrag = true,
  bool showDrawerHandle = true,
  bool showDesktopCloseButton = true,
  AppAdaptiveModalVariant variant = AppAdaptiveModalVariant.auto,
}) {
  assert(
    desktopConstraints == null ||
        (desktopWidth == null && desktopHeight == null),
    'Use either desktopConstraints or desktopWidth/desktopHeight sizing.',
  );
  final resolved = _resolveVariant(context, variant);
  if (resolved == AppAdaptiveModalVariant.drawer) {
    return showAppBottomDrawer<T>(
      context: context,
      drawerKey: drawerKey ?? modalKey,
      heightFactor: mobileHeightFactor,
      maxHeightFactor: mobileMaxHeightFactor,
      ignoreTopSafeArea: drawerIgnoreTopSafeArea,
      enableDrag: enableDrag,
      isDismissible: barrierDismissible,
      showHandle: showDrawerHandle,
      builder: (drawerContext) => AppAdaptiveModalShellScope(
        isDrawer: true,
        child: builder(drawerContext),
      ),
    );
  }
  return showAppDialog<T>(
    context: context,
    barrierColor: context.appColors.modalBarrier,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => AppDesktopDialog(
      dialogKey: dialogKey ?? modalKey,
      width: desktopConstraints == null
          ? desktopWidth ?? dialogContext.appLayoutTokens.dialogWidthMd
          : null,
      height: desktopConstraints == null ? desktopHeight : null,
      constraints: desktopConstraints,
      insetPadding: desktopInsetPadding,
      contentKey: desktopContentKey,
      backgroundColor: desktopBackgroundColor,
      onClose: desktopOnClose,
      showCloseButton: showDesktopCloseButton,
      child: AppAdaptiveModalShellScope(
        isDrawer: false,
        child: builder(dialogContext),
      ),
    ),
  );
}

AppAdaptiveModalVariant _resolveVariant(
  BuildContext context,
  AppAdaptiveModalVariant variant,
) {
  if (variant != AppAdaptiveModalVariant.auto) {
    return variant;
  }
  final platform = AppPlatformScope.maybeOf(context);
  return platform == AppPlatform.mobile
      ? AppAdaptiveModalVariant.drawer
      : AppAdaptiveModalVariant.dialog;
}
