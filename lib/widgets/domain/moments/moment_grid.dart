import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/widgets/base/feedback/app_cover_card_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_card.dart';

class MomentGrid extends StatelessWidget {
  const MomentGrid({
    super.key,
    required this.items,
    required this.onItemTap,
    this.isLoading = false,
    this.placeholderCount = 8,
    this.maxRows,
    this.maxColumns = 4,
  });

  final List<MomentListItem> items;
  final ValueChanged<MomentListItem> onItemTap;
  final bool isLoading;
  final int placeholderCount;

  /// 首页等预览区可限制为固定行数；列表页保持不传以展示全部项目。
  final int? maxRows;

  /// 网格的最大列数；默认保持时刻列表既有的 4 列上限。
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardGrid<MomentListItem>(
      gridKey: const Key('moment-grid'),
      items: items,
      isLoading: isLoading,
      placeholderCount: placeholderCount,
      skeletonBuilder: (_, __) => const AppCoverCardSkeleton(),
      targetColumnWidth: 280,
      minColumns: 2,
      maxColumns: maxColumns,
      childAspectRatio: 16 / 10,
      maxRows: maxRows,
      itemBuilder: (context, item, _) =>
          MomentCard(item: item, onTap: () => onItemTap(item)),
    );
  }
}

/// 累计分页时刻列表使用的 Sliver 网格版本。
class MomentSliver extends StatelessWidget {
  const MomentSliver({
    super.key,
    required this.items,
    required this.onItemTap,
    this.isLoading = false,
    this.placeholderCount = 8,
  });

  final List<MomentListItem> items;
  final ValueChanged<MomentListItem> onItemTap;
  final bool isLoading;
  final int placeholderCount;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardSliver<MomentListItem>(
      gridKey: const Key('moment-grid'),
      items: items,
      isLoading: isLoading,
      placeholderCount: placeholderCount,
      skeletonBuilder: (_, __) => const AppCoverCardSkeleton(),
      targetColumnWidth: 280,
      minColumns: 2,
      maxColumns: 4,
      childAspectRatio: 16 / 10,
      itemBuilder: (context, item, _) =>
          MomentCard(item: item, onTap: () => onItemTap(item)),
    );
  }
}
