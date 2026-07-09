import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';

class MomentSortHeader extends StatelessWidget {
  const MomentSortHeader({
    super.key,
    required this.total,
    required this.sortOrder,
    required this.onSortChanged,
    required this.kindFilter,
    required this.onKindChanged,
    this.keyPrefix = 'moments',
  });

  final int total;
  final MomentSortOrder sortOrder;
  final ValueChanged<MomentSortOrder> onSortChanged;
  final MomentKindFilter kindFilter;
  final ValueChanged<MomentKindFilter> onKindChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppFilterTotalHeader(
      leading: Row(
        children: [
          _buildKindAction(
            context,
            actionKey: Key('$keyPrefix-kind-jav'),
            kind: MomentKindFilter.jav,
          ),
          SizedBox(width: spacing.sm),
          _buildKindAction(
            context,
            actionKey: Key('$keyPrefix-kind-video'),
            kind: MomentKindFilter.video,
          ),
          // kind 组与 sort 组之间留个稍宽的间隔，让两组在视觉上分开。
          SizedBox(width: spacing.md),
          _buildSortAction(
            context,
            actionKey: Key('$keyPrefix-sort-latest'),
            order: MomentSortOrder.latest,
          ),
          SizedBox(width: spacing.sm),
          _buildSortAction(
            context,
            actionKey: Key('$keyPrefix-sort-earliest'),
            order: MomentSortOrder.earliest,
          ),
        ],
      ),
      totalText: '$total 个时刻',
      totalKey: Key('$keyPrefix-page-total'),
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

  Widget _buildKindAction(
    BuildContext context, {
    required Key actionKey,
    required MomentKindFilter kind,
  }) {
    return AppTextButton(
      key: actionKey,
      label: kind.label,
      size: AppTextButtonSize.xSmall,
      isSelected: kindFilter == kind,
      onPressed: () => onKindChanged(kind),
    );
  }
}
