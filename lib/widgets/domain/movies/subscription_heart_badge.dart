import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 订阅心形徽标(徽标区大小 + 中心心形/加载圈)。
///
/// movie 卡片右上角 / actor 卡片右下角逐字相同,合并到此。
/// 移动端 IconButton 变体不在这里(命中区不同)。
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

    final badge = SizedBox(
      width: componentTokens.movieCardStatusBadgeSize,
      height: componentTokens.movieCardStatusBadgeSize,
      child: Center(
        child: isUpdating
            ? SizedBox(
                width: componentTokens.movieCardLoaderSize,
                height: componentTokens.movieCardLoaderSize,
                child: CircularProgressIndicator(
                  key: loadingKey,
                  strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
                  color: colors.subscriptionHeartIcon,
                ),
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: badge,
      ),
    );
  }
}
