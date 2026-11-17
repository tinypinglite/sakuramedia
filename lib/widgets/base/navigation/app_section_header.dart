import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 分区标题行：`标题（+可选数量）……右侧动作入口`。
///
/// 目前用于「发现」页与「概览」页的预览分区（如「最近添加 / 最近播放」的
/// 「更多」入口）。动作不是必须的——窄布局或没有落点页时可只传标题。
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.trailingText,
    this.actionLabel,
    this.actionKey,
    this.actionSize = AppTextButtonSize.small,
    this.onActionTap,
  });

  final String title;

  /// 标题右侧的次要说明（如「128 部」）；null 时不占位。
  final String? trailingText;

  /// 右侧动作文案（如「更多」）；null 时不渲染动作。
  final String? actionLabel;
  final Key? actionKey;
  final AppTextButtonSize actionSize;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        if (trailingText != null) ...<Widget>[
          SizedBox(width: context.appSpacing.sm),
          Text(
            trailingText!,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
        const Spacer(),
        if (actionLabel != null)
          AppTextButton(
            key: actionKey,
            label: actionLabel!,
            size: actionSize,
            trailingIcon: const Icon(Icons.chevron_right_rounded),
            onPressed: onActionTap,
          ),
      ],
    );
  }
}
