import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 数据指标块：value 大字在上、label 小字在下。
///
/// 适用移动端概览卡里的统计小格 / dashboard tile。
/// 内部：`surfaceCard` + `mdBorder`，padding `sm`。
class AppStatTile extends StatelessWidget {
  const AppStatTile({
    super.key,
    required this.label,
    required this.value,
    this.valueSize = AppTextSize.s16,
  });

  final String label;
  final String value;
  final AppTextSize valueSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.appSpacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: resolveAppTextStyle(
              context,
              size: valueSize,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ),
    );
  }
}
