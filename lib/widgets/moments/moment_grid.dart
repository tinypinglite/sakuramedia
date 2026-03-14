import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/moments/moment_card.dart';

class MomentGrid extends StatelessWidget {
  const MomentGrid({super.key, required this.items, required this.onItemTap});

  final List<MomentListItem> items;
  final ValueChanged<MomentListItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing.md;
        final columns = _resolveColumnCount(constraints.maxWidth, spacing);
        return GridView.builder(
          key: const Key('moment-grid'),
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
              (context, index) => MomentCard(
                item: items[index],
                onTap: () => onItemTap(items[index]),
              ),
        );
      },
    );
  }

  int _resolveColumnCount(double width, double spacing) {
    final columns = ((width + spacing) / (280 + spacing)).floor();
    return math.max(2, math.min(4, columns));
  }
}
