import 'package:flutter/material.dart';
import 'package:sakuramedia/features/rankings/presentation/ranking_sort_mode.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';

/// 排行榜列表顶部的本地排序栏。
///
/// 交互对齐国内主流 App（淘宝/京东等）的「综合 / 价格 ↑↓」排序条：
/// 「默认」保持榜单名次；点「热度」在降序↓与升序↑之间切换，箭头指示当前方向。
class RankingSortControl extends StatelessWidget {
  const RankingSortControl({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final RankingSortMode mode;
  final ValueChanged<RankingSortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isByHeat = mode.isByHeat;
    final heatIcon =
        mode == RankingSortMode.heatAsc
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextButton(
          key: const Key('rankings-sort-default'),
          label: '默认',
          size: AppTextButtonSize.small,
          isSelected: mode == RankingSortMode.byRank,
          onPressed: () => onChanged(RankingSortMode.byRank),
        ),
        SizedBox(width: context.appSpacing.sm),
        AppTextButton(
          key: const Key('rankings-sort-heat'),
          label: '热度',
          size: AppTextButtonSize.small,
          isSelected: isByHeat,
          trailingIcon: Icon(heatIcon),
          onPressed:
              () => onChanged(
                mode == RankingSortMode.heatDesc
                    ? RankingSortMode.heatAsc
                    : RankingSortMode.heatDesc,
              ),
        ),
      ],
    );
  }
}
