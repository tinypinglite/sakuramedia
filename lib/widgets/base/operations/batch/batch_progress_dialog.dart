import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 批量任务执行结果：成功与失败的原始条目清单，供调用方按结果就地更新列表。
class BatchRunResult<T> {
  const BatchRunResult({required this.succeeded, required this.failed});

  final List<T> succeeded;
  final List<T> failed;

  int get total => succeeded.length + failed.length;
  bool get hasFailure => failed.isNotEmpty;
}

/// 顺序执行一组单条任务，并用进度弹窗呈现过程。
///
/// - 逐条 `await action(item)`，某条抛异常即记为失败并**跳过继续**，不中断剩余项。
/// - 全部成功时进度弹窗自动关闭；有失败则停留展示「X 成功 / Y 失败」，等用户手动关闭。
/// - 返回 [BatchRunResult]，调用方据此移除/刷新成功项。
///
/// 若用户中途强行关闭（理论上 barrier 不可点关，仅兜底），返回当前已统计的结果。
Future<BatchRunResult<T>> runBatchOperation<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required Future<void> Function(T item) action,
}) async {
  final result = await showDialog<BatchRunResult<T>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _BatchProgressDialog<T>(
      title: title,
      items: items,
      action: action,
    ),
  );
  return result ??
      BatchRunResult<T>(
        succeeded: const [],
        failed: List<T>.of(items),
      );
}

class _BatchProgressDialog<T> extends StatefulWidget {
  const _BatchProgressDialog({
    required this.title,
    required this.items,
    required this.action,
  });

  final String title;
  final List<T> items;
  final Future<void> Function(T item) action;

  @override
  State<_BatchProgressDialog<T>> createState() =>
      _BatchProgressDialogState<T>();
}

class _BatchProgressDialogState<T> extends State<_BatchProgressDialog<T>> {
  final List<T> _succeeded = <T>[];
  final List<T> _failed = <T>[];
  int _current = 0;
  bool _done = false;

  int get _total => widget.items.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    for (final item in widget.items) {
      try {
        await widget.action(item);
        _succeeded.add(item);
      } catch (_) {
        _failed.add(item);
      }
      if (!mounted) {
        return;
      }
      setState(() => _current += 1);
    }
    if (!mounted) {
      return;
    }
    final result =
        BatchRunResult<T>(succeeded: _succeeded, failed: _failed);
    if (_failed.isEmpty) {
      // 全部成功：自动关闭并回传结果。
      Navigator.of(context).pop(result);
      return;
    }
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final value = _total == 0 ? 1.0 : _current / _total;

    return AppDesktopDialog(
      width: 360,
      showCloseButton: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _done ? '已完成' : widget.title,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.md),
          ClipRRect(
            borderRadius: context.appRadius.smBorder,
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: colors.surfaceMuted,
            ),
          ),
          SizedBox(height: spacing.sm),
          Text(
            _done
                ? '成功 ${_succeeded.length} 个，失败 ${_failed.length} 个'
                : '处理中 $_current/$_total',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: _done && _failed.isNotEmpty
                  ? AppTextTone.error
                  : AppTextTone.secondary,
            ),
          ),
          if (_done) ...[
            SizedBox(height: spacing.lg),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                key: const Key('batch-progress-close-button'),
                label: '关闭',
                size: AppButtonSize.small,
                onPressed: () => Navigator.of(context).pop(
                  BatchRunResult<T>(succeeded: _succeeded, failed: _failed),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
