import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 列表「多选态」通用操作条：`已选 N · Spacer · 全选/取消全选 · 批量动作… · 取消`。
///
/// 进入多选后**原地替换筛选行**，保持信息密度不变。活动中心资源任务面板与影片列表
/// 批量订阅此前各写了一份逐字相同的骨架（同样的 s12/medium/primary 计数文案、
/// 同样的 `Spacer`、同样的 `spacing.sm` 间距、同样的三种按钮尺寸），统一收口到这里。
///
/// 差异化的批量动作按钮由调用方通过 [actions] 传入（活动中心一个「重置生成状态」，
/// 影片列表两个「订阅」/「取消订阅」），本组件只负责骨架与按钮间距。
///
/// 配套的非多选态入口按钮见 [AppSelectionEntryButton]。
class AppSelectionToolbar extends StatelessWidget {
  const AppSelectionToolbar({
    super.key,
    required this.countLabel,
    required this.selectAllLabel,
    required this.onToggleAll,
    required this.actions,
    required this.onExit,
    this.countKey,
    this.selectAllKey,
    this.exitKey,
    this.exitLabel = '取消',
  });

  /// 左侧计数文案，单位由调用方决定（`已选 3 部` / `已选 3 个`）。
  final String countLabel;

  /// 「全选」按钮文案；调用方自行处理「取消全选」与带计数的变体
  /// （如 `全选可重置(2/5)`）。
  final String selectAllLabel;

  /// `null` 时「全选」按钮禁用（无可选项或正在提交）。
  final VoidCallback? onToggleAll;

  /// 批量动作按钮，按传入顺序排在「全选」与「取消」之间，之间自动补 `spacing.sm`。
  /// 通常是 [AppButton]（`variant: primary`、`size: small`）。
  final List<Widget> actions;

  /// 「取消」（退出多选）回调；`null` 时禁用（正在提交）。
  final VoidCallback? onExit;

  final Key? countKey;
  final Key? selectAllKey;
  final Key? exitKey;
  final String exitLabel;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      children: [
        Text(
          countLabel,
          key: countKey,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.primary,
          ),
        ),
        const Spacer(),
        AppTextButton(
          key: selectAllKey,
          label: selectAllLabel,
          size: AppTextButtonSize.small,
          onPressed: onToggleAll,
        ),
        for (final action in actions) ...[SizedBox(width: spacing.sm), action],
        SizedBox(width: spacing.sm),
        AppTextButton(
          key: exitKey,
          label: exitLabel,
          size: AppTextButtonSize.small,
          onPressed: onExit,
        ),
      ],
    );
  }
}

/// 非多选态下的「选择」入口按钮：小号 [AppTextButton] + 勾选圈图标。
///
/// 只是按钮本体，不含对齐——调用方按自己的 header 结构决定怎么摆
/// （`AppFilterTotalHeader.trailing` / `Row` 尾项 / `Align` 右对齐）。
class AppSelectionEntryButton extends StatelessWidget {
  const AppSelectionEntryButton({
    super.key,
    required this.onPressed,
    this.label = '选择',
  });

  /// `null` 时禁用（列表为空、无可选项）。
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppTextButton(
      label: label,
      icon: const Icon(Icons.check_circle_outline, size: 16),
      size: AppTextButtonSize.small,
      onPressed: onPressed,
    );
  }
}
