import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_card.dart';

class MomentGrid extends StatelessWidget {
  const MomentGrid({super.key, required this.items, required this.onItemTap});

  final List<MomentListItem> items;
  final ValueChanged<MomentListItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardGrid<MomentListItem>(
      gridKey: const Key('moment-grid'),
      items: items,
      // 调用方各自管加载态,本组件不感知 isLoading。
      isLoading: false,
      skeletonBuilder: (_, __) => const SizedBox.shrink(),
      targetColumnWidth: 280,
      minColumns: 2,
      maxColumns: 4,
      childAspectRatio: 16 / 10,
      itemBuilder: (context, item, _) =>
          MomentCard(item: item, onTap: () => onItemTap(item)),
    );
  }
}
