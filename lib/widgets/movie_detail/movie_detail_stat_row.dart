import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MovieDetailStatRow extends StatelessWidget {
  const MovieDetailStatRow({super.key, required this.items});

  final List<MovieDetailStatItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items
          .map(
            (item) => Tooltip(
              message: item.tooltip,
              waitDuration: const Duration(milliseconds: 250),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: context.appComponentTokens.iconSizeXs,
                    color: item.iconColor,
                  ),
                  SizedBox(width: context.appSpacing.xs),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class MovieDetailStatItem {
  const MovieDetailStatItem({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final Color iconColor;
}
