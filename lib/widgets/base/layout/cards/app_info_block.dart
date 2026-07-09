import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 只读字段展示：label 小字灰在上、value 正常字在下。
///
/// 适用移动端详情抽屉里的字段信息块（跟 [AppStatTile] 是"翻转版"——
/// StatTile 强调数字、InfoBlock 强调标签）。
/// 内部：宽度撑满 + `surfaceMuted` + `mdBorder`，padding `sm`。
class AppInfoBlock extends StatelessWidget {
  const AppInfoBlock({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          Text(
            value,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.primary,
            ),
          ),
        ],
      ),
    );
  }
}
