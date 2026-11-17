import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 移动端配置流程/引导卡:标题 + 描述 + 可选 tip + 可选 [AppBadge] 状态 +
/// 底部 CTA 按钮。用作「先做 X → 再做 Y → 最后 Z」的多步流程卡,
/// 或单独的「先去别的页配置」提示卡。
///
/// - 带 [badgeLabel] 时右上角显示状态 badge(用于流程进度)。
/// - 带 [tip] 时正文下方多一个 surfaceMuted 提示块。
class MobileConfigOnboardingCard extends StatelessWidget {
  const MobileConfigOnboardingCard({
    super.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onActionTap,
    this.tip,
    this.badgeLabel,
    this.badgeTone,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onActionTap;
  final String? tip;
  final String? badgeLabel;
  final AppBadgeTone? badgeTone;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppContentCard(
      title: title,
      headerTrailing: badgeLabel == null
          ? null
          : AppBadge(
              label: badgeLabel!,
              tone: badgeTone ?? AppBadgeTone.warning,
              size: AppBadgeSize.compact,
            ),
      headerBottomSpacing: tip != null ? spacing.sm : spacing.xs,
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          if (tip != null) ...[
            SizedBox(height: spacing.sm),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(spacing.sm),
              decoration: BoxDecoration(
                color: context.appColors.surfaceMuted,
                borderRadius: context.appRadius.mdBorder,
              ),
              child: Text(
                tip!,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
            ),
          ],
          SizedBox(height: spacing.md),
          AppButton(
            label: actionLabel,
            size: AppButtonSize.xSmall,
            onPressed: onActionTap,
          ),
        ],
      ),
    );
  }
}
