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
    this.kindFilter,
    this.onKindChanged,
    this.variant = MomentSortHeaderVariant.standard,
    this.latestSortKey = const Key('moments-sort-latest'),
    this.earliestSortKey = const Key('moments-sort-earliest'),
    this.totalKey = const Key('moments-page-total'),
    this.kindJavKey = const Key('moments-kind-jav'),
    this.kindVideoKey = const Key('moments-kind-video'),
  });

  final int total;
  final MomentSortOrder sortOrder;
  final ValueChanged<MomentSortOrder> onSortChanged;
  // 同时非空才渲染 kind 切换；discovery 等不传则保持现状（只显示排序 + 总数）。
  final MomentKindFilter? kindFilter;
  final ValueChanged<MomentKindFilter>? onKindChanged;
  final MomentSortHeaderVariant variant;
  final Key latestSortKey;
  final Key earliestSortKey;
  final Key totalKey;
  final Key kindJavKey;
  final Key kindVideoKey;

  bool get _hasKindFilter => kindFilter != null && onKindChanged != null;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      children: [
        if (_hasKindFilter) ...[
          _buildKindAction(
            context,
            actionKey: kindJavKey,
            kind: MomentKindFilter.jav,
          ),
          SizedBox(width: spacing.sm),
          _buildKindAction(
            context,
            actionKey: kindVideoKey,
            kind: MomentKindFilter.video,
          ),
          // kind 组与 sort 组之间留个稍宽的间隔，让两组在视觉上分开。
          SizedBox(width: spacing.md),
        ],
        _buildSortAction(
          context,
          actionKey: latestSortKey,
          order: MomentSortOrder.latest,
        ),
        SizedBox(width: spacing.sm),
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
      onPressed: () => onKindChanged!.call(kind),
    );
  }
}
