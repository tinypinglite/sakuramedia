import 'package:flutter/material.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/image_search_result_card.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';

/// 累计搜索结果使用的懒构建 Sliver 网格。
class ImageSearchResultSliver extends StatelessWidget {
  const ImageSearchResultSliver({
    super.key,
    required this.items,
    required this.onItemTap,
    this.onItemMenuRequested,
  });

  final List<ImageSearchResultItemDto> items;
  final ValueChanged<ImageSearchResultItemDto> onItemTap;
  final void Function(ImageSearchResultItemDto item, Offset globalPosition)?
  onItemMenuRequested;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardSliver<ImageSearchResultItemDto>(
      gridKey: const Key('desktop-image-search-result-grid'),
      items: items,
      isLoading: false,
      targetColumnWidth: 220,
      minColumns: 2,
      maxColumns: 5,
      childAspectRatio: 16 / 10,
      skeletonBuilder: (context, index) => const SizedBox.shrink(),
      itemBuilder:
          (context, item, index) => ImageSearchResultCard(
            item: item,
            onTap: () => onItemTap(item),
            onRequestMenu:
                onItemMenuRequested == null
                    ? null
                    : (globalPosition) =>
                        onItemMenuRequested!(item, globalPosition),
          ),
    );
  }
}
