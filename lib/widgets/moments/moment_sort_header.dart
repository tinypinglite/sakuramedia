import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';

enum MomentSortHeaderVariant { standard, mobileTagCompact }

class MomentSortHeader extends StatelessWidget {
  const MomentSortHeader({
    super.key,
    required this.total,
    required this.sortOrder,
    required this.onSortChanged,
    this.variant = MomentSortHeaderVariant.standard,
    this.latestSortKey = const Key('moments-sort-latest'),
    this.earliestSortKey = const Key('moments-sort-earliest'),
    this.totalKey = const Key('moments-page-total'),
  });

  final int total;
  final MomentSortOrder sortOrder;
  final ValueChanged<MomentSortOrder> onSortChanged;
  final MomentSortHeaderVariant variant;
  final Key latestSortKey;
  final Key earliestSortKey;
  final Key totalKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildSortAction(
          context,
          actionKey: latestSortKey,
          order: MomentSortOrder.latest,
        ),
        SizedBox(width: context.appSpacing.sm),
        _buildSortAction(
          context,
          actionKey: earliestSortKey,
          order: MomentSortOrder.earliest,
        ),
        const Spacer(),
        Text(
          '$total 个时刻',
          key: totalKey,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSortAction(
    BuildContext context, {
    required Key actionKey,
    required MomentSortOrder order,
  }) {
    return AppTextButton(
      key: actionKey,
      label: order.label,
      size: AppTextButtonSize.xSmall,
      isSelected: sortOrder == order,
      onPressed: () => onSortChanged(order),
    );
  }
}
