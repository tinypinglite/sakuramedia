import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 决定 [showAppConfirmDialog] 用哪种壳显示。
enum AppConfirmVariant {
  /// 读 `Provider<AppPlatform?>`：`mobile` → 底部抽屉，其余（`desktop` /
  /// `web` / null）→ 桌面对话框。参考 `AppTabBar._resolveVariant`。
  auto,

  /// 显式强制走桌面对话框（`AppDesktopDialog`）。
  dialog,

  /// 显式强制走底部抽屉（`showAppBottomDrawer`）。
  drawer,
}

/// 统一的二次确认弹窗：标题 + 正文 + 「取消 / 确认」两个按钮。
///
/// 取代此前各页面手写的同构 `AlertDialog` / `AppDesktopDialog` / 手撸删除抽屉。
/// 确认返回 `true`，取消 / 点遮罩 / 下滑关闭返回 `false`（恒非空，调用方可直接
/// `if (!confirmed) return;`）。
///
/// - [danger] 为 `true` 时确认按钮用危险红色（删除类不可恢复操作）。
/// - [dialogKey] / [confirmKey] / [cancelKey] 用于沿用各处既有的测试 key；
///   drawer 分支下 [dialogKey] 透传为 `drawerKey`。
/// - [extraContent] 在正文与按钮之间插入自定义内容（如带 key 的路径文本），
///   `null` 时不渲染。
/// - [variant] 决定壳体；默认 [AppConfirmVariant.auto]。
/// - [onConfirm] 传了 → 点确认后内部把确认按钮置 `isLoading`、禁用取消，
///   `await onConfirm()` 成功后 pop(true)；抛异常时 toast 兜底 + 恢复按钮状态、
///   **不 pop**。不传则保持旧行为：点确认立即 pop(true) 由 caller 自行调 API。
/// - [failureFallback] 是 [onConfirm] 异常时 toast 的兜底文案（默认 `'操作失败'`），
///   通过 `apiErrorMessage(error, fallback: failureFallback)` 解析后展示。
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  bool danger = false,
  Key? dialogKey,
  Key? confirmKey,
  Key? cancelKey,
  Widget? extraContent,
  AppConfirmVariant variant = AppConfirmVariant.auto,
  Future<void> Function()? onConfirm,
  String failureFallback = '操作失败',
}) async {
  final resolved = _resolveVariant(context, variant);
  Widget buildBody(BuildContext _) => _ConfirmBody(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        danger: danger,
        confirmKey: confirmKey,
        cancelKey: cancelKey,
        extraContent: extraContent,
        onConfirm: onConfirm,
        failureFallback: failureFallback,
      );

  if (resolved == AppConfirmVariant.drawer) {
    final confirmed = await showAppBottomDrawer<bool>(
      context: context,
      drawerKey: dialogKey,
      maxHeightFactor: 0.42,
      builder: buildBody,
    );
    return confirmed ?? false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AppDesktopDialog(
        dialogKey: dialogKey,
        width: dialogContext.appLayoutTokens.dialogWidthSm,
        child: buildBody(dialogContext),
      );
    },
  );
  return confirmed ?? false;
}

AppConfirmVariant _resolveVariant(
  BuildContext context,
  AppConfirmVariant variant,
) {
  if (variant != AppConfirmVariant.auto) {
    return variant;
  }
  final platform = Provider.of<AppPlatform?>(context, listen: false);
  return platform == AppPlatform.mobile
      ? AppConfirmVariant.drawer
      : AppConfirmVariant.dialog;
}

/// dialog 与 drawer 两个壳共享的正文 + 双按钮布局，同时承载 `onConfirm` 的 loading 状态。
class _ConfirmBody extends StatefulWidget {
  const _ConfirmBody({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.danger,
    required this.confirmKey,
    required this.cancelKey,
    required this.extraContent,
    required this.onConfirm,
    required this.failureFallback,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
  final Key? confirmKey;
  final Key? cancelKey;
  final Widget? extraContent;
  final Future<void> Function()? onConfirm;
  final String failureFallback;

  @override
  State<_ConfirmBody> createState() => _ConfirmBodyState();
}

class _ConfirmBodyState extends State<_ConfirmBody> {
  bool _isConfirming = false;

  Future<void> _handleConfirm() async {
    if (_isConfirming) {
      return;
    }
    final onConfirm = widget.onConfirm;
    if (onConfirm == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _isConfirming = true);
    try {
      await onConfirm();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isConfirming = false);
      showToast(apiErrorMessage(error, fallback: widget.failureFallback));
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    // onConfirm 进行中禁止下拉/遮罩/系统返回键关闭弹窗，防止 API 副作用
    // 与 modal dismiss 竞态导致本地状态不同步。取消按钮同时被禁用。
    return PopScope<bool>(
      canPop: !_isConfirming,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.lg),
          Text(
            widget.message,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          if (widget.extraContent != null) ...[
            SizedBox(height: spacing.md),
            widget.extraContent!,
          ],
          SizedBox(height: spacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  key: widget.cancelKey,
                  label: widget.cancelLabel,
                  onPressed: _isConfirming
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: widget.confirmKey,
                  label: widget.confirmLabel,
                  variant: widget.danger
                      ? AppButtonVariant.danger
                      : AppButtonVariant.primary,
                  isLoading: _isConfirming,
                  onPressed: _handleConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
