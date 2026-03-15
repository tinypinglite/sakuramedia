import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';

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
    final compactTagMode = variant == MomentSortHeaderVariant.mobileTagCompact;
    return Row(
      children: [
        _buildSortAction(
          context,
          actionKey: latestSortKey,
          order: MomentSortOrder.latest,
          compactTagMode: compactTagMode,
        ),
        SizedBox(
          width: compactTagMode ? context.appSpacing.xs : context.appSpacing.sm,
        ),
        _buildSortAction(
          context,
          actionKey: earliestSortKey,
          order: MomentSortOrder.earliest,
          compactTagMode: compactTagMode,
        ),
        const Spacer(),
        Text(
          '$total 个时刻',
          key: totalKey,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSortAction(
    BuildContext context, {
    required Key actionKey,
    required MomentSortOrder order,
    required bool compactTagMode,
  }) {
    final selected = sortOrder == order;
    if (!compactTagMode) {
      return AppButton(
        key: actionKey,
        label: order.label,
        size: AppButtonSize.small,
        isSelected: selected,
        onPressed: () => onSortChanged(order),
      );
    }

    final theme = Theme.of(context);
    final colors = context.appColors;
    final primary = theme.colorScheme.primary;
    final backgroundColor =
        selected ? primary.withValues(alpha: 0.08) : colors.surfaceCard;
    final borderColor = selected ? primary : colors.borderSubtle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: actionKey,
        borderRadius: context.appRadius.smBorder,
        onTap: () => onSortChanged(order),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: context.appRadius.smBorder,
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.appSpacing.sm,
              vertical: context.appSpacing.xs,
            ),
            child: Text(
              order.label,
              style: theme.textTheme.labelSmall
            ),
          ),
        ),
      ),
    );
  }
}
