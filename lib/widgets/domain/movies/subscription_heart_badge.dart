import 'package:expand_tap_area/expand_tap_area.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/platform/haptic_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';

/// 订阅心形徽标：视觉图标固定 `iconSizeXl`（24），外层命中区使用
/// `subscriptionHeartHitSize`（44）。布局盒保持 `movieCardStatusBadgeSize`
/// （24），命中区经 `expand_tap_area` 外扩，不改变显示大小与相邻元素对齐。
///
/// movie / actor 摘要卡片、影片详情 hero、演员详情（桌面 / 移动）共用。
/// 移动端 follow 卡片是 IconButton 变体（带水波纹），不在这里。
/// 点击时播放一次轻触感反馈（移动端），桌面端无副作用。
class SubscriptionHeartBadge extends StatelessWidget {
  const SubscriptionHeartBadge({
    super.key,
    required this.loadingKey,
    required this.isSubscribed,
    required this.isUpdating,
    required this.onTap,
  });

  final Key loadingKey;
  final bool isSubscribed;
  final bool isUpdating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;
    final colors = context.appColors;

    final badgeSize = componentTokens.movieCardStatusBadgeSize;
    final hitPadding =
        (componentTokens.subscriptionHeartHitSize - badgeSize) / 2;

    final badge = SizedBox(
      width: badgeSize,
      height: badgeSize,
      child: Center(
        child: isUpdating
            ? AppInlineSpinner(
                key: loadingKey,
                color: colors.subscriptionHeartIcon,
              )
            : Icon(
                isSubscribed
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: componentTokens.iconSizeXl,
                color: colors.subscriptionHeartIcon,
              ),
      ),
    );

    if (onTap == null || isUpdating) {
      return badge;
    }

    return ExpandTapWidget(
      onTap: () {
        triggerSelectionHaptic();
        onTap!();
      },
      tapPadding: EdgeInsets.all(hitPadding),
      // MouseRegion 的命中测试受自身布局尺寸限制，光标仍只在 24 图标区域内显示；
      // 命中区本身由 ExpandTapWidget 外扩，不受影响。
      child: MouseRegion(cursor: SystemMouseCursors.click, child: badge),
    );
  }
}
