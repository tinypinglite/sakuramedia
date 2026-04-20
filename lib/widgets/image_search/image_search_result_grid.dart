import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/image_search/image_search_result_card.dart';

class ImageSearchResultGrid extends StatelessWidget {
  const ImageSearchResultGrid({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing.md;
        final columns = _resolveColumnCount(constraints.maxWidth, spacing);
        return GridView.builder(
          key: const Key('desktop-image-search-result-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 16 / 10,
          ),
          itemBuilder:
              (context, index) => ImageSearchResultCard(
                item: items[index],
                onTap: () => onItemTap(items[index]),
                onRequestMenu:
                    onItemMenuRequested == null
                        ? null
                        : (globalPosition) =>
                            onItemMenuRequested!(items[index], globalPosition),
              ),
        );
      },
    );
  }

  int _resolveColumnCount(double width, double spacing) {
    final columns = ((width + spacing) / (220 + spacing)).floor();
    return math.max(2, math.min(5, columns));
  }
}
