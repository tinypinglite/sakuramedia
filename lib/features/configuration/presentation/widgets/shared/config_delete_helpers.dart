import 'package:flutter/widgets.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/widgets/feedback/app_confirm_dialog.dart';

/// 配置域标准删除流程：danger 确认 → 调 [onDelete] → 成功 toast + 返回 true。
///
/// 封装 `showAppConfirmDialog(danger: true, onConfirm: ..., failureFallback: ...)`
/// + 成功 toast 三步曲。onConfirm 失败(抛异常)时对话框内部自动展示错误 toast、
/// 保持对话框不 pop，返回 false。
///
/// 调用方拿到 `true` 后再做「本地 setState / 后台对账 / 重新加载」这类
/// 无法封装的副作用。
Future<bool> showAppConfigDeleteConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required Future<void> Function() onDelete,
  required String successToast,
  required String failureFallback,
  String confirmLabel = '删除',
  Key? dialogKey,
  Key? confirmKey,
}) async {
  final confirmed = await showAppConfirmDialog(
    context,
    title: title,
    message: message,
    danger: true,
    confirmLabel: confirmLabel,
    dialogKey: dialogKey,
    confirmKey: confirmKey,
    failureFallback: failureFallback,
    onConfirm: onDelete,
  );
  if (confirmed && context.mounted) {
    showToast(successToast);
  }
  return confirmed;
}
