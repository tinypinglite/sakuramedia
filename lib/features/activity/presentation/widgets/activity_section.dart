import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_state.dart';
import 'package:sakuramedia/theme.dart';

/// 带标题的内容段：任务中心各区块（活动任务 / 重点关注 / 最近操作）共用。
class ActivitySection extends StatelessWidget {
  const ActivitySection({
    super.key,
    required this.title,
    required this.child,
    this.titleStyle,
    this.trailing,
  });

  final String title;
  final Widget child;
  final TextStyle? titleStyle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style:
          titleStyle ??
          resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trailing == null)
          titleWidget
        else
          Row(
            children: [
              Expanded(child: titleWidget),
              SizedBox(width: context.appSpacing.md),
              trailing!,
            ],
          ),
        SizedBox(height: context.appSpacing.lg),
        child,
      ],
    );
  }
}

/// 轮询状态横幅：说明当前同步节奏 / 最近一次同步是否失败。
class ActivityConnectionBanner extends StatelessWidget {
  const ActivityConnectionBanner({
    super.key,
    required this.state,
    this.message,
  });

  final ActivityConnectionState state;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final backgroundColor = switch (state) {
      ActivityConnectionState.connecting => colors.surfaceMuted,
      ActivityConnectionState.polling => colors.selectionSurface,
    };
    final foregroundColor = switch (state) {
      ActivityConnectionState.connecting => context.appTextPalette.secondary,
      ActivityConnectionState.polling => context.appTextPalette.accent,
    };
    final icon = switch (state) {
      ActivityConnectionState.connecting => Icons.sync_rounded,
      ActivityConnectionState.polling => Icons.schedule_rounded,
    };

    return Container(
      key: const Key('activity-connection-banner'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.lg,
        vertical: context.appSpacing.md,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: foregroundColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: foregroundColor,
            size: context.appComponentTokens.iconSizeMd,
          ),
          SizedBox(width: context.appSpacing.sm),
          Expanded(
            child: Text(
              message ?? '',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ).copyWith(color: foregroundColor),
            ),
          ),
        ],
      ),
    );
  }
}
