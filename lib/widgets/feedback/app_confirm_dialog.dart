import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';

/// 统一的二次确认弹窗：标题 + 正文 + 「取消 / 确认」两个按钮。
///
/// 取代此前各页面手写的同构 `AlertDialog` / `AppDesktopDialog` 确认框。确认返回
/// `true`，取消或点遮罩关闭返回 `false`（恒非空，调用方可直接 `if (!confirmed) return;`）。
///
/// [danger] 为 `true` 时确认按钮用危险红色（删除类不可恢复操作）。[dialogKey] /
/// [confirmKey] / [cancelKey] 用于沿用各处既有的测试 key。[extraContent] 在正文与
/// 按钮之间插入自定义内容（如带 key 的路径文本），为 `null` 时不渲染。
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
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final spacing = dialogContext.appSpacing;
      return AppDesktopDialog(
        dialogKey: dialogKey,
        width: dialogContext.appLayoutTokens.dialogWidthSm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: resolveAppTextStyle(
                dialogContext,
                size: AppTextSize.s18,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: spacing.lg),
            Text(
              message,
              style: resolveAppTextStyle(
                dialogContext,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            if (extraContent != null) ...[
              SizedBox(height: spacing.md),
              extraContent,
            ],
            SizedBox(height: spacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    key: cancelKey,
                    label: cancelLabel,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: AppButton(
                    key: confirmKey,
                    label: confirmLabel,
                    variant: danger
                        ? AppButtonVariant.danger
                        : AppButtonVariant.primary,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return confirmed ?? false;
}
