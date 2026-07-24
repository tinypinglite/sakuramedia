import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/theme/app_layout_tokens.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 决定 [showAppAdaptiveModal] 用哪种壳显示。
enum AppAdaptiveModalVariant {
  /// 读 `Provider<AppPlatform?>`：`mobile` → 底部抽屉，其余（`desktop` /
  /// `web` / null）→ 桌面对话框。参考 `AppTabBar._resolveVariant`。
  auto,

  /// 显式强制走桌面对话框（`AppDesktopDialog`）。
  dialog,

  /// 显式强制走底部抽屉（`showAppBottomDrawer`）。
  drawer,
}

/// 平台自适应的通用弹窗壳。
///
/// - `mobile` → [showAppBottomDrawer]（`mobileHeightFactor` / `mobileMaxHeightFactor`）；
/// - 其余 → [showDialog] + [AppDesktopDialog]（`desktopWidth`）。
///
/// [builder] 在两端共用；`modalKey` 透传为 drawer 分支的 `drawerKey`、dialog
/// 分支的 `dialogKey`，供测试锚点。
///
/// 收敛此前三处手写「`AppPlatform == mobile ? drawer : dialog`」dispatch
/// （cloud115_backend_picker / cloud115_library_login_flow / directory_picker_dialog）。
/// [showAppConfirmDialog] 走的是同类模式的专用版；一般表单/流程弹窗用这个。
Future<T?> showAppAdaptiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Key? modalKey,
  double? desktopWidth,
  double mobileHeightFactor = 0.9,
  double? mobileMaxHeightFactor,
  bool barrierDismissible = true,
  bool enableDrag = true,
  bool showDesktopCloseButton = true,
  AppAdaptiveModalVariant variant = AppAdaptiveModalVariant.auto,
}) {
  final resolved = _resolveVariant(context, variant);
  if (resolved == AppAdaptiveModalVariant.drawer) {
    return showAppBottomDrawer<T>(
      context: context,
      drawerKey: modalKey,
      heightFactor: mobileHeightFactor,
      maxHeightFactor: mobileMaxHeightFactor,
      enableDrag: enableDrag,
      isDismissible: barrierDismissible,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder:
        (dialogContext) => AppDesktopDialog(
          dialogKey: modalKey,
          width: desktopWidth ?? dialogContext.appLayoutTokens.dialogWidthMd,
          showCloseButton: showDesktopCloseButton,
          child: builder(dialogContext),
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
  final platform = Provider.of<AppPlatform?>(context, listen: false);
  return platform == AppPlatform.mobile
      ? AppAdaptiveModalVariant.drawer
      : AppAdaptiveModalVariant.dialog;
}
